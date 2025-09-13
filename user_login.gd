extends Control

var username_input: LineEdit
var password_input: LineEdit
var login_button: Button
var register_button: Button
var status_label: Label
var title_label: Label

var multiplayer_manager: MultiplayerManager

# Configurações do servidor
const SERVER_HOST: String = "localhost"
const SERVER_PORT: int = 8765

func _ready():
	# Encontrar nós
	username_input = $VBoxContainer/UsernameInput
	password_input = $VBoxContainer/PasswordInput
	login_button = $VBoxContainer/HBoxContainer/LoginButton
	register_button = $VBoxContainer/HBoxContainer/RegisterButton
	status_label = $VBoxContainer/StatusLabel
	title_label = $VBoxContainer/TitleLabel
	
	# Criar e configurar MultiplayerManager
	multiplayer_manager = MultiplayerManager.new()
	add_child(multiplayer_manager)
	
	# Conectar sinais
	multiplayer_manager.connection_lost.connect(_on_connection_lost)
	multiplayer_manager.login_response.connect(_on_login_response)
	multiplayer_manager.register_response.connect(_on_register_response)
	
	# Configurar interface
	login_button.pressed.connect(_on_login_button_pressed)
	register_button.pressed.connect(_on_register_button_pressed)
	username_input.text_submitted.connect(_on_username_submitted)
	password_input.text_submitted.connect(_on_password_submitted)
	
	# Status inicial
	_update_status("Digite suas credenciais", Color.WHITE)
	
	# Dar foco ao input
	username_input.grab_focus()
	
	# Conectar ao servidor automaticamente
	_connect_to_server()

func _on_login_button_pressed():
	if not multiplayer_manager.socket_connected:
		_connect_to_server()
	else:
		_send_login()

func _on_register_button_pressed():
	if not multiplayer_manager.socket_connected:
		_connect_to_server()
	else:
		_send_register()

func _on_username_submitted(_text: String):
	password_input.grab_focus()

func _on_password_submitted(_text: String):
	if multiplayer_manager.socket_connected:
		_send_login()
	else:
		_connect_to_server()

func _connect_to_server():
	_update_status("Conectando ao servidor...", Color.YELLOW)
	_disable_buttons()
	
	var success = multiplayer_manager.connect_to_server(SERVER_HOST, SERVER_PORT)
	if success:
		_wait_for_connection()
	else:
		_on_connection_failed()

func _wait_for_connection():
	"""Aguarda a conexão WebSocket ser estabelecida"""
	_update_status("Aguardando conexão...", Color.YELLOW)
	
	# Aguardar até 5 segundos pela conexão
	var max_wait_time = 5.0
	var elapsed_time = 0.0
	
	while elapsed_time < max_wait_time:
		await get_tree().process_frame
		elapsed_time += get_process_delta_time()
		
		# Verificar se socket existe e está conectado
		if multiplayer_manager.socket and multiplayer_manager.socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_on_connection_established()
			return
		
		# Verificar se falhou
		if multiplayer_manager.socket and multiplayer_manager.socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			_on_connection_failed()
			return
	
	# Timeout
	_on_connection_failed()

func _on_connection_established():
	_update_status("Conectado! Digite suas credenciais", Color.GREEN)
	_enable_buttons()

func _on_connection_failed():
	_update_status("Falha na conexão! Verifique se o servidor está ligado", Color.RED)
	_enable_buttons()

func _on_connection_lost():
	_update_status("Conexão perdida! Verifique se o servidor está ligado", Color.RED)
	_enable_buttons()

func _send_login():
	var username = username_input.text.strip_edges()
	var password = password_input.text.strip_edges()
	
	if username.is_empty() or password.is_empty():
		_update_status("Digite usuário e senha!", Color.ORANGE)
		return
	
	_update_status("Fazendo login...", Color.YELLOW)
	_disable_buttons()
	
	multiplayer_manager.send_message({
		"type": "login",
		"username": username,
		"password": password
	})

func _send_register():
	var username = username_input.text.strip_edges()
	var password = password_input.text.strip_edges()
	
	if username.is_empty() or password.is_empty():
		_update_status("Digite usuário e senha!", Color.ORANGE)
		return
		
	if len(username) < 3 or len(password) < 6:
		_update_status("Usuário min 3 chars, senha min 6!", Color.ORANGE)
		return
	
	_update_status("Registrando usuário...", Color.YELLOW)
	_disable_buttons()
	
	multiplayer_manager.send_message({
		"type": "register",
		"username": username,
		"password": password
	})

func _on_login_response(success: bool, message: String, player_info: Dictionary):
	_enable_buttons()
	
	if success:
		if player_info.get("needs_character", false):
			_update_status("Login realizado! Carregando seleção de personagem...", Color.GREEN)
			await get_tree().create_timer(1.0).timeout
			_go_to_character_selection()
		else:
			_update_status("Login realizado! Carregando jogo...", Color.GREEN)
			await get_tree().create_timer(1.0).timeout
			_go_to_multiplayer_game()
	else:
		_update_status("Erro: " + message, Color.RED)

func _on_register_response(success: bool, message: String):
	_enable_buttons()
	
	if success:
		_update_status(message, Color.GREEN)
		# Limpar campos após registro bem-sucedido
		password_input.text = ""
		username_input.grab_focus()
	else:
		_update_status("Erro: " + message, Color.RED)

func _go_to_character_selection():
	# Ir para seleção de personagem
	var character_selection_scene = preload("res://character_selection.tscn")
	var character_selection = character_selection_scene.instantiate()
	
	# Remover manager da cena atual antes de passar
	if multiplayer_manager.get_parent():
		multiplayer_manager.get_parent().remove_child(multiplayer_manager)
	
	# Passar o manager para a cena de seleção
	character_selection.setup_multiplayer(multiplayer_manager)
	
	# Trocar cena
	get_tree().root.add_child(character_selection)
	queue_free()

func _go_to_multiplayer_game():
	# Ir direto para o jogo
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

func _disable_buttons():
	login_button.disabled = true
	register_button.disabled = true
	username_input.editable = false
	password_input.editable = false

func _enable_buttons():
	login_button.disabled = false
	register_button.disabled = false
	username_input.editable = true
	password_input.editable = true

func _update_status(text: String, color: Color):
	status_label.text = text
	status_label.modulate = color
	print("[USER_LOGIN] ", text)