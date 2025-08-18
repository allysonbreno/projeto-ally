extends Node2D

var main: Node
var player: Player

# Chão invisível (colisão) + largura responsiva
var ground_body: StaticBody2D
var ground_shape: RectangleShape2D
var ground_col: CollisionShape2D
var ground_width: float = 0.0

# Paredes / teto (limites)
var left_wall: StaticBody2D
var right_wall: StaticBody2D
var ceil_body: StaticBody2D

# Background
var bg_sprite: Sprite2D
const CITY_BG_PATH: String = "res://art/bg/city_bg.png"

# ===== ajuste fino do piso/limites =====
const GROUND_H: float = 24.0
const BOTTOM_MARGIN: float = 150.0
const WALL_T: float = 32.0
# ======================================

func setup(main_ref: Node) -> void:
    main = main_ref
    _build_world()
    _spawn_player()

func _build_world() -> void:
    var vp: Vector2 = get_viewport().get_visible_rect().size
    ground_width = vp.x

    _build_background()

    # ----- Chão invisível (só colisão) -----
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

    # ----- Limites (paredes e teto) -----
    _build_bounds()

    # Título
    var label: Label = Label.new()
    label.text = "Cidade"
    label.position = Vector2(10, 10)
    add_child(label)

    # Câmera fixa
    var cam: Camera2D = Camera2D.new()
    cam.position = Vector2.ZERO
    add_child(cam)
    cam.call_deferred("make_current")

    get_tree().root.size_changed.connect(_on_window_resized)

func _build_background() -> void:
    if ResourceLoader.exists(CITY_BG_PATH):
        var tex: Texture2D = load(CITY_BG_PATH)
        bg_sprite = Sprite2D.new()
        bg_sprite.texture = tex
        bg_sprite.centered = true
        bg_sprite.z_index = -100
        add_child(bg_sprite)
        _update_background(true)

func _build_bounds() -> void:
    var vp: Vector2 = get_viewport().get_visible_rect().size

    # Parede esquerda
    left_wall = StaticBody2D.new()
    var lshape: RectangleShape2D = RectangleShape2D.new()
    lshape.size = Vector2(WALL_T, vp.y + 200.0)
    var lcol: CollisionShape2D = CollisionShape2D.new()
    lcol.shape = lshape
    left_wall.add_child(lcol)
    left_wall.position = Vector2(-vp.x * 0.5 + WALL_T * 0.5, 0.0)
    add_child(left_wall)

    # Parede direita
    right_wall = StaticBody2D.new()
    var rshape: RectangleShape2D = RectangleShape2D.new()
    rshape.size = Vector2(WALL_T, vp.y + 200.0)
    var rcol: CollisionShape2D = CollisionShape2D.new()
    rcol.shape = rshape
    right_wall.add_child(rcol)
    right_wall.position = Vector2(vp.x * 0.5 - WALL_T * 0.5, 0.0)
    add_child(right_wall)

    # Teto
    ceil_body = StaticBody2D.new()
    var cshape: RectangleShape2D = RectangleShape2D.new()
    cshape.size = Vector2(vp.x, WALL_T)
    var ccol: CollisionShape2D = CollisionShape2D.new()
    ccol.shape = cshape
    ceil_body.add_child(ccol)
    ceil_body.position = Vector2(0.0, -vp.y * 0.5 + WALL_T * 0.5)
    add_child(ceil_body)

    for b in [left_wall, right_wall, ceil_body]:
        b.set_collision_layer_value(3, true)
        b.set_collision_mask_value(1, true)
        b.set_collision_mask_value(2, true)

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
        var sz: Vector2i = tex.get_size()
        if sz.x > 0 and sz.y > 0:
            var k: float = max(vp.x / float(sz.x), vp.y / float(sz.y))
            bg_sprite.scale = Vector2(k, k)

func _on_window_resized() -> void:
    var vp: Vector2 = get_viewport().get_visible_rect().size
    ground_width = vp.x
    ground_shape.size = Vector2(ground_width, GROUND_H)
    ground_body.position = Vector2(0.0, vp.y * 0.5 - BOTTOM_MARGIN + GROUND_H * 0.5)

    # Atualiza limites
    (left_wall.get_child(0) as CollisionShape2D).shape.size = Vector2(WALL_T, vp.y + 200.0)
    left_wall.position = Vector2(-vp.x * 0.5 + WALL_T * 0.5, 0.0)

    (right_wall.get_child(0) as CollisionShape2D).shape.size = Vector2(WALL_T, vp.y + 200.0)
    right_wall.position = Vector2(vp.x * 0.5 - WALL_T * 0.5, 0.0)

    (ceil_body.get_child(0) as CollisionShape2D).shape.size = Vector2(vp.x, WALL_T)
    ceil_body.position = Vector2(0.0, -vp.y * 0.5 + WALL_T * 0.5)

    _update_background(true)

func _spawn_player() -> void:
    const PlayerScene := preload("res://scripts/player.gd")
    player = PlayerScene.new()
    var vp: Vector2 = get_viewport().get_visible_rect().size
    var stand_y: float = (vp.y * 0.5 - BOTTOM_MARGIN) - 20.0
    player.position = Vector2(0.0, stand_y)
    player.main = main
    add_child(player)
    if "hud" in main:
        main.hud.set_player(player)
