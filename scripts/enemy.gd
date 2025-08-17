extends CharacterBody2D
class_name Enemy

var speed: float = 160.0
var gravity: float = 900.0
var hp: int = 100
var player: Player
var main: Node
var attack_timer: float = 0.0
var attack_interval: float = 0.7
var contact_range: float = 26.0  # alcance levemente maior

func _ready() -> void:
    # Visual
    var rect: ColorRect = ColorRect.new()
    rect.color = Color.INDIAN_RED
    rect.size = Vector2(22, 22)
    rect.position = Vector2(-11, -11)
    add_child(rect)

    # Collider
    var shape: RectangleShape2D = RectangleShape2D.new()
    shape.size = Vector2(22, 22)
    var col: CollisionShape2D = CollisionShape2D.new()
    col.shape = shape
    add_child(col)

    # Layers: inimigo na 2; colide com 1 (player) e 3 (cenário)
    set_collision_layer_value(2, true)
    set_collision_mask_value(1, true)
    set_collision_mask_value(3, true)

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y += gravity * delta

    if player and player.is_inside_tree():
        var to_player: Vector2 = player.global_position - global_position
        var horiz: float = float(sign(to_player.x))
        velocity.x = horiz * speed

        attack_timer -= delta
        # Checamos por distância total (não só eixo X) para valer igualmente esquerda/direita/diagonal
        if attack_timer <= 0.0 and to_player.length() <= contact_range + 6.0:
            _attack_player()
            attack_timer = attack_interval
    else:
        velocity.x = 0.0

    move_and_slide()

func _attack_player() -> void:
    if player:
        player.take_damage(12)

func take_damage(amount: int) -> void:
    hp -= amount
    if hp <= 0:
        queue_free()
        if main and main.has_method("on_enemy_killed"):
            main.on_enemy_killed()
