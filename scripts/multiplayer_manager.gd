extends Node
class_name MultiplayerManager

signal player_connected(player_info)
signal player_disconnected(player_id)
signal player_sync_received(player_id, player_data)
# Novos sinais para sistema server-side
signal enemies_update_received(enemies_data)
signal enemies_state_received(enemies_data)
signal enemy_death_received(enemy_data)
signal enemy_position_sync_received(sync_data)
signal map_change_received(player_id, current_map)
signal login_response(success, message, player_info)
signal connection_established()
signal connection_lost()
signal server_reconciliation(reconciliation_data)

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
    # Adicionar ao grupo para ser encontrado pelos inimigos
    add_to_group("multiplayer_manager")
    
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

func send_player_update_with_sequence(position: Vector2, velocity: Vector2, animation: String, facing: int, hp: int, sequence: int):
    """Envia atualização do jogador com sequence para reconciliação"""
    if not is_logged_in:
        return
    
    var update_data = {
        "type": "player_update",
        "position": {"x": position.x, "y": position.y},
        "velocity": {"x": velocity.x, "y": velocity.y},
        "animation": animation,
        "facing": facing,
        "hp": hp,
        "sequence": sequence
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

func send_map_change(current_map: String):
    """Notifica servidor sobre mudança de mapa"""
    if not is_logged_in:
        return
    
    var map_data = {
        "type": "map_change",
        "current_map": current_map
    }
    
    _send_message(map_data)

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

func send_enemy_death(enemy_id: String, enemy_position: Vector2):
    """Envia notificação de morte de inimigo"""
    if connection_status == "connected":
        var death_data = {
            "type": "enemy_death",
            "enemy_id": enemy_id,
            "position": {"x": enemy_position.x, "y": enemy_position.y},
            "killer_id": local_player_info.get("id", "")
        }
        _send_message(death_data)

func send_enemy_damage(enemy_id: String, damage: int, new_hp: int):
    """Envia notificação de dano ao inimigo"""
    if connection_status == "connected":
        var damage_data = {
            "type": "enemy_damage",
            "enemy_id": enemy_id,
            "damage": damage,
            "new_hp": new_hp,
            "attacker_id": local_player_info.get("id", "")
        }
        _send_message(damage_data)

func send_enemy_position_sync(enemy_id: String, position: Vector2, velocity: Vector2, flip_h: bool, animation: String):
    """Envia sincronização de posição do inimigo"""
    if connection_status == "connected":
        var sync_data = {
            "type": "enemy_position_sync",
            "enemy_id": enemy_id,
            "position": {"x": position.x, "y": position.y},
            "velocity": {"x": velocity.x, "y": velocity.y},
            "flip_h": flip_h,
            "animation": animation,
            "controller_id": local_player_info.get("id", "")
        }
        _send_message(sync_data)

func send_player_attack_enemy(enemy_id: String, damage: int):
    """Envia ataque do player ao inimigo (server-side)"""
    if connection_status == "connected":
        var attack_data = {
            "type": "player_attack_enemy",
            "enemy_id": enemy_id,
            "damage": damage,
            "attacker_id": local_player_info.get("id", "")
        }
        _send_message(attack_data)

func request_enemies_state(map_name: String):
    """Solicita estado atual dos inimigos de um mapa"""
    if connection_status == "connected":
        var request_data = {
            "type": "request_enemies_state",
            "map_name": map_name
        }
        _send_message(request_data)

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
        
        "player_sync_ack":
            _handle_player_sync_ack(data)
        
        "player_action":
            _handle_player_action(data)
        
        "enemy_death":
            _handle_enemy_death(data)
            
        "enemies_update":
            _handle_enemies_update(data)
            
        "enemies_state":
            _handle_enemies_state(data)
            
        "enemy_death":
            _handle_enemy_death_server(data)
            
        "enemy_position_sync":
            _handle_enemy_position_sync(data)
        
        "map_change":
            _handle_map_change(data)
        
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

func _handle_enemy_death(data: Dictionary):
    """Processa morte de inimigo recebida do servidor"""
    var enemy_id = data.get("enemy_id", "")
    var killer_id = data.get("killer_id", "")
    
    # Não processar morte de inimigo que o próprio player matou
    var local_id = local_player_info.get("id", "")
    if killer_id == local_id:
        return
    
    _log_to_file("💀 Inimigo morto: " + enemy_id + " por " + killer_id)
    enemy_death_received.emit(enemy_id, killer_id)

# Função removida - não mais necessária no sistema server-side

func _handle_enemies_update(data: Dictionary):
    """Processa atualizações de inimigos do servidor"""
    var enemies_data = data.get("enemies", [])
    enemies_update_received.emit(enemies_data)

func _handle_enemies_state(data: Dictionary):
    """Processa estado inicial dos inimigos"""
    var enemies_data = data.get("enemies", [])
    var map_name = data.get("map_name", "")
    _log_to_file("📋 Recebido estado de " + str(enemies_data.size()) + " inimigos do mapa " + map_name)
    enemies_state_received.emit(enemies_data)

func _handle_enemy_death_server(data: Dictionary):
    """Processa morte de inimigo do servidor"""
    if data.get("type") == "enemy_death":
        var enemy_id = data.get("enemy_id", "")
        var killer_id = data.get("killer_id", "")
        _log_to_file("💀 Inimigo morto pelo servidor: " + enemy_id + " por " + killer_id)
        enemy_death_received.emit(data)

func _handle_enemy_position_sync(data: Dictionary):
    """Processa sincronização de posição de inimigo"""
    var enemy_id = data.get("enemy_id", "")
    var controller_id = data.get("controller_id", "")
    
    # Não processar sync do próprio inimigo
    var local_id = local_player_info.get("id", "")
    if controller_id == local_id:
        return
    
    # Emitir sinal para o mapa processar
    enemy_position_sync_received.emit(data)

func _handle_map_change(data: Dictionary):
    """Processa mudança de mapa recebida do servidor"""
    var player_id = data.get("player_id", "")
    var current_map = data.get("current_map", "")
    var spawn_position = data.get("spawn_position", {})
    
    # Não processar mudança do próprio player
    var local_id = local_player_info.get("id", "")
    if player_id == local_id:
        return
    
    # Atualizar posição do player nos dados
    if player_id in players_data and spawn_position.has("x") and spawn_position.has("y"):
        players_data[player_id]["position"] = spawn_position
        _log_to_file("🗺️ Player " + player_id + " spawn em " + current_map + ": " + str(spawn_position))
    
    _log_to_file("🗺️ Player " + player_id + " mudou para: " + current_map)
    map_change_received.emit(player_id, current_map)

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

func _handle_player_sync_ack(data: Dictionary):
    """Processa confirmação de sincronização do servidor para reconciliação"""
    var sequence = data.get("sequence", 0)
    var server_position = data.get("position", {"x": 0, "y": 0})
    var server_velocity = data.get("velocity", {"x": 0, "y": 0})
    var server_timestamp = data.get("server_timestamp", 0.0)
    
    # Encontrar jogador local e aplicar reconciliação
    var local_id = local_player_info.get("id", "")
    if local_id.is_empty():
        return
        
    # Enviar dados de reconciliação para o jogador local
    var reconciliation_data = {
        "position": server_position,
        "velocity": server_velocity,
        "sequence": sequence,
        "server_timestamp": server_timestamp
    }
    
    _log_to_file("🔄 Recebido ACK do servidor - seq: " + str(sequence))
    
    # Emitir sinal para o jogador aplicar reconciliação
    if has_signal("server_reconciliation"):
        emit_signal("server_reconciliation", reconciliation_data)

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
