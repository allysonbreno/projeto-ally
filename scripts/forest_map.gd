extends Node2D

var main: Node
var player: Player

# Chão invisível (colisão) + largura responsiva
var ground_body: StaticBody2D
var ground_shape: RectangleShape2D
var ground_col: CollisionShape2D
var ground_width: float = 0.0

# Background
var bg_sprite: Sprite2D
const FOREST_BG_PATH: String = "res://art/bg/forest_bg.png"

# ===== ajuste fino do piso =====
const GROUND_H: float = 24.0
const BOTTOM_MARGIN: float = 120.0
# =================================

func setup(main_ref: Node) -> void:
    main = main_ref
    _build_world()
    _spawn_player()
    _spawn_enemies(5)
    main.set_enemies_to_kill(5)

func _build_world() -> void:
    var vp: Vector2 = get_viewport().get_visible_rect().size
    ground_width = vp.x

    _build_background()

    ground_body = StaticBody2D.new()
    ground_shape = RectangleShape2D.new()
    ground_shape.size = Vector2(ground_width, GROUND_H)
    ground_col = CollisionShape2D.new()
    ground_col.shape = ground_shape
    ground_body.add_child(ground_col)
    add_child(ground_body)

    var ground_center_y: float = vp.y * 0.5 - BOTTOM_MARGIN + GROUND_H * 0.5
    ground_body.position = Vector2(0.0, ground_center_y)

    ground_body.set_collision_layer_value(3, true)
    ground_body.set_collision_mask_value(1, true)
    ground_body.set_collision_mask_value(2, true)

    var label: Label = Label.new()
    label.text = "Floresta"
    label.position = Vector2(10, 10)
    add_child(label)

    var cam2d: Camera2D = Camera2D.new()
    cam2d.position = Vector2.ZERO
    add_child(cam2d)
    cam2d.call_deferred("make_current")

    get_tree().root.size_changed.connect(_on_window_resized)

func _build_background() -> void:
    if ResourceLoader.exists(FOREST_BG_PATH):
        var tex: Texture2D = load(FOREST_BG_PATH)
        bg_sprite = Sprite2D.new()
        bg_sprite.texture = tex
        bg_sprite.centered = true
        bg_sprite.z_index = -100
        add_child(bg_sprite)
        _update_background(true)

func _process(_delta: float) -> void:
    _update_background(false)

func _update_background(force: bool) -> void:
    if bg_sprite == null:
        return
    var cam: Camera2D = get_viewport().get_camera_2d()
    var vp: Vector2 = get_viewport().get_visible_rect().size
    var target_pos: Vector2 = cam.global_position if cam != null else Vector2.ZERO
    if force or bg_sprite.position != target_pos:
        bg_sprite.position = target_pos

    var tex: Texture2D = bg_sprite.texture
    if tex != null:
        var tex_size: Vector2 = tex.get_size()
        if tex_size.x > 0.0 and tex_size.y > 0.0:
            var scale_factor: float = max(vp.x / tex_size.x, vp.y / tex_size.y)
            bg_sprite.scale = Vector2(scale_factor, scale_factor)

func _on_window_resized() -> void:
    var vp: Vector2 = get_viewport().get_visible_rect().size
    ground_width = vp.x
    ground_shape.size = Vector2(ground_width, GROUND_H)
    ground_body.position = Vector2(0.0, vp.y * 0.5 - BOTTOM_MARGIN + GROUND_H * 0.5)
    _update_background(true)

func _spawn_player() -> void:
    const PlayerScene := preload("res://scripts/player.gd")
    player = PlayerScene.new()

    var vp: Vector2 = get_viewport().get_visible_rect().size
    var stand_y: float = (vp.y * 0.5 - BOTTOM_MARGIN) - 20.0
    var left_x: float = -vp.x * 0.5 + 64.0
    player.position = Vector2(left_x, stand_y)
    player.velocity = Vector2.ZERO
    player.main = main
    add_child(player)

    if "hud" in main:
        main.hud.set_player(player)

func _spawn_enemies(n: int) -> void:
    const EnemyScene := preload("res://scripts/enemy.gd")
    var vp: Vector2 = get_viewport().get_visible_rect().size
    var stand_y: float = (vp.y * 0.5 - BOTTOM_MARGIN) - 20.0
    var xs: Array[float] = [-200.0, -100.0, 0.0, 100.0, 200.0]
    for i in range(min(n, xs.size())):
        var e: Enemy = EnemyScene.new()
        e.position = Vector2(xs[i], stand_y)
        e.player = player
        e.main = main
        add_child(e)
