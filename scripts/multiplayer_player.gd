extends CharacterBody2D
class_name MultiplayerPlayer

# Sinais para comunicação com o MultiplayerManager
signal player_update(position: Vector2, velocity: Vector2, animation: String, facing: int, hp: int)
signal player_action(action: String, action_data: Dictionary)

# Informações do jogador
var player_id: String = ""
var player_name: String = ""
var is_local_player: bool = false

# --- Movimento ---
var speed: float = 220.0
var jump_force: float = 360.0
var gravity: float = 900.0

# Direção atual: -1 = esquerda, +1 = direita
var facing_sign: int = 1

# --- Ataque ---
var attack_cooldown: float = 0.3
var _can_attack: bool = true
var is_attacking: bool = false
var attack_cd_remaining: float = 0.0

# --- Auto Attack ---
var auto_attack_enabled: bool = false
var auto_attack_timer: float = 0.0

# --- Status ---
var max_hp: int = 100
var current_hp: int = 100

# --- Sprite/animação ---
var sprite: AnimatedSprite2D
var frames: SpriteFrames
var current_animation: String = "idle"

# Nametag
var name_label: Label

# Tamanho/escala
const SPRITE_SCALE: Vector2 = Vector2(0.2, 0.2)
const COLLIDER_SIZE: Vector2 = Vector2(28, 60)

# FPS
const FPS_IDLE: int = 4
const FPS_WALK: int = 8
const FPS_JUMP: int = 3
const FPS_ATTACK: int = 10

# Orientação base de cada animação
const IDLE_FACES_RIGHT: bool = false
const WALK_FACES_RIGHT: bool = false
const JUMP_FACES_RIGHT: bool = false
const ATTACK_FACES_RIGHT: bool = false

# Sincronização para jogadores remotos
var last_sync_time: float = 0.0
var sync_interval: float = 0.2  # 5 vezes por segundo (reduzido para evitar sobrecarga)

# Para logs menos frequentes
var last_log_time: float = 0.0
var log_interval: float = 3.0  # Log a cada 3 segundos

func _log(message: String):
    """Log que vai para o servidor via MultiplayerManager"""
    print(message)
    # Tentar encontrar o MultiplayerManager em diferentes locais
    var multiplayer_manager = null
    
    # Primeiro tentar no pai direto (MultiplayerGame)
    var parent_node = get_parent()
    while parent_node != null:
        var manager = parent_node.get_node_or_null("MultiplayerManager")
        if manager:
            multiplayer_manager = manager
            break
        parent_node = parent_node.get_parent()
    
    if multiplayer_manager:
        multiplayer_manager.send_log_to_server(message)

func _ready() -> void:
    _setup_physics()
    _setup_sprite()
    _setup_nametag()

func setup_multiplayer_player(id: String, player_name: String, local: bool) -> void:
    """Configura o jogador multiplayer"""
    player_id = id
    self.player_name = player_name
    is_local_player = local
    
    # GARANTIR que os componentes estão criados antes de configurar
    _log("🔧 SETUP MULTIPLAYER INICIADO para " + player_name + " - Sprite existe? " + str(sprite != null))
    if not sprite:
        _log("🚨 CRIANDO componentes pois _ready() ainda não foi chamado para " + player_name)
        _setup_physics()
        _setup_sprite()
        _setup_nametag()
        _log("🔧 COMPONENTES CRIADOS para " + player_name + " - Sprite agora existe? " + str(sprite != null))
    
    # Configurar camadas de colisão para evitar colisão entre jogadores
    if is_local_player:
        # Jogador local: camada 1, colide com ambiente (camada 2)
        set_collision_layer_value(1, true)
        set_collision_layer_value(3, false)  # Remove da camada de jogadores
        set_collision_mask_value(2, true)    # Colide com ambiente
        set_collision_mask_value(3, false)   # Não colide com outros jogadores
    else:
        # Jogadores remotos: camada 3, colide com ambiente (camada 2)
        set_collision_layer_value(1, false)  # Remove da camada padrão
        set_collision_layer_value(3, true)   # Adiciona à camada de jogadores remotos
        set_collision_mask_value(2, true)    # Colide com ambiente
        set_collision_mask_value(3, false)   # Não colide com outros jogadores
    
    # Atualizar nametag
    if name_label:
        name_label.text = player_name
        # Cor diferente para jogador local
        if is_local_player:
            name_label.modulate = Color.CYAN
        else:
            name_label.modulate = Color.WHITE
    
    # GARANTIR que o sprite esteja visível
    if sprite:
        sprite.visible = true
        sprite.modulate = Color.WHITE
        _log("✅ Sprite garantidamente visível para " + player_name + " - Visível: " + str(sprite.visible) + " Modulate: " + str(sprite.modulate))
    else:
        _log("❌ ERRO: Sprite ainda é null após setup para " + player_name)
    
    var layer_info = "Camadas: "
    for i in range(1, 5):
        if get_collision_layer_value(i):
            layer_info += str(i) + " "
    _log("🎮 Player configurado: " + player_name + " (Local: " + str(local) + ", " + layer_info + ")")
    _log("👁️ Player visível: " + player_name + " em posição: " + str(global_position))

func _setup_physics() -> void:
    # Colisão
    var shape: RectangleShape2D = RectangleShape2D.new()
    shape.size = COLLIDER_SIZE
    var col: CollisionShape2D = CollisionShape2D.new()
    col.shape = shape
    add_child(col)
    
    # Configurar camadas de colisão depois no setup
    set_collision_layer_value(1, true)
    set_collision_mask_value(2, true)

func _setup_sprite() -> void:
    _log("🎨 INICIANDO _setup_sprite para " + player_name)
    # Sprite
    sprite = AnimatedSprite2D.new()
    add_child(sprite)
    frames = SpriteFrames.new()
    sprite.frames = frames
    sprite.centered = true
    sprite.scale = SPRITE_SCALE
    
    # IMPORTANTE: Garantir que o sprite seja visível
    sprite.visible = true
    sprite.modulate = Color.WHITE
    sprite.z_index = 0
    _log("🎨 SPRITE CRIADO para " + player_name + " - Visível: " + str(sprite.visible) + " Escala: " + str(sprite.scale))
    
    # Criar animações básicas (simplificado para multiplayer)
    _create_simple_animations()
    
    sprite.play("idle")
    current_animation = "idle"
    _apply_flip_for_current_anim()
    
    _log("🎨 SPRITE FINALIZADO para " + player_name + " - Animação: " + current_animation + " Visível: " + str(sprite.visible))

func _setup_nametag() -> void:
    # Label com nome do jogador
    name_label = Label.new()
    name_label.text = player_name
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.position = Vector2(-20, -40)
    name_label.size = Vector2(40, 20)
    name_label.add_theme_color_override("font_color", Color.WHITE)
    name_label.add_theme_color_override("font_shadow_color", Color.BLACK)
    name_label.add_theme_constant_override("shadow_offset_x", 1)
    name_label.add_theme_constant_override("shadow_offset_y", 1)
    add_child(name_label)

func _create_simple_animations() -> void:
    """Criar animações básicas para multiplayer"""
    # Animação idle
    frames.add_animation("idle")
    frames.set_animation_loop("idle", true)
    frames.set_animation_speed("idle", FPS_IDLE)
    
    # Animação walk
    frames.add_animation("walk")
    frames.set_animation_loop("walk", true)
    frames.set_animation_speed("walk", FPS_WALK)
    
    # Animação jump
    frames.add_animation("jump")
    frames.set_animation_loop("jump", false)
    frames.set_animation_speed("jump", FPS_JUMP)
    
    # Animação attack
    frames.add_animation("attack")
    frames.set_animation_loop("attack", false)
    frames.set_animation_speed("attack", FPS_ATTACK)
    
    # Tentar usar sprites existentes se disponíveis
    _try_load_player_sprites()

func _try_load_player_sprites() -> void:
    """Tenta carregar sprites do PlayerSprites se disponível"""
    # Verificar se PlayerSprites existe antes de usar
    var player_sprites_class = load("res://player_sprites.gd")
    if player_sprites_class:
        var player_sprites = player_sprites_class.new()
        var idle_frames = player_sprites.get_frames("idle")
        var walk_frames = player_sprites.get_frames("walk")
        var jump_frames = player_sprites.get_frames("jump")
        var attack_frames = player_sprites.get_frames("attack")
        
        _add_frames_to_animation("idle", idle_frames)
        _add_frames_to_animation("walk", walk_frames)
        _add_frames_to_animation("jump", jump_frames)
        _add_frames_to_animation("attack", attack_frames)
        
        _log("🖼️ Sprites carregados para " + player_name + " - Idle frames: " + str(idle_frames.size()))
    else:
        _log("⚠️ PlayerSprites não encontrado, criando textura padrão")
        # Criar uma textura padrão para debug
        _create_debug_texture()

