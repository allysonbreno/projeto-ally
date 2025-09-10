extends MultiplayerEnemy
class_name SlimeEnemy

var jump_timer: float = 0.0
var jump_interval: float = 2.0
var jump_force: float = 300.0
var can_jump: bool = true

func _ready() -> void:
	# Configurações específicas do Slime
	enemy_type = "slime"
	speed = 90.0  # Mais lento que Orc
	hp = 75
	max_hp = 75
	attack_interval = 1.0  # Ataque mais lento
	contact_range = 22.0  # Alcance menor
	attack_damage = 8  # Dano menor
	
	# FPS específicos do Slime (mais fluidos)
	fps_idle = 6
	fps_walk = 8
	fps_attack = 8
	
	# Chamar _ready da classe pai
	super._ready()
	
	print("🟢 Slime enemy inicializado: " + enemy_id)

func _process_local_movement(delta: float) -> void:
	"""Override para adicionar comportamento de salto do Slime"""
	if not is_controlled_locally:
		return
	
	# Lógica de salto específica do Slime
	jump_timer -= delta
	if jump_timer <= 0.0 and is_on_floor() and can_jump:
		_try_jump()
		jump_timer = jump_interval
	
	# Chamar movimento base da classe pai
	super._process_local_movement(delta)

func _try_jump() -> void:
	"""Slime pode fazer pequenos saltos durante movimento"""
	if target_player and is_on_floor():
		var distance_to_player = global_position.distance_to(target_player.global_position)
		
		# Só pula se não está muito longe nem muito perto
		if distance_to_player > 40.0 and distance_to_player < 120.0:
			velocity.y = -jump_force
			print("🟢 Slime " + enemy_id + " saltou!")

func _drop_item() -> void:
	"""Slime dropa Poção de Vida"""
	# 80% chance de dropar poção
	if randf() < 0.8:
		var potion_item = {
			"name": "Poção de Vida",
			"type": "consumable",
			"heal": 25,
			"icon": "health_potion.png"
		}
		
		# Criar item no chão
		var ItemDropScene = load("res://scripts/item_drop.gd")
		var item_drop = ItemDropScene.new()
		
		# Posicionar no local da morte
		item_drop.position = global_position
		
		# Configurar item
		item_drop.setup_item(potion_item)
		
		# Adicionar à cena
		get_parent().add_child(item_drop)
		
		print("🧪 Slime dropou Poção de Vida em " + str(global_position))
	else:
		print("🟢 Slime não dropou nada")

func take_damage(amount: int) -> void:
	"""Override para efeitos visuais específicos do Slime"""
	# Chamar dano base
	super.take_damage(amount)
	
	# Efeito visual específico: Slime "treme" quando toma dano
	if hp > 0:
		var tween = create_tween()
		var original_scale = sprite.scale
		tween.tween_property(sprite, "scale", original_scale * 1.2, 0.1)
		tween.tween_property(sprite, "scale", original_scale, 0.1)
		print("🟢 Slime " + enemy_id + " tremeu de dor!")