extends Control

var character_name_input: LineEdit
var check_name_button: Button
var create_button: Button
var status_label: Label
var character_buttons: Array[Button] = []
var selected_character_type: String = ""

var multiplayer_manager: MultiplayerManager

# Tipos de personagem disponíveis
const CHARACTER_TYPES = {
	"warrior": {
		"name": "Guerreiro",
		"description": "Alto ataque físico e resistência",
		"stats": "FOR: 8, DEF: 7, INT: 3, VIT: 7"
	},
	"mage": {
		"name": "Mago", 
		"description": "Alto poder mágico e conhecimento",
		"stats": "FOR: 3, DEF: 4, INT: 8, VIT: 5"
	},
	"archer": {
		"name": "Arqueiro",
		"description": "Balanceado e versátil",
		"stats": "FOR: 6, DEF: 5, INT: 6, VIT: 6"
	}
}

func _ready():
	# Encontrar nós
	character_name_input = $VBoxContainer/CharacterNameInput
	check_name_button = $VBoxContainer/HBoxContainer/CheckNameButton
	create_button = $VBoxContainer/HBoxContainer/CreateButton
	status_label = $VBoxContainer/StatusLabel
	
	# Encontrar botões de personagem
	character_buttons.append($VBoxContainer/CharacterSelection/WarriorButton)
	character_buttons.append($VBoxContainer/CharacterSelection/MageButton)
	character_buttons.append($VBoxContainer/CharacterSelection/ArcherButton)
	
	# Conectar sinais
	check_name_button.pressed.connect(_on_check_name_pressed)
	create_button.pressed.connect(_on_create_character_pressed)
	character_name_input.text_submitted.connect(_on_name_submitted)
	
	# Conectar botões de personagem
	character_buttons[0].pressed.connect(func(): _on_character_selected("warrior"))
	character_buttons[1].pressed.connect(func(): _on_character_selected("mage"))  
	character_buttons[2].pressed.connect(func(): _on_character_selected("archer"))
	
	# Estado inicial
	create_button.disabled = true
	_update_status("Selecione um personagem e digite um nome", Color.WHITE)
	
	# Dar foco ao input de nome
	character_name_input.grab_focus()

func setup_multiplayer(manager: MultiplayerManager):
	"""Recebe o MultiplayerManager da tela anterior"""
	multiplayer_manager = manager
	add_child(multiplayer_manager)
	
	# Conectar sinais específicos desta tela
	multiplayer_manager.check_character_name_response.connect(_on_check_character_name_response)
	multiplayer_manager.create_character_response.connect(_on_create_character_response)
	multiplayer_manager.login_response.connect(_on_login_response)

func _on_character_selected(character_type: String):
	selected_character_type = character_type
	
	# Atualizar visual dos botões
	for i in range(character_buttons.size()):
		var button = character_buttons[i]
		var types = ["warrior", "mage", "archer"]
		if types[i] == character_type:
			button.modulate = Color.GREEN
			button.text = CHARACTER_TYPES[character_type]["name"] + " [SELECIONADO]"
		else:
			button.modulate = Color.WHITE
			var other_type = types[i]
			button.text = CHARACTER_TYPES[other_type]["name"]
	
	# Mostrar informações do personagem
	var info = CHARACTER_TYPES[character_type]
	_update_status("Selecionado: " + info["name"] + " - " + info["description"] + " (" + info["stats"] + ")", Color.CYAN)
	
	_check_create_button_state()

func _on_name_submitted(_text: String):
	if selected_character_type != "":
		_on_check_name_pressed()

func _on_check_name_pressed():
	var character_name = character_name_input.text.strip_edges()
	
	if character_name.is_empty():
		_update_status("Digite um nome para o personagem!", Color.ORANGE)
		return
		
	if len(character_name) < 3:
		_update_status("Nome deve ter pelo menos 3 caracteres!", Color.ORANGE)
		return
	
	_update_status("Verificando disponibilidade do nome...", Color.YELLOW)
	check_name_button.disabled = true
	
	multiplayer_manager.send_message({
		"type": "check_character_name",
		"character_name": character_name
	})

func _on_create_character_pressed():
	var character_name = character_name_input.text.strip_edges()
	
	if character_name.is_empty() or selected_character_type.is_empty():
		_update_status("Selecione personagem e digite um nome!", Color.ORANGE)
		return
	
	_update_status("Criando personagem...", Color.YELLOW)
	create_button.disabled = true
	check_name_button.disabled = true
	_disable_character_buttons()
	
	multiplayer_manager.send_message({
		"type": "create_character",
		"character_name": character_name,
		"character_type": selected_character_type
	})

func _on_check_character_name_response(success: bool, message: String):
	check_name_button.disabled = false
	
	if success:
		_update_status("✓ " + message + " - Você pode criar o personagem!", Color.GREEN)
	else:
		_update_status("✗ " + message, Color.RED)
	
	_check_create_button_state()

func _on_create_character_response(success: bool, message: String):
	if success:
		_update_status("Personagem criado com sucesso! Entrando no jogo...", Color.GREEN)
		# O servidor automaticamente fará login no jogo após criar o personagem
	else:
		_update_status("Erro ao criar personagem: " + message, Color.RED)
		create_button.disabled = false
		check_name_button.disabled = false
		_enable_character_buttons()

func _on_login_response(success: bool, message: String, player_info: Dictionary):
	if success and not player_info.get("needs_character", false):
		# Login no jogo realizado com sucesso após criar personagem
		_update_status("Carregando jogo...", Color.GREEN)
		await get_tree().create_timer(1.0).timeout
		_go_to_multiplayer_game()
	elif not success:
		_update_status("Erro ao entrar no jogo: " + message, Color.RED)
		create_button.disabled = false
		check_name_button.disabled = false
		_enable_character_buttons()

func _go_to_multiplayer_game():
	# Ir para o jogo
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

func _check_create_button_state():
	var name_checked = status_label.text.begins_with("✓")
	var character_selected = selected_character_type != ""
	create_button.disabled = not (name_checked and character_selected)

func _disable_character_buttons():
	for button in character_buttons:
		button.disabled = true

func _enable_character_buttons():
	for button in character_buttons:
		button.disabled = false

func _update_status(text: String, color: Color):
	status_label.text = text
	status_label.modulate = color
	print("[CHAR_SELECT] ", text)