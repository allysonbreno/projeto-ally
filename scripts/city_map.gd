extends Node2D

var main: Node
var player: Player

# Ground fixo no mundo + largura responsiva
var ground_body: StaticBody2D
var ground_shape: RectangleShape2D
var ground_col: CollisionShape2D
var ground_sprite: Sprite2D
var ground_width: float = 1800.0

const GROUND_H: float = 24.0
const GROUND_Y: float = 220.0
const GROUND_COLOR: Color = Color(0.25, 0.25, 0.25)

func setup(main_ref: Node) -> void:
	main = main_ref
	_build_world()
	_spawn_player()

func _build_world() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	ground_width = max(1800.0, vp.x * 2.0)

	ground_body = StaticBody2D.new()
	ground_shape = RectangleShape2D.new()
	ground_shape.size = Vector2(ground_width, GROUND_H)
	ground_col = CollisionShape2D.new()
	ground_col.shape = ground_shape
	ground_body.add_child(ground_col)
	add_child(ground_body)

	ground_body.position = Vector2(0.0, GROUND_Y)
	ground_body.set_collision_layer_value(3, true)
	ground_body.set_collision_mask_value(1, true)
	ground_body.set_collision_mask_value(2, true)

	ground_sprite = Sprite2D.new()
	ground_sprite.centered = true
	add_child(ground_sprite)
	_set_sprite_rect(ground_sprite, Vector2(ground_width, GROUND_H), GROUND_COLOR)
	ground_sprite.position = ground_body.position

	var label: Label = Label.new()
	label.text = "Cidade"
	label.position = Vector2(10, 10)
	add_child(label)

	get_tree().root.size_changed.connect(_on_window_resized)

func _on_window_resized() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	ground_width = max(1800.0, vp.x * 2.0)
	ground_shape.size = Vector2(ground_width, GROUND_H)
	_set_sprite_rect(ground_sprite, Vector2(ground_width, GROUND_H), GROUND_COLOR)
	ground_sprite.position = ground_body.position

func _set_sprite_rect(sprite: Sprite2D, size: Vector2, color: Color) -> void:
	var w: int = int(max(2.0, size.x))
	var h: int = int(max(2.0, size.y))
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	sprite.texture = tex

func _spawn_player() -> void:
	const PlayerScene := preload("res://scripts/player.gd")
	player = PlayerScene.new()
	player.position = Vector2(0.0, GROUND_Y - (GROUND_H * 0.5) - 20.0)
	player.main = main
	add_child(player)

	# passa referência para o HUD (para cooldown do ataque)
	if main and main.has_method("hud") == false:
		pass
	if "hud" in main:
		main.hud.set_player(player)

	var cam: Camera2D = Camera2D.new()
	player.add_child(cam)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.make_current()
