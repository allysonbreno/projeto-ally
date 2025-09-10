extends Node
class_name MultiplayerManager

# ============================================================================
# MULTIPLAYER MANAGER - CLIENT RENDERING ONLY (SERVER-AUTHORITATIVE)
# ============================================================================
# Este sistema é 100% server-side. O cliente apenas:
# - Envia input para o servidor
# - Recebe updates do servidor 
# - Renderiza o estado autoritativo do servidor

# Sinais para comunicação com a UI
signal login_response(success: bool, message: String, player_info: Dictionary)
signal player_connected(player_info: Dictionary)
signal player_disconnected(player_id: String)
signal connection_lost()
signal player_sync_received(player_id: String, player_data: Dictionary)
signal map_change_received(player_id: String, player_map: String)
signal server_reconciliation(reconciliation_data: Dictionary)
signal players_list_received(players: Dictionary)
signal player_left_map_received(player_id: String)
signal enemy_death_received(enemy_id: String, killer_id: String)
signal enemy_position_sync_received(sync_data: Dictionary)
signal enemies_state_received(enemies: Array)
signal enemies_update_received(enemies: Array)

# WebSocket
var socket: WebSocketPeer
var socket_connected: bool = false
var is_logged_in: bool = false

# Player info (apenas para referência local)
var local_player_info: Dictionary = {}
var rendered_players: Dictionary = {}  # Players sendo renderizados

# Estado da conexão 
var connection_logged: bool = false  # Para evitar spam de logs

# Log file
var log_file: FileAccess

func _ready():
    _setup_log()

func _setup_log():
    """Configura arquivo de log do cliente"""
    log_file = FileAccess.open("logs_cliente.txt", FileAccess.WRITE)
    if log_file:
        log_file.store_line("CLIENTE GODOT - LOGS MULTIPLAYER")
        log_file.store_line("====================================")
        log_file.flush()
        print("✅ Log do cliente inicializado: logs_cliente.txt")
    else:
        print("⚠️ Falha ao criar arquivo de log do cliente")

func _log_to_file(message: String):
    """Escreve no arquivo de log"""
    var timestamp = Time.get_datetime_string_from_system()
    var log_message = "[" + timestamp + "] " + message
    print(log_message)
    
    # Verificar se log_file ainda é válido
    if log_file and log_file.is_open():
        log_file.store_line(log_message)
        log_file.flush()
    elif log_file == null:
        # Tentar recriar arquivo de log se foi perdido
        _setup_log()
        if log_file and log_file.is_open():
            log_file.store_line(log_message)
            log_file.flush()

# ============================================================================
# CONEXÃO COM SERVIDOR
# ============================================================================

func connect_to_server(host: String, port: int) -> bool:
    """Conecta ao servidor WebSocket"""
    _log_to_file("[CONNECT] Tentando conectar ao servidor: " + host + ":" + str(port))
    
    socket = WebSocketPeer.new()
    var url = "ws://" + host + ":" + str(port)
    _log_to_file("[CONNECT] URL WebSocket: " + url)
    
    var error = socket.connect_to_url(url)
    
    if error != OK:
        _log_to_file("❌ Falha na conexão WebSocket - Código: " + str(error))
        _log_to_file("❌ Verifique se o servidor Python está rodando!")
        return false
    
    # NÃO definir socket_connected = true aqui - será definido no _process() quando OPEN
    socket_connected = false  # Garantir que está false até conexão real
    connection_logged = false  # Resetar para permitir logs de nova conexão
    _log_to_file("[CONNECT] Comando connect_to_url() executado. Aguardando STATE_OPEN...")
    
    return true

func disconnect_from_server():
    """Desconecta do servidor"""
    if socket:
        socket.close()
        socket_connected = false
        is_logged_in = false
        _log_to_file("🔌 Desconectado do servidor")

# ============================================================================
# PROCESSAMENTO DE MENSAGENS (PASSIVO - APENAS RECEBE DO SERVIDOR)
# ============================================================================

func _process(_delta):
    """Processa mensagens do servidor"""
    if not socket:
        # Socket ainda não foi inicializado - aguardando conexão
        return
    
    socket.poll()
    var state = socket.get_ready_state()
    
    # Debug: Log estado uma vez por segundo
    var current_time = Time.get_unix_time_from_system()
    if not has_meta("last_debug_time") or (current_time - get_meta("last_debug_time", 0.0)) > 1.0:
        set_meta("last_debug_time", current_time)
        _log_to_file("[PROCESS] WebSocket Estado: " + str(state) + " | socket_connected: " + str(socket_connected))
    
    if state == WebSocketPeer.STATE_OPEN:
        # Atualizar estado de conexão
        if not socket_connected:
            socket_connected = true
            _log_to_file("✅ WebSocket CONECTADO! Estado: OPEN")
            _log_to_file("✅ socket_connected = true")
        
        # Log apenas uma vez quando conecta
        if not connection_logged:
            connection_logged = true
        
        # Processar mensagens
        while socket.get_available_packet_count() > 0:
            var packet = socket.get_packet()
            var message = packet.get_string_from_utf8()
            _process_server_message(message)
            
    elif state == WebSocketPeer.STATE_CLOSED:
        if socket_connected:  # Só processar se estava conectado antes
            _log_to_file("[DISCONNECT] WebSocket mudou para STATE_CLOSED")
            _log_to_file("[DISCONNECT] socket_connected era true, processando perda de conexão")
            socket_connected = false
            _handle_connection_lost()
        # STATE_CLOSED mas socket_connected já false = normal após disconnect - sem log para evitar spam
            
    elif state == WebSocketPeer.STATE_CONNECTING:
        if not connection_logged:
            _log_to_file("🔄 Estado: CONNECTING - aguardando servidor...")
            connection_logged = true
    else:
        if not connection_logged:
            _log_to_file("⚠️ Estado WebSocket: " + str(state))
            connection_logged = true

