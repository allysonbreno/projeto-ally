extends Control

var player_name_input: LineEdit
var connect_button: Button
var status_label: Label  
var server_info_label: Label

var multiplayer_manager: MultiplayerManager

# Configurações do servidor
const SERVER_HOST: String = "localhost"
const SERVER_PORT: int = 8765

func _ready():
    # Encontrar nós
    player_name_input = $VBoxContainer/NameInput
    connect_button = $VBoxContainer/ConnectButton
    status_label = $VBoxContainer/StatusLabel
    server_info_label = $VBoxContainer/ServerLabel
    
    # Criar e configurar MultiplayerManager
    multiplayer_manager = MultiplayerManager.new()
    add_child(multiplayer_manager)
    
    # Conectar sinais
    multiplayer_manager.connection_lost.connect(_on_connection_lost)
    multiplayer_manager.login_response.connect(_on_login_response)
    
    # Configurar interface
    connect_button.pressed.connect(_on_connect_button_pressed)
    player_name_input.text_submitted.connect(_on_name_submitted)
    
    # Nome aleatório inicial
    player_name_input.text = "Jogador" + str(randi_range(100, 999))
    
    # Informações do servidor
    server_info_label.text = "Servidor: ws://%s:%d" % [SERVER_HOST, SERVER_PORT]
    
    # Status inicial
    _update_status("Desconectado", Color.RED)
    
    # Dar foco ao input
    player_name_input.grab_focus()

func _on_connect_button_pressed():
    if not multiplayer_manager.socket_connected:
        _connect_to_server()
    else:
        _login_to_server()

func _on_name_submitted(_text: String):
    if multiplayer_manager.socket_connected:
        _login_to_server()
    else:
        _connect_to_server()

func _connect_to_server():
    print("[LOGIN] _connect_to_server() chamado")
    var player_name = player_name_input.text.strip_edges()
    
    if player_name.is_empty():
        _update_status("Digite um nome válido!", Color.ORANGE)
        return
    
    _update_status("Conectando ao servidor...", Color.YELLOW)
    connect_button.disabled = true
    player_name_input.editable = false
    
    print("[LOGIN] Chamando multiplayer_manager.connect_to_server()")
    var success = multiplayer_manager.connect_to_server(SERVER_HOST, SERVER_PORT)
    if success:
        # Aguardar a conexão real ser estabelecida
        _wait_for_connection()
    else:
        _on_connection_failed()

func _login_to_server():
    var player_name = player_name_input.text.strip_edges()
    
    if player_name.is_empty():
        _update_status("Digite um nome válido!", Color.ORANGE)
        return
    
    _update_status("Fazendo login...", Color.YELLOW)
    connect_button.disabled = true
    
    multiplayer_manager.send_login(player_name)

func _on_connection_established():
    _update_status("Conectado! Digite seu nome e pressione Enter", Color.GREEN)
    connect_button.disabled = false
    connect_button.text = "Entrar no Jogo"

func _wait_for_connection():
    """Aguarda a conexão WebSocket ser estabelecida"""
    print("[LOGIN] _wait_for_connection() iniciado")
    _update_status("Aguardando conexão...", Color.YELLOW)
    
    # Aguardar até 5 segundos pela conexão
    var max_wait_time = 5.0
    var elapsed_time = 0.0
    
    while elapsed_time < max_wait_time:
        await get_tree().process_frame
        elapsed_time += get_process_delta_time()
        
        # Verificar se socket existe e está conectado
        if multiplayer_manager.socket and multiplayer_manager.socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
            print("[LOGIN] Socket encontrado com estado OPEN!")
            _on_connection_established()
            return
        
        # Verificar se falhou
        if multiplayer_manager.socket and multiplayer_manager.socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
            _on_connection_failed()
            return
        
        # Atualizar status a cada segundo
        if int(elapsed_time) != int(elapsed_time - get_process_delta_time()):
            var remaining = int(max_wait_time - elapsed_time)
            _update_status("Conectando... (%d)" % remaining, Color.YELLOW)
    
    # Timeout
    _update_status("Timeout na conexão", Color.RED)
    _on_connection_failed()

func _on_connection_failed():
    _update_status("Falha na conexão! Verifique se o servidor está ligado", Color.RED)
    connect_button.disabled = false
    connect_button.text = "Conectar ao Servidor"
    player_name_input.editable = true

func _on_connection_lost():
    _update_status("Conexão perdida! Verifique se o servidor está ligado", Color.RED)
    connect_button.disabled = false
    connect_button.text = "Conectar ao Servidor"
    player_name_input.editable = true

func _on_login_response(success: bool, message: String, _player_info: Dictionary):
    connect_button.disabled = false
    
    if success:
        _update_status("Login realizado! Carregando jogo...", Color.GREEN)
        
        # Aguardar um pouco e ir para o jogo
        await get_tree().create_timer(1.0).timeout
        _go_to_multiplayer_game()
    else:
        _update_status("Erro no login: " + message, Color.RED)
        connect_button.text = "Tentar Novamente"

func _go_to_multiplayer_game():
    # Passar MultiplayerManager para a próxima cena
    var multiplayer_game_scene = preload("res://multiplayer_game.tscn")
    var multiplayer_game = multiplayer_game_scene.instantiate()
    
    # Remover manager da cena atual antes de passar
    if multiplayer_manager.get_parent():
        multiplayer_manager.get_parent().remove_child(multiplayer_manager)
    
    # Passar o manager para a cena do jogo
    multiplayer_game.setup_multiplayer(multiplayer_manager)
    
    # Trocar cena
    get_tree().root.add_child(multiplayer_game)
    queue_free()

func _update_status(text: String, color: Color):
    status_label.text = text
    status_label.modulate = color
    print("[LOGIN] ", text)
