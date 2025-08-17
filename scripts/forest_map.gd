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
const GROUND_COLOR: Color = Color(0.20, 0.35, 0.20)

func setup(main_ref: Node) -> void:
    main = main_ref
    _build_world()
    _spawn_player()
    _spawn_enemies(5)
    main.set_enemies_to_kill(5)

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

    var base_y: float = GROUND_Y
    var xs: Array[float] = [-300.0, 0.0, 300.0]
    for i in range(xs.size()):
        var plat: StaticBody2D = StaticBody2D.new()
        var s: RectangleShape2D = RectangleShape2D.new()
        s.size = Vector2(200, 16)
        var c: CollisionShape2D = CollisionShape2D.new()
        c.shape = s
        plat.position = Vector2(xs[i], base_y - 100.0 - float(i) * 20.0)
        plat.add_child(c)
        add_child(plat)
        plat.set_collision_layer_value(3, true)
        plat.set_collision_mask_value(1, true)
        plat.set_collision_mask_value(2, true)

        var spr: Sprite2D = Sprite2D.new()
        _set_sprite_rect(spr, Vector2(200, 16), Color(0.25, 0.45, 0.25))
        spr.centered = true
        spr.position = plat.position
        add_child(spr)

    var label: Label = Label.new()
    label.text = "Floresta"
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

    var left_x: float = -ground_width * 0.5 + 64.0
    var stand_y: float = GROUND_Y - (GROUND_H * 0.5) - 20.0
    player.position = Vector2(left_x, stand_y)
    player.velocity = Vector2.ZERO
    player.main = main
    add_child(player)

    # HUD precisa do player p/ cooldown
    if "hud" in main:
        main.hud.set_player(player)

    var cam2d: Camera2D = Camera2D.new()
    player.add_child(cam2d)
    cam2d.position_smoothing_enabled = true
    cam2d.position_smoothing_speed = 8.0
    cam2d.make_current()

func _spawn_enemies(n: int) -> void:
    const EnemyScene := preload("res://scripts/enemy.gd")
    var stand_y: float = GROUND_Y - (GROUND_H * 0.5) - 20.0
    var xs: Array[float] = [-200.0, -100.0, 0.0, 100.0, 200.0]
    for i in range(min(n, xs.size())):
        var e: Enemy = EnemyScene.new()
        e.position = Vector2(xs[i], stand_y)
        e.player = player
        e.main = main
        add_child(e)