func _process_server_message(message: String):
    """Processa mensagem recebida do servidor (apenas renderização)"""
    var data = JSON.parse_string(message)
    if not data:
        _log_to_file("❌ Mensagem inválida recebida")
        return
    
    var message_type = data.get("type", "")
    
    match message_type:
        "login_response":
            _handle_login_response(data)
        "player_sync":
            _handle_player_sync(data)
        "players_update":
            _handle_players_update(data)
        "players_list":
            _handle_players_list(data)
        "player_connected":
            _handle_player_connected(data)
        "player_disconnected":
            _handle_player_disconnected(data)
        "map_change":
            _handle_map_change(data)
        "server_reconciliation":
            _handle_server_reconciliation(data)
        "enemy_death":
            enemy_death_received.emit(str(data.get("enemy_id", "")), str(data.get("killer_id", "")))
        "enemy_position_sync":
            enemy_position_sync_received.emit(data)
        "enemies_state":
            enemies_state_received.emit(data.get("enemies", []))
        "enemies_update":
            enemies_update_received.emit(data.get("enemies", []))
        "player_left_map":
            var _pid = str(data.get("player_id", ""))
            if _pid != "":
                player_left_map_received.emit(_pid)
        _:
            _log_to_file("❓ Tipo de mensagem desconhecido: " + message_type)

# ============================================================================
# HANDLERS DE MENSAGENS DO SERVIDOR
# ============================================================================

func _handle_login_response(data: Dictionary):
    """Processa resposta de login"""
    var success = data.get("success", false)
    var message = data.get("message", "")
    
    if success:
        local_player_info = data.get("player_info", {})
        is_logged_in = true
        _log_to_file("✅ Login realizado! ID: " + str(local_player_info.get("id", "")))
    else:
        _log_to_file("❌ Falha no login: " + message)
    
    login_response.emit(success, message, local_player_info)

func _handle_players_list(data: Dictionary):
    """Processa lista inicial de players após login"""
    var players_data = data.get("players", {})
    _log_to_file("📋 Recebida lista com " + str(players_data.size()) + " players")
    
    # Atualizar dados renderizados com todos os players
    for player_id in players_data.keys():
        var player_data = players_data[player_id]
        rendered_players[player_id] = player_data
        _log_to_file("👤 Player listado: " + str(player_data.get("name", "?")) + " (" + player_id + ")")
    if has_signal("players_list_received"):
        players_list_received.emit(players_data)

func _handle_player_sync(data: Dictionary):
    """Recebe estado de um player do servidor e renderiza"""
    var player_id = data.get("player_id", "")
    var player_data = data.get("player_data", {})
    
    if player_id == "":
        return
    
    # Atualizar dados renderizados
    rendered_players[player_id] = player_data
    
    # Emitir sinal para o jogo processar
    player_sync_received.emit(player_id, player_data)
    
    # Log apenas para debug
    var pos = player_data.get("position", {})
    _log_to_file("🎮 Player sync: " + player_id + " pos: (" + str(pos.get("x", 0)) + ", " + str(pos.get("y", 0)) + ")")

func _handle_players_update(data: Dictionary):
    """Recebe estado de múltiplos players do servidor"""
    var players_data = data.get("players", {})
    
    for player_id in players_data:
        var player_data = players_data[player_id]
        rendered_players[player_id] = player_data
    
    _log_to_file("📊 Sincronização de " + str(players_data.size()) + " players")

func _handle_player_connected(data: Dictionary):
    """Novo player conectou"""
    var player_info = data.get("player_info", {})
    var player_id = str(player_info.get("id", ""))
    
    if player_id != "" and player_id != str(local_player_info.get("id", "")):
        _log_to_file("👋 Novo player: " + str(player_info.get("name", "")))
        player_connected.emit(player_info)

func _handle_player_disconnected(data: Dictionary):
    """Player desconectou"""
    var player_id = data.get("player_id", "")
    
    if player_id in rendered_players:
        rendered_players.erase(player_id)
        _log_to_file("👋 Player desconectou: " + player_id)
        player_disconnected.emit(player_id)

func _handle_connection_lost():
    """Conexão perdida"""
    socket_connected = false
    is_logged_in = false
    connection_logged = false  # Permitir logs de nova conexão
    _log_to_file("[DISCONNECT] _handle_connection_lost() chamado")
    _log_to_file("[DISCONNECT] Emitindo sinal connection_lost")
    connection_lost.emit()

