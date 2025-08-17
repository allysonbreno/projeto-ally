extends Node2D

var main: Node
var player: Player

func setup(main_ref: Node) -> void:
    main = main_ref
    _build_world()
    _spawn_player()

func _build_world() -> void:
    # chão (StaticBody2D + collider)
    var ground: StaticBody2D = StaticBody2D.new()
    var col: CollisionShape2D = CollisionShape2D.new()
    var shape: RectangleShape2D = RectangleShape2D.new()
    shape.size = Vector2(900, 24)
    col.shape = shape
    ground.position = Vector2(0, 200)
    ground.add_child(col)
    add_child(ground)

    # Layers do chão: cenário em layer 3
    ground.set_collision_layer_value(3, true)
    ground.set_collision_mask_value(1, true) # player
    ground.set_collision_mask_value(2, true) # inimigos

    # Visual do chão
    _add_rect_sprite(Vector2(900, 24), ground.position, Color(0.25, 0.25, 0.25))

    # Texto “Cidade”
    var label: Label = Label.new()
    label.text = "Cidade"
    label.position = Vector2(10, 10)
    add_child(label)

func _spawn_player() -> void:
    const PlayerScene := preload("res://scripts/player.gd")
    player = PlayerScene.new()
    player.position = Vector2(0, 0) # meio
    player.main = main
    add_child(player)

    # Camera simples (ordem ajustada para evitar aviso)
    var cam: Camera2D = Camera2D.new()
    player.add_child(cam)
    cam.position_smoothing_enabled = true
    cam.position_smoothing_speed = 8.0
    cam.make_current()

# helper para retângulos visuais
func _add_rect_sprite(size: Vector2, pos: Vector2, color: Color) -> void:
    var img: Image = Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
    img.fill(color)
    var tex: ImageTexture = ImageTexture.create_from_image(img)
    var sprite: Sprite2D = Sprite2D.new()
    sprite.texture = tex
    sprite.centered = true
    sprite.position = pos
    add_child(sprite)
