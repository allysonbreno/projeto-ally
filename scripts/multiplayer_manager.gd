extends Node
class_name MultiplayerManager

signal player_connected(player_info)
signal player_disconnected(player_id)
signal player_sync_received(player_id, player_data)
signal login_response(success, message, player_info)
signal connection_established()
signal connection_lost()

# Configuração do servidor
var server_host = "127.0.0.1"
var server_port = 8765
var websocket_url = ""

# WebSocket
var websocket: WebSocketPeer
var connection_status = "disconnected"  # disconnected, connecting, connected

# Dados do jogador local
var local_player_info = {}
var is_logged_in = false

# Jogadores conectados
var players_data = {}

func _ready():
    # Detectar se estamos rodando via Godot ou executável
    var is_debug = OS.is_debug_build()
    var log_file_path = ""
    
    if is_debug:
        log_file_path = "prompt_explicacao.txt"
        _init_log_file(log_file_path, "INSTANCIA1 (GODOT)")
    else:
        log_file_path = "logs_instancia2.txt"  
        _init_log_file(log_file_path, "INSTANCIA2 (EXECUTAVEL)")
    
    _log_to_file("MultiplayerManager inicializado")
    print("MultiplayerManager inicializado")
    websocket_url = "ws://%s:%d" % [server_host, server_port]
    
    # Configurar WebSocket
    websocket = WebSocketPeer.new()
    
func _process(_delta):
    if websocket:
        websocket.poll()
        
        match websocket.get_ready_state():
            WebSocketPeer.STATE_CONNECTING:
                if connection_status != "connecting":
                    connection_status = "connecting"
                    print("🔗 Conectando ao servidor...")
            
            WebSocketPeer.STATE_OPEN:
                if connection_status != "connected":
                    connection_status = "connected"
                    print("✅ Conectado ao servidor!")
                    connection_established.emit()
                
                # Processar mensagens recebidas
                _process_messages()
            
            WebSocketPeer.STATE_CLOSING:
                connection_status = "disconnecting"
                print("🔌 Desconectando...")
            
            WebSocketPeer.STATE_CLOSED:
                if connection_status != "disconnected":
                    connection_status = "disconnected"
                    print("❌ Conexão perdida!")
                    connection_lost.emit()
                    _on_connection_lost()

func connect_to_server():
    """Conecta ao servidor WebSocket"""
    if connection_status != "disconnected":
        _log_to_file("⚠️ Já conectado ou conectando...")
        return false
    
    _log_to_file("🚀 Conectando a %s..." % websocket_url)
    
    var error = websocket.connect_to_url(websocket_url)
    if error != OK:
        _log_to_file("❌ Erro ao conectar: " + str(error))
        return false
    
    return true

func disconnect_from_server():
    """Desconecta do servidor"""
    if websocket and connection_status == "connected":
        websocket.close()
    connection_status = "disconnected"
    is_logged_in = false
    players_data.clear()

func login(player_name: String):
    """Faz login no servidor"""
    if connection_status != "connected":
        print("❌ Não conectado ao servidor")
        return false
    
    if player_name.strip_edges().is_empty():
        print("❌ Nome do jogador não pode estar vazio")
        return false
    
    var login_data = {
        "type": "login",
        "player_name": player_name.strip_edges()
    }
    
    _send_message(login_data)
    return true

func send_player_update(position: Vector2, velocity: Vector2, animation: String, facing: int, hp: int):
    """Envia atualização do jogador para o servidor"""
    if not is_logged_in:
        return
    
    var update_data = {
        "type": "player_update",
        "position": {"x": position.x, "y": position.y},
        "velocity": {"x": velocity.x, "y": velocity.y},
        "animation": animation,
        "facing": facing,
        "hp": hp
    }
    
    _send_message(update_data)

func send_player_action(action: String, action_data: Dictionary = {}):
    """Envia ação do jogador para o servidor"""
    if not is_logged_in:
        return
    
    var action_message = {
        "type": "player_action",
        "action": action,
        "action_data": action_data
    }
    
    _send_message(action_message)

