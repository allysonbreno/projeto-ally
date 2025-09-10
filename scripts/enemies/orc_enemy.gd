extends MultiplayerEnemy
class_name OrcEnemy

func _ready() -> void:
	# Configurações específicas do Orc
	enemy_type = "orc"
	speed = 112.0
	hp = 100
	max_hp = 100
	attack_interval = 0.7
	contact_range = 26.0
	attack_damage = 12
	
	# FPS específicos do Orc
	fps_idle = 6
	fps_walk = 8
	fps_attack = 7
	
	# Chamar _ready da classe pai
	super._ready()
	
	print("🧌 Orc enemy inicializado: " + enemy_id)

func _drop_item() -> void:
	"""Orc dropa Espada de Ferro"""
	# 100% chance de dropar espada
	var sword_item = {
		"name": "Espada de Ferro",
		"type": "weapon",
		"damage": 15,
		"icon": "sword.png"
	}
	
	# Criar item no chão
	var ItemDropScene = load("res://scripts/item_drop.gd")
	var item_drop = ItemDropScene.new()
	
	# Posicionar no local da morte
	item_drop.position = global_position
	
	# Configurar item
	item_drop.setup_item(sword_item)
	
	# Adicionar à cena
	get_parent().add_child(item_drop)
	
	print("⚔️ Orc dropou Espada de Ferro em " + str(global_position))