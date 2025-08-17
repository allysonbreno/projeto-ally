extends Node2D

var main: Node
var player: Player

func setup(main_ref: Node) -> void:
    main = main_ref
    _build_world()
    _spawn_player()
    _spawn_enemies(5)
    main.set_enemies_to_kill(5)

func _build_world() -> void:
    # Plataforma principal
    var ground: StaticBody2D = StaticBody2D.new()
    var col: CollisionShape2D = CollisionShape2D.new()
    var shape: RectangleShape2D = RectangleShape2D.new()
    shape.size = Vector2(1200, 24)
    col.shape = shape
    ground.position = Vector2(0, 220)
    ground.add_child(col)
    add_child(ground)
    ground.set_collision_layer_value(3, true)
    ground.set_collision_mask_value(1, true)
    ground.set_collision_mask_value(2, true)

    # Visual principal
    _add_rect_sprite(Vector2(1200, 24), ground.position, Color(0.20, 0.35, 0.20))

    # Plataformas extras
    for i in range(3):
        var plat: StaticBody2D = StaticBody2D.new()
        var c: CollisionShape2D = CollisionShape2D.new()
        var s: RectangleShape2D = RectangleShape2D.new()
        s.size = Vector2(200, 16)
        c.shape = s
        plat.position = Vector2(-300 + i * 300, 120 - i * 20)
        plat.add_child(c)
        add_child(plat)
        plat.set_collision_layer_value(3, true)
        plat.set_collision_mask_value(1, true)
        plat.set_collision_mask_value(2, true)

        _add_rect_sprite(Vector2(200, 16), plat.position, Color(0.25, 0.45, 0.25))

    # Rótulo
    var label: Label = Label.new()
    label.text = "Floresta"
    label.position = Vector2(10, 10)
    add_child(label)

func _spawn_player() -> void:
    const PlayerScene := preload("res://scripts/player.gd")
    player = PlayerScene.new()
    # ⬅️ Nascer na EXTREMA ESQUERDA do mapa (um pouco acima do chão)
    # plataforma principal vai de -600 a +600 (24px de altura). Posição segura:
    player.position = Vector2(-560, 150)
    player.velocity = Vector2.ZERO
    player.main = main
    add_child(player)

    # Camera (ordem para evitar aviso)
    var cam: Camera2D = Camera2D.new()
    player.add_child(cam)
    cam.position_smoothing_enabled = true
    cam.position_smoothing_speed = 8.0
    cam.make_current()

func _spawn_enemies(n: int) -> void:
    const EnemyScene := preload("res://scripts/enemy.gd")

    # 👹 Inimigos concentrados no CENTRO do mapa, sem sobrepor o player
    var xs := [-200, -100, 0, 100, 200]
    for i in range(min(n, xs.size())):
        var e: Enemy = EnemyScene.new()
        e.position = Vector2(xs[i], 150) # mesma altura do player, longe do spawn esquerda
        e.player = player
        e.main = main
        add_child(e)

# helper visual
func _add_rect_sprite(size: Vector2, pos: Vector2, color: Color) -> void:
    var img: Image = Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
    img.fill(color)
    var tex: ImageTexture = ImageTexture.create_from_image(img)
    var sprite: Sprite2D = Sprite2D.new()
    sprite.texture = tex
    sprite.centered = true
    sprite.position = pos
    add_child(sprite)