func _send_message(data: Dictionary):
    """Envia mensagem para o servidor"""
    if websocket and connection_status == "connected":
        var json_string = JSON.stringify(data)
        websocket.send_text(json_string)

func send_log_to_server(message: String):
    """Envia log para o servidor em tempo real"""
    if connection_status == "connected":
        var instance_type = "GODOT" if OS.is_debug_build() else "EXECUTAVEL"
        var log_data = {
            "type": "client_log",
            "message": message,
            "instance_type": instance_type
        }
        _send_message(log_data)

func _process_messages():
    """Processa mensagens recebidas do servidor"""
    while websocket.get_available_packet_count():
        var packet = websocket.get_packet()
        var message_string = packet.get_string_from_utf8()
        
        var json = JSON.new()
        var parse_result = json.parse(message_string)
        
        if parse_result != OK:
            print("❌ Erro ao parsear JSON: ", message_string)
            continue
        
        var message_data = json.get_data()
        _handle_server_message(message_data)

func _handle_server_message(data: Dictionary):
    """Processa mensagens do servidor"""
    var message_type = data.get("type", "")
    
    match message_type:
        "login_response":
            _handle_login_response(data)
        
        "players_list":
            _handle_players_list(data)
        
        "player_connected":
            _handle_player_connected(data)
        
        "player_disconnected":
            _handle_player_disconnected(data)
        
        "player_sync":
            _handle_player_sync(data)
        
        "player_action":
            _handle_player_action(data)
        
        "server_shutdown":
            _handle_server_shutdown(data)
        
        _:
            print("❓ Tipo de mensagem desconhecido: ", message_type)

func _handle_login_response(data: Dictionary):
    """Processa resposta de login"""
    var success = data.get("success", false)
    var message = data.get("message", "")
    
    if success:
        local_player_info = data.get("player_info", {})
        is_logged_in = true
        _log_to_file("✅ Login realizado com sucesso! ID: " + local_player_info.get("id", ""))
    else:
        is_logged_in = false
        _log_to_file("❌ Falha no login: " + message)
    
    login_response.emit(success, message, local_player_info)

func _handle_players_list(data: Dictionary):
    """Processa lista de jogadores"""
    var players = data.get("players", {})
    var my_id = local_player_info.get("id", "")
    
    _log_to_file("📋 Processando players_list - Meu ID: " + my_id)
    _log_to_file("📋 Jogadores na lista recebida: " + str(players.keys()))
    _log_to_file("📋 Jogadores ANTES da atualização: " + str(players_data.keys()))
    
    # Identificar novos jogadores que não estavam na lista anterior
    var novos_jogadores = []
    for player_id in players:
        _log_to_file("🔍 Analisando player_id: " + player_id + " | É meu ID? " + str(player_id == my_id) + " | Já existe? " + str(player_id in players_data))
        if player_id != my_id and player_id not in players_data:
            novos_jogadores.append(player_id)
            _log_to_file("➕ NOVO jogador identificado: " + player_id)
    
    _log_to_file("📊 Lista de novos jogadores ANTES de processar: " + str(novos_jogadores))
    
    # Atualizar dados dos jogadores
    for player_id in players:
        var player_info = players[player_id]
        players_data[player_id] = player_info
        
        _log_to_file("📋 Processando jogador: " + player_info.get("name", "") + " (ID: " + player_id + ")")
    
    # Emitir sinal apenas para NOVOS jogadores que não são o local
    for player_id in novos_jogadores:
        var player_info = players[player_id]
        _log_to_file("✅ EMITINDO player_connected para: " + player_info.get("name", "") + " (ID: " + player_id + ")")
        player_connected.emit(player_info)
    
    _log_to_file("📋 Lista final de jogadores: " + str(players_data.keys()))
    _log_to_file("📋 Novos jogadores detectados: " + str(novos_jogadores))