func _handle_map_change(data: Dictionary):
    """Processa mudança de mapa de um player"""
    var player_id = data.get("player_id", "")
    var player_map = data.get("player_map", "")
    
    if player_id != "" and player_map != "":
        _log_to_file("🗺️ Player " + player_id + " mudou para mapa: " + player_map)
        map_change_received.emit(player_id, player_map)

func _handle_server_reconciliation(data: Dictionary):
    """Processa dados de reconciliação do servidor"""
    var reconciliation_data = data.get("reconciliation_data", {})
    
    if not reconciliation_data.is_empty():
        _log_to_file("🔄 Reconciliação do servidor recebida")
        server_reconciliation.emit(reconciliation_data)

# ============================================================================
# ENVIO DE DADOS PARA SERVIDOR (APENAS INPUT)
# ============================================================================

func send_login(player_name: String):
    """Envia pedido de login"""
    _log_to_file("🔑 Tentando fazer login com nome: " + player_name)
    
    if not socket_connected:
        _log_to_file("❌ Login falhou: socket_connected = false")
        return false
    
    if not socket:
        _log_to_file("❌ Login falhou: socket = null")
        return false
    
    var state = socket.get_ready_state()
    if state != WebSocketPeer.STATE_OPEN:
        _log_to_file("❌ Login falhou: WebSocket estado = " + str(state) + " (esperado OPEN)")
        return false
    
    var login_data = {
        "type": "login",
        "player_name": player_name
    }
    
    _log_to_file("🔑 Enviando dados de login: " + str(login_data))
    return _send_to_server(login_data)

func send_input(input_data: Dictionary):
    """Envia input para o servidor processar"""
    if not is_logged_in:
        return false
    
    var message = {
        "type": "player_input",
        "input": input_data
    }
    
    return _send_to_server(message)

func send_player_update(pos: Vector2, velocity: Vector2, animation: String, facing: int, hp: int):
    """Envia atualização do player para o servidor"""
    if not is_logged_in:
        return false
    
    var message = {
        "type": "player_update",
        "position": {"x": pos.x, "y": pos.y},
        "velocity": {"x": velocity.x, "y": velocity.y},
        "animation": animation,
        "facing": facing,
        "hp": hp
    }
    
    return _send_to_server(message)

func send_player_update_with_sequence(pos: Vector2, velocity: Vector2, animation: String, facing: int, hp: int, sequence: int):
    """Envia atualização do player com sequência para o servidor"""
    if not is_logged_in:
        return false
    
    var message = {
        "type": "player_update",
        "position": {"x": pos.x, "y": pos.y},
        "velocity": {"x": velocity.x, "y": velocity.y},
        "animation": animation,
        "facing": facing,
        "hp": hp,
        "sequence": sequence
    }
    
    return _send_to_server(message)

func send_map_change(new_map: String):
    """Solicita mudança de mapa"""
    if not is_logged_in:
        return false
    
    var message = {
        "type": "map_change",
        "current_map": new_map
    }
    
    return _send_to_server(message)

func _send_to_server(data: Dictionary) -> bool:
    """Envia dados para o servidor"""
    if not socket or socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
        return false
    
    var json_string = JSON.stringify(data)
    var packet = json_string.to_utf8_buffer()
    socket.send(packet)
    return true

# Compatibilidade com scripts antigos
func _send_message(data: Dictionary) -> bool:
    return _send_to_server(data)

# ============================================================================
# GETTERS PARA RENDERIZAÇÃO
# ============================================================================

func get_local_player_id() -> String:
    """Retorna ID do player local"""
    return str(local_player_info.get("id", ""))

func get_local_player_name() -> String:
    """Retorna nome do player local"""
    return str(local_player_info.get("name", ""))

func get_rendered_players() -> Dictionary:
    """Retorna todos os players sendo renderizados"""
    return rendered_players

func get_players_data() -> Dictionary:
    """Retorna dados de todos os players renderizados"""
    return rendered_players

func get_player_data(player_id: String) -> Dictionary:
    """Retorna dados de um player específico"""
    return rendered_players.get(player_id, {})

func is_local_player(player_id: String) -> bool:
    """Verifica se é o player local"""
    return player_id == get_local_player_id()

# ============================================================================
# CLEANUP
# ============================================================================

func _exit_tree():
    _log_to_file("[CLEANUP] _exit_tree() chamado!")
    _log_to_file("[CLEANUP] Parent atual: " + str(get_parent()))
    _log_to_file("[CLEANUP] Socket existe? " + str(socket != null))
    _log_to_file("[CLEANUP] socket_connected: " + str(socket_connected))
    
    # IMPORTANTE: NÃO fechar socket se still conectado e transferindo entre cenas
    if socket and socket_connected and get_parent() != null:
        _log_to_file("[CLEANUP] MANTENDO socket aberto - transferindo entre cenas")
        # NÃO fechar - socket ainda está em uso
    elif socket:
        _log_to_file("[CLEANUP] Fechando socket...")
        socket.close()
    
    if log_file:
        log_file.close()
