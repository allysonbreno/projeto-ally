extends CharacterBody2D
class_name Player

var speed: float = 220.0
var jump_force: float = 360.0
var gravity: float = 900.0
var on_ground: bool = false
var facing: Vector2 = Vector2.RIGHT
var main: Node # referência ao Main

# Ataque
var attack_cooldown: float = 0.3
var _can_attack: bool = true

func _ready() -> void:
    # Visual: quadrado
    var rect: ColorRect = ColorRect.new()
    rect.color = Color.DODGER_BLUE
    rect.size = Vector2(24, 24)
    rect.position = Vector2(-12, -12)
    add_child(rect)

    # Collider
    var shape: RectangleShape2D = RectangleShape2D.new()
    shape.size = Vector2(24, 24)
    var col: CollisionShape2D = CollisionShape2D.new()
    col.shape = shape
    add_child(col)

    # Layers/máscaras do player
    set_collision_layer_value(1, true)  # player: layer 1
    set_collision_mask_value(2, true)   # colide com inimigos
    set_collision_mask_value(3, true)   # colide com cenário

func _physics_process(delta: float) -> void:
    # Gravidade
    if not is_on_floor():
        velocity.y += gravity * delta

    # Movimento
    var input_dir: float = 0.0
    if Input.is_action_pressed("move_left"):
        input_dir -= 1.0
    if Input.is_action_pressed("move_right"):
        input_dir += 1.0

    velocity.x = input_dir * speed

    if input_dir != 0.0:
        facing = Vector2(sign(input_dir), 0)

    # Pulo
    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = -jump_force

    move_and_slide()

    # Ataque
    if Input.is_action_just_pressed("attack"):
        _try_attack()

func _try_attack() -> void:
    if not _can_attack:
        return
    _can_attack = false
    await _spawn_attack_hitbox()
    await get_tree().create_timer(attack_cooldown).timeout
    _can_attack = true

func _spawn_attack_hitbox() -> Signal:
    # Área de ataque curta à frente do player
    var area: Area2D = Area2D.new()
    var col: CollisionShape2D = CollisionShape2D.new()
    var shape: RectangleShape2D = RectangleShape2D.new()
    shape.size = Vector2(22, 22)
    col.shape = shape

    var offset: Vector2 = Vector2(18, 0) * facing.x
    area.position = position + offset
    area.add_child(col)

    # Garantias para detecção:
    area.monitoring = true
    area.monitorable = true
    area.collision_layer = 0
    area.collision_mask = 0
    area.set_collision_mask_value(2, true) # detectar bodies na layer 2 (Enemy)

    area.body_entered.connect(func(body):
        if body is Enemy:
            body.take_damage(34) # ~3 hits para 100HP
    )
    get_parent().add_child(area)
    await get_tree().create_timer(0.07).timeout
    area.queue_free()
    return area.tree_exited

# Dano sofrido pelo player (chamado por inimigos)
func take_damage(amount: int) -> void:
    main.damage_player(amount)