func _handle_player_connected(data: Dictionary):
    """Processa novo jogador conectado"""
    var player_info = data.get("player_info", {})
    var player_id = player_info.get("id", "")
    
    if player_id and player_id != local_player_info.get("id", ""):
        players_data[player_id] = player_info
        player_connected.emit(player_info)
        print("👤 Novo jogador conectado: ", player_info.get("name", ""))

func _handle_player_disconnected(data: Dictionary):
    """Processa jogador desconectado"""
    var player_id = data.get("player_id", "")
    var player_name = data.get("player_name", "")
    
    if player_id and player_id in players_data:
        players_data.erase(player_id)
        player_disconnected.emit(player_id)
        print("👋 Jogador desconectado: ", player_name)

func _handle_player_sync(data: Dictionary):
    """Processa sincronização de jogador"""
    var player_id = data.get("player_id", "")
    var player_info = data.get("player_info", {})
    
    if player_id and player_id != local_player_info.get("id", ""):
        # Atualizar dados do jogador
        if player_id in players_data:
            players_data[player_id].merge(player_info)
        
        player_sync_received.emit(player_id, player_info)

func _handle_player_action(data: Dictionary):
    """Processa ação de jogador"""
    var player_id = data.get("player_id", "")
    var action = data.get("action", "")
    var _action_data = data.get("data", {})
    
    if player_id != local_player_info.get("id", ""):
        var from_player = players_data.get(player_id, {}).get("name", "Unknown")
        print("🎯 Ação de ", from_player, " (", player_id, "): ", action)
        # Aqui você pode processar diferentes tipos de ações
        # Por exemplo: ataques, pulos, etc.

func _handle_server_shutdown(data: Dictionary):
    """Processa shutdown do servidor"""
    var message = data.get("message", "Servidor desligado")
    print("🛑 ", message)
    disconnect_from_server()

func _on_connection_lost():
    """Callback quando perde conexão"""
    is_logged_in = false
    players_data.clear()
    local_player_info.clear()

# Getters para uso externo
func get_local_player_id() -> String:
    return local_player_info.get("id", "")

func get_local_player_name() -> String:
    return local_player_info.get("name", "")

func is_server_connected() -> bool:
    return connection_status == "connected"

func get_players_data() -> Dictionary:
    return players_data

func get_player_info(player_id: String) -> Dictionary:
    return players_data.get(player_id, {})

# Variável global para controlar qual arquivo de log usar
var current_log_file = ""

func _init_log_file(file_path: String, instance_name: String):
    """Inicializa arquivo de log"""
    # Para executável, usar caminho absoluto na raiz do projeto
    if not OS.is_debug_build():
        # Executável: vai um nível acima da pasta builds
        current_log_file = "../" + file_path
    else:
        # Debug (Godot): usar caminho relativo normal
        current_log_file = file_path
    
    _log_to_file("Inicializando log em: " + current_log_file)
    
    var file = FileAccess.open(current_log_file, FileAccess.WRITE)
    if file:
        file.store_string("SISTEMA DE LOGS MULTIPLAYER - PROJETO ALLY\n\n")
        file.store_string("Este arquivo é automaticamente atualizado com os logs da %s.\n\n" % instance_name)
        file.store_string("==== LOGS %s ====\n" % instance_name)
        file.close()
        _log_to_file("Arquivo de log inicializado com sucesso")
    else:
        print("ERRO: Não conseguiu criar arquivo de log em: " + current_log_file)

func _log_to_file(message: String, file_path: String = ""):
    """Salva log no arquivo E envia para o servidor"""
    if file_path.is_empty():
        file_path = current_log_file
    
    var timestamp = Time.get_datetime_string_from_system().split("T")[1].substr(0, 8)
    var log_message = "[%s] %s" % [timestamp, message]
    
    # Salvar no arquivo local
    var file = FileAccess.open(file_path, FileAccess.WRITE_READ)
    if file:
        file.seek_end()
        file.store_string(log_message + "\n")
        file.close()
    
    # Enviar para o servidor em tempo real
    send_log_to_server(log_message)
