extends CharacterBody2D
class_name Enemy

# --- Movimento/combate ---
var speed: float = 112.0        # 160 * 0.7 (30% mais lento)
var gravity: float = 900.0
var hp: int = 100
var attack_timer: float = 0.0
var attack_interval: float = 0.7
var contact_range: float = 26.0
var is_attacking: bool = false  # trava movimento enquanto anima ataque

# --- Referências ---
var player: Player
var main: Node

# --- Sprite/animação ---
var sprite: AnimatedSprite2D
var frames: SpriteFrames

# Pastas (walk + attack)
const PATH_WALK  := "res://art/enemy_forest/walk_east"
const PATH_ATK   := "res://art/enemy_forest/attack_east"

# FPS
const FPS_WALK := 8
const FPS_ATK  := 7  # 10 * 0.7 (30% mais lento)

func _ready() -> void:
    # Collider simples 22x22 (visual pode ser maior)
    var shape: RectangleShape2D = RectangleShape2D.new()
    shape.size = Vector2(22, 22)
    var col: CollisionShape2D = CollisionShape2D.new()
    col.shape = shape
    add_child(col)

    # Layers: inimigo = layer 2; colide com 1 (player) e 3 (cenário)
    set_collision_layer_value(2, true)
    set_collision_mask_value(1, true)
    set_collision_mask_value(3, true)

    # AnimatedSprite2D criado por código
    sprite = AnimatedSprite2D.new()
    add_child(sprite)
    frames = SpriteFrames.new()
    sprite.frames = frames
    sprite.centered = true

    # Carregar animações a partir das pastas
    _add_animation_from_dir("walk", PATH_WALK, FPS_WALK, true)
    _add_animation_from_dir("attack", PATH_ATK, FPS_ATK, false)

    # "idle" automático usando o 1º frame do walk
    if frames.has_animation("walk") and frames.get_frame_count("walk") > 0:
        frames.add_animation("idle")
        frames.set_animation_speed("idle", 1)
        frames.set_animation_loop("idle", true)
        frames.add_frame("idle", frames.get_frame_texture("walk", 0))

    sprite.play("idle")

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y += gravity * delta

    # Se está atacando, não persegue (mantém anima visível)
    if is_attacking:
        velocity.x = 0.0
        move_and_slide()
        return

    if player and player.is_inside_tree():
        var to_player: Vector2 = player.global_position - global_position

        # Movimento horizontal
        var horiz: float = float(sign(to_player.x))
        velocity.x = horiz * speed

        # Virar sprite conforme direção
        if absf(velocity.x) > 1.0:
            sprite.flip_h = (velocity.x < 0)

        # Animação: walk quando anda, idle quando para
        if absf(velocity.x) > 1.0:
            _play_if_not("walk")
        else:
            _play_if_not("idle")

        # Ataque radial (vale esquerda/direita)
        attack_timer -= delta
        if attack_timer <= 0.0 and to_player.length() <= contact_range + 6.0:
            _do_attack()
            # o attack_timer é setado dentro de _do_attack
    else:
        velocity.x = 0.0
        _play_if_not("idle")

    move_and_slide()

func _do_attack() -> void:
    if is_attacking:
        return
    is_attacking = true

    _play_once_if_has("attack")
    var anim_len: float = _anim_length("attack")  # duração da animação
    if anim_len <= 0.0:
        anim_len = 0.5  # fallback

    # aplica dano no meio da animação (40%)
    var hit_time: float = clamp(anim_len * 0.4, 0.05, 0.6)
    await get_tree().create_timer(hit_time).timeout
    if player:
        player.take_damage(12)

    # espera o restante da animação
    await get_tree().create_timer(max(0.0, anim_len - hit_time)).timeout
    is_attacking = false

    # garante cooldown >= duração da animação
    attack_timer = max(attack_interval, anim_len * 0.9)

func take_damage(amount: int) -> void:
    hp -= amount
    if hp <= 0:
        queue_free()
        if main and main.has_method("on_enemy_killed"):
            main.on_enemy_killed()

# -----------------------
# Helpers de animação
# -----------------------

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
    out.sort() # "frame_000.png"... ordena certinho
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
