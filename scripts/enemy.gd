extends CharacterBody2D
class_name Enemy

var speed: float = 112.0
var gravity: float = 900.0
var hp: int = 100
var attack_timer: float = 0.0
var attack_interval: float = 0.7
var contact_range: float = 26.0
var is_attacking: bool = false

var player: Player
var main: Node

var sprite: AnimatedSprite2D
var frames: SpriteFrames

const PATH_WALK: String = "res://art/enemy_forest/walk_east"
const PATH_ATK: String  = "res://art/enemy_forest/attack_east"
const SPRITE_SCALE: Vector2 = Vector2(1.8, 1.8)
const COLLIDER_SIZE: Vector2 = Vector2(24, 40)
const FPS_WALK: int = 8
const FPS_ATK: int = 7

func _ready() -> void:
    var shape: RectangleShape2D = RectangleShape2D.new()
    shape.size = COLLIDER_SIZE
    var col: CollisionShape2D = CollisionShape2D.new()
    col.shape = shape
    add_child(col)

    set_collision_layer_value(2, true)
    set_collision_mask_value(1, true)
    set_collision_mask_value(3, true)

    sprite = AnimatedSprite2D.new()
    add_child(sprite)
    frames = SpriteFrames.new()
    sprite.frames = frames
    sprite.centered = true
    sprite.scale = SPRITE_SCALE

    _add_animation_from_dir("walk", PATH_WALK, FPS_WALK, true)
    _add_animation_from_dir("attack", PATH_ATK, FPS_ATK, false)

    if frames.has_animation("walk") and frames.get_frame_count("walk") > 0 and not frames.has_animation("idle"):
        frames.add_animation("idle")
        frames.set_animation_speed("idle", 1)
        frames.set_animation_loop("idle", true)
        frames.add_frame("idle", frames.get_frame_texture("walk", 0))

    sprite.play("idle")

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y += gravity * delta

    if is_attacking:
        velocity.x = 0.0
        move_and_slide()
        return

    if player and player.is_inside_tree():
        var to_player: Vector2 = player.global_position - global_position
        var horiz: float = float(sign(to_player.x))
        velocity.x = horiz * speed

        if absf(velocity.x) > 1.0:
            sprite.flip_h = (velocity.x < 0)

        if absf(velocity.x) > 1.0:
            _play_if_not("walk")
        else:
            _play_if_not("idle")

        attack_timer -= delta
        if attack_timer <= 0.0 and to_player.length() <= contact_range + 6.0:
            _do_attack()
    else:
        velocity.x = 0.0
        _play_if_not("idle")

    move_and_slide()

func _do_attack() -> void:
    if is_attacking:
        return
    is_attacking = true

    _play_once_if_has("attack")
    var anim_len: float = _anim_length("attack")
    if anim_len <= 0.0:
        anim_len = 0.5

    var hit_time: float = clamp(anim_len * 0.4, 0.05, anim_len - 0.05)
    await get_tree().create_timer(hit_time).timeout
    if player:
        player.take_damage(12)

    await get_tree().create_timer(max(0.0, anim_len - hit_time)).timeout
    is_attacking = false
    attack_timer = max(attack_interval, anim_len * 0.9)

func take_damage(amount: int) -> void:
    hp -= amount
    if main and main.has_method("show_damage_popup_at_world"):
        main.show_damage_popup_at_world(global_position, "-" + str(amount), Color(1, 0.5, 0.1, 1))
    if hp <= 0:
        _drop_item()
        queue_free()
        if main and main.has_method("on_enemy_killed"):
            main.on_enemy_killed()

func _drop_item() -> void:
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

# helpers
func _add_animation_from_dir(anim_name: String, dir_path: String, fps: int, loop: bool) -> void:
    var files: Array[String] = _list_pngs_sorted(dir_path)
    if files.is_empty():
        return
    frames.add_animation(anim_name)
    frames.set_animation_loop(anim_name, loop)
    frames.set_animation_speed(anim_name, fps)
    for f in files:
        var tex: Resource = load(f)
        if tex is Texture2D:
            frames.add_frame(anim_name, tex)

func _list_pngs_sorted(dir_path: String) -> Array[String]:
    var out: Array[String] = []
    var d: DirAccess = DirAccess.open(dir_path)
    if d == null:
        return out
    d.list_dir_begin()
    var entry: String = d.get_next()
    while entry != "":
        if not d.current_is_dir() and entry.to_lower().ends_with(".png"):
            out.append(dir_path + "/" + entry)
        entry = d.get_next()
    d.list_dir_end()
    out.sort()
    return out

func _play_if_not(anim: String) -> void:
    if sprite.animation != anim and frames.has_animation(anim):
        sprite.play(anim)

func _play_once_if_has(anim: String) -> void:
    if frames.has_animation(anim):
        sprite.play(anim)

func _anim_length(anim: String) -> float:
    if not frames.has_animation(anim):
        return 0.0
    var fps: float = max(1.0, float(frames.get_animation_speed(anim)))
    var count: float = float(frames.get_frame_count(anim))
    return count / fps
