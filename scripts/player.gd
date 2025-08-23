extends CharacterBody2D
class_name Player

# --- Movimento ---
var speed: float = 220.0
var jump_force: float = 360.0
var gravity: float = 900.0
var main: Node

# Direção atual: -1 = esquerda, +1 = direita
var facing_sign: int = 1

# --- Ataque ---
var attack_cooldown: float = 0.3
var _can_attack: bool = true
var is_attacking: bool = false
var attack_cd_remaining: float = 0.0

# --- Sprite/animação ---
var sprite: AnimatedSprite2D
var frames: SpriteFrames

# Pastas (nomes "_east" são só convenção)
const PATH_IDLE: String   = "res://art/player/idle_east"
const PATH_WALK: String   = "res://art/player/walk_east"
const PATH_JUMP: String   = "res://art/player/jump_east"
const PATH_ATTACK: String = "res://art/player/attack_east"

# Tamanho/escala
const SPRITE_SCALE: Vector2 = Vector2(0.9, 0.9)
const COLLIDER_SIZE: Vector2 = Vector2(28, 60)

# FPS
const FPS_IDLE: int   = 3
const FPS_WALK: int   = 10
const FPS_JUMP: int   = 12
const FPS_ATTACK: int = 10

# Orientação base de cada animação (true = frames originais olham para a DIREITA/Este; false = para a ESQUERDA/Oeste)
const IDLE_FACES_RIGHT: bool   = false	# ajuste aqui se trocar os frames de idle
const WALK_FACES_RIGHT: bool   = true
const JUMP_FACES_RIGHT: bool   = true
const ATTACK_FACES_RIGHT: bool = true

func _ready() -> void:
    # colisão
    var shape: RectangleShape2D = RectangleShape2D.new()
    shape.size = COLLIDER_SIZE
    var col: CollisionShape2D = CollisionShape2D.new()
    col.shape = shape
    add_child(col)

    set_collision_layer_value(1, true)
    set_collision_mask_value(2, true)
    set_collision_mask_value(3, true)

    # sprite
    sprite = AnimatedSprite2D.new()
    add_child(sprite)
    frames = SpriteFrames.new()
    sprite.frames = frames
    sprite.centered = true
    sprite.scale = SPRITE_SCALE

    # animações
    var idle_ok: bool = _add_animation_idle_if_exists()
    _add_animation_from_dir("walk", PATH_WALK, FPS_WALK, true)
    _add_animation_from_dir("jump", PATH_JUMP, FPS_JUMP, false)
    _add_animation_from_dir("attack", PATH_ATTACK, FPS_ATTACK, false)

    # fallback de idle caso não exista pasta idle_east
    if not idle_ok and frames.has_animation("walk") and not frames.has_animation("idle"):
        frames.add_animation("idle")
        frames.set_animation_speed("idle", 1)
        frames.set_animation_loop("idle", true)
        frames.add_frame("idle", frames.get_frame_texture("walk", 0))

    sprite.play("idle")
    _apply_flip_for_current_anim()