func _create_debug_texture() -> void:
    """Cria uma textura colorida para debug quando sprites não carregam"""
    # Criar uma textura simples colorida
    var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
    var color = Color.RED if is_local_player else Color.BLUE
    image.fill(color)
    
    var texture = ImageTexture.new()
    texture.set_image(image)
    
    # Adicionar a textura a todas as animações
    frames.add_frame("idle", texture)
    frames.add_frame("walk", texture)
    frames.add_frame("jump", texture)
    frames.add_frame("attack", texture)
    
    _log("🔴 Textura debug criada para " + player_name + " - Cor: " + str(color))

func _add_frames_to_animation(anim_name: String, textures: Array) -> void:
    """Adiciona frames a uma animação"""
    if textures.is_empty():
        return
    
    for texture in textures:
        if texture is Texture2D:
            frames.add_frame(anim_name, texture)

func _physics_process(delta: float) -> void:
    # Cooldown do ataque
    if attack_cd_remaining > 0.0:
        attack_cd_remaining = max(0.0, attack_cd_remaining - delta)
    
    # Gravidade
    if not is_on_floor():
        velocity.y += gravity * delta
    
    # Só processar input se for jogador local
    if is_local_player:
        _process_local_input(delta)
        _send_sync_update()
    
    move_and_slide()
    
    # Atualizar animação
    if not is_attacking:
        _update_animation()
    
    _apply_flip_for_current_anim()

func _process_local_input(delta: float) -> void:
    """Processa input apenas para jogador local"""
    # Movimento
    var input_dir: float = 0.0
    if Input.is_action_pressed("ui_left"):
        input_dir -= 1.0
    if Input.is_action_pressed("ui_right"):
        input_dir += 1.0
    
    velocity.x = input_dir * speed
    
    # Atualizar direção
    if input_dir != 0.0:
        facing_sign = int(sign(input_dir))
    
    # Pulo
    if Input.is_action_just_pressed("ui_up") and is_on_floor() and not is_attacking:
        velocity.y = -jump_force
        _play_animation("jump")
        
        # Enviar ação de pulo
        _log("🦘 " + player_name + " enviando pulo!")
        player_action.emit("jump", {"position": global_position})
    
    # Ataque manual (Space para ataque temporário)
    if Input.is_action_just_pressed("ui_accept"):
        _try_attack()
    
    # Auto attack
    if auto_attack_enabled:
        auto_attack_timer -= delta
        if auto_attack_timer <= 0.0:
            _try_attack()
            auto_attack_timer = attack_cooldown

func _send_sync_update() -> void:
    """Envia atualização para o servidor se for jogador local"""
    if not is_local_player:
        return
    
    var current_time = Time.get_ticks_msec() / 1000.0
    if current_time - last_sync_time >= sync_interval:
        # Log apenas a cada 3 segundos para não poluir
        if current_time - last_log_time >= log_interval:
            _log("🔄 " + player_name + " enviando sync: pos=" + str(global_position) + " vel=" + str(velocity) + " anim=" + current_animation)
            last_log_time = current_time
        
        player_update.emit(global_position, velocity, current_animation, facing_sign, current_hp)
        last_sync_time = current_time

func apply_sync_data(data: Dictionary) -> void:
    """Aplica dados de sincronização para jogadores remotos"""
    if is_local_player:
        return  # Jogador local não recebe sync
    
    # Log apenas a cada 3 segundos para não poluir
    var current_time = Time.get_ticks_msec() / 1000.0
    if current_time - last_log_time >= log_interval:
        _log("📥 " + player_name + " recebendo sync: pos=" + str(data.get("position", "N/A")) + " anim=" + str(data.get("animation", "N/A")))
        _log("📍 Posição atual de " + player_name + " após sync: " + str(global_position))
        last_log_time = current_time
    
    # Atualizar posição
    if "position" in data:
        var pos = data.position
        global_position = Vector2(pos.x, pos.y)
    
    # Atualizar velocidade
    if "velocity" in data:
        var vel = data.velocity
        velocity = Vector2(vel.x, vel.y)
    
    # Atualizar animação
    if "animation" in data:
        _play_animation(data.animation)
    
    # Atualizar direção
    if "facing" in data:
        facing_sign = data.facing
    
    # Atualizar HP
    if "hp" in data:
        current_hp = data.hp