func _physics_process(delta: float) -> void:
    if attack_cd_remaining > 0.0:
        attack_cd_remaining = max(0.0, attack_cd_remaining - delta)

    if not is_on_floor():
        velocity.y += gravity * delta

    var input_dir: float = 0.0
    if not is_attacking:
        if Input.is_action_pressed("move_left") or Input.is_action_pressed("ui_left"):
            input_dir -= 1.0
        if Input.is_action_pressed("move_right") or Input.is_action_pressed("ui_right"):
            input_dir += 1.0
    velocity.x = input_dir * speed

    # atualiza direção quando há input
    if input_dir != 0.0:
        facing_sign = int(sign(input_dir))

    if (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_up")) and is_on_floor() and not is_attacking:
        velocity.y = -jump_force
        _play_if_not("jump")

    move_and_slide()

    if Input.is_action_just_pressed("attack"):
        _try_attack()

    # troca animação
    if not is_attacking:
        if not is_on_floor():
            _play_if_not("jump")
        elif absf(velocity.x) > 1.0:
            _play_if_not("walk")
        else:
            _play_if_not("idle")

    # aplica flip coerente com a orientação base da anima atual
    _apply_flip_for_current_anim()

func _apply_flip_for_current_anim() -> void:
    var anim: String = sprite.animation
    var faces_right: bool = true
    if anim == "idle":
        faces_right = IDLE_FACES_RIGHT
    elif anim == "walk":
        faces_right = WALK_FACES_RIGHT
    elif anim == "jump":
        faces_right = JUMP_FACES_RIGHT
    elif anim == "attack":
        faces_right = ATTACK_FACES_RIGHT
    # Se frames originais olham para a direita: flip quando olhando para esquerda.
    # Se frames originais olham para a esquerda: flip quando olhando para direita.
    if faces_right:
        sprite.flip_h = (facing_sign < 0)
    else:
        sprite.flip_h = (facing_sign > 0)

func _try_attack() -> void:
    if not _can_attack or is_attacking:
        return
    is_attacking = true
    _can_attack = false

    _play_once_if_has("attack")
    if main and main.has_method("play_sfx_id"):
        main.play_sfx_id("attack")

    var anim_len: float = _anim_length("attack")
    if anim_len <= 0.0:
        anim_len = 0.4

    var hit_time: float = clamp(anim_len * 0.35, 0.05, anim_len - 0.05)
    _spawn_attack_hitbox_after_delay(hit_time)

    await get_tree().create_timer(anim_len).timeout
    is_attacking = false

    attack_cd_remaining = attack_cooldown
    await get_tree().create_timer(attack_cooldown).timeout
    _can_attack = true

func get_attack_cooldown_ratio() -> float:
    if attack_cooldown <= 0.0:
        return 1.0
    var r: float = 1.0 - clamp(attack_cd_remaining / attack_cooldown, 0.0, 1.0)
    return r

func _spawn_attack_hitbox_after_delay(delay: float) -> void:
    await get_tree().create_timer(delay).timeout
    _spawn_attack_hitbox()

func _spawn_attack_hitbox() -> void:
    var area: Area2D = Area2D.new()
    var cshape: CollisionShape2D = CollisionShape2D.new()
    var shape: RectangleShape2D = RectangleShape2D.new()
    shape.size = Vector2(28, 24)
    cshape.shape = shape

    var dir_x: float = float(facing_sign)
    if dir_x == 0.0:
        dir_x = 1.0
    var offset: Vector2 = Vector2(22, 0) * dir_x
    area.position = position + offset
    area.add_child(cshape)

    area.monitoring = true
    area.monitorable = true
    area.collision_layer = 0
    area.collision_mask = 0
    area.set_collision_mask_value(2, true)

    # Adiciona o hitbox na cena para que a colisão funcione
    if get_parent() != null:
        get_parent().add_child(area)
    else:
        add_child(area)

    # Remove o hitbox automaticamente após curto intervalo
    var tween = create_tween()
    tween.tween_interval(0.1)
    tween.tween_callback(area.queue_free)

    area.body_entered.connect(_on_attack_hitbox_body_entered.bind(area))

func _on_attack_hitbox_body_entered(body: Node, hitbox: Area2D) -> void:
    if body is Enemy:
        var damage = 34  # Dano base padrão
        if main and main.has_method("get_player_damage"):
            damage = main.get_player_damage()
        
        body.take_damage(damage)
        # play SFX / show popup via `main`
        if main and main.has_method("play_sfx_id"):
            main.play_sfx_id("hit")
        if main and main.has_method("show_damage_popup_at_world"):
            main.show_damage_popup_at_world(body.global_position, "-" + str(damage), Color(1, 0.8, 0.2, 1))
    if is_instance_valid(hitbox):
        hitbox.queue_free()

func take_damage(amount: int) -> void:
    if main and main.has_method("damage_player"):
        main.damage_player(amount, global_position)

# ------ helpers de animação ------
func _add_animation_idle_if_exists() -> bool:
    if not DirAccess.dir_exists_absolute(PATH_IDLE):
        return false
    var files: Array[String] = _list_pngs_sorted(PATH_IDLE)
    if files.is_empty():
        return false
    frames.add_animation("idle")
    frames.set_animation_loop("idle", true)
    frames.set_animation_speed("idle", FPS_IDLE)
    if files.size() == 2:
        for i in [0, 1, 0, 1]:
            var tex: Resource = load(files[i])
            if tex is Texture2D:
                frames.add_frame("idle", tex)
    else:
        for f in files:
            var tex2: Resource = load(f)
            if tex2 is Texture2D:
                frames.add_frame("idle", tex2)
    return true

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

func _anim_length(anim: String) -> float:
    if not frames.has_animation(anim):
        return 0.0
    var fps: float = max(1.0, float(frames.get_animation_speed(anim)))
    var count: float = float(frames.get_frame_count(anim))
    return count / fps

func _play_if_not(anim: String) -> void:
    if sprite.animation != anim and frames.has_animation(anim):
        sprite.play(anim)

func _play_once_if_has(anim: String) -> void:
    if frames.has_animation(anim):
        sprite.play(anim)