func _try_attack() -> void:
    """Tenta executar ataque"""
    if not _can_attack or is_attacking:
        return
    
    is_attacking = true
    _can_attack = false
    
    _play_animation("attack")
    
    # Enviar ação de ataque
    if is_local_player:
        _log("⚔️ " + player_name + " enviando ataque!")
        player_action.emit("attack", {
            "position": global_position,
            "facing": facing_sign
        })
    
    var anim_len: float = _get_animation_length("attack")
    if anim_len <= 0.0:
        anim_len = 0.4
    
    var hit_time: float = clamp(anim_len * 0.35, 0.05, anim_len - 0.05)
    _spawn_attack_hitbox_after_delay(hit_time)
    
    await get_tree().create_timer(anim_len).timeout
    is_attacking = false
    
    attack_cd_remaining = attack_cooldown
    await get_tree().create_timer(attack_cooldown).timeout
    _can_attack = true

func _spawn_attack_hitbox_after_delay(delay: float) -> void:
    await get_tree().create_timer(delay).timeout
    _spawn_attack_hitbox()

func _spawn_attack_hitbox() -> void:
    """Cria hitbox de ataque"""
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
    
    if get_parent() != null:
        get_parent().add_child(area)
    else:
        add_child(area)
    
    # Remove hitbox após curto intervalo
    var tween = create_tween()
    tween.tween_interval(0.1)
    tween.tween_callback(area.queue_free)
    
    area.body_entered.connect(_on_attack_hitbox_body_entered.bind(area))

func _on_attack_hitbox_body_entered(body: Node, hitbox: Area2D) -> void:
    """Callback quando hitbox atinge algo"""
    if body is Enemy:
        var damage = 34
        body.take_damage(damage)
        _log("💥 Dano aplicado: " + str(damage))
    
    if is_instance_valid(hitbox):
        hitbox.queue_free()

func take_damage(amount: int) -> void:
    """Recebe dano"""
    current_hp = max(0, current_hp - amount)
    _log("❤️ HP: " + str(current_hp) + "/" + str(max_hp))
    
    # Enviar atualização se for jogador local
    if is_local_player:
        player_update.emit(global_position, velocity, current_animation, facing_sign, current_hp)

func _update_animation() -> void:
    """Atualiza animação baseada no estado"""
    var new_anim: String = "idle"
    
    if not is_on_floor():
        new_anim = "jump"
    elif absf(velocity.x) > 1.0:
        new_anim = "walk"
    else:
        new_anim = "idle"
    
    _play_animation(new_anim)

func _play_animation(anim: String) -> void:
    """Reproduz animação se diferente da atual"""
    if current_animation != anim and frames.has_animation(anim):
        sprite.play(anim)
        current_animation = anim

func _apply_flip_for_current_anim() -> void:
    """Aplica flip baseado na direção e orientação da animação"""
    var anim: String = current_animation
    var faces_right: bool = true
    
    match anim:
        "idle": faces_right = IDLE_FACES_RIGHT
        "walk": faces_right = WALK_FACES_RIGHT
        "jump": faces_right = JUMP_FACES_RIGHT
        "attack": faces_right = ATTACK_FACES_RIGHT
    
    if faces_right:
        sprite.flip_h = (facing_sign < 0)
    else:
        sprite.flip_h = (facing_sign > 0)

func _get_animation_length(anim: String) -> float:
    """Retorna duração da animação em segundos"""
    if not frames.has_animation(anim):
        return 0.0
    
    var fps: float = max(1.0, float(frames.get_animation_speed(anim)))
    var count: float = float(frames.get_frame_count(anim))
    return count / fps

func get_attack_cooldown_ratio() -> float:
    """Retorna progresso do cooldown de ataque (0.0 - 1.0)"""
    if attack_cooldown <= 0.0:
        return 1.0
    return 1.0 - clamp(attack_cd_remaining / attack_cooldown, 0.0, 1.0)

func set_auto_attack(enabled: bool) -> void:
    """Define auto ataque"""
    auto_attack_enabled = enabled
    auto_attack_timer = 0.0
