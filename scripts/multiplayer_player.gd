extends CharacterBody2D
class_name MultiplayerPlayer

# Sinais para comunicação com o MultiplayerManager
signal player_update(position: Vector2, velocity: Vector2, animation: String, facing: int, hp: int)
signal player_update_with_sequence(position: Vector2, velocity: Vector2, animation: String, facing: int, hp: int, sequence: int)
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

# Client-side prediction
var predicted_position: Vector2
var predicted_velocity: Vector2
var input_sequence: int = 0
var input_buffer: Array = []  # Armazena inputs enviados para reconciliação
var server_position: Vector2
var server_velocity: Vector2
var server_timestamp: float = 0.0
var reconciliation_threshold: float = 15.0  # pixels de diferença para correção (aumentado)

# Interpolação para jogadores remotos
var interpolation_buffer: Array = []  # Buffer de estados recebidos
var interpolation_delay: float = 0.1  # 100ms de atraso para suavizar
var max_buffer_size: int = 10

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

func setup_multiplayer_player(id: String, player_display_name: String, local: bool) -> void:
    """Configura o jogador multiplayer"""
    player_id = id
    self.player_name = player_display_name
    is_local_player = local
    
    # GARANTIR que os componentes estão criados antes de configurar
    _log("🔧 SETUP MULTIPLAYER INICIADO para " + player_name + " - Sprite existe? " + str(sprite != null))
    if not sprite:
        _log("🚨 CRIANDO componentes pois _ready() ainda não foi chamado para " + player_name)
        _setup_physics()
        _setup_sprite()
        _setup_nametag()
        _log("🔧 COMPONENTES CRIADOS para " + player_name + " - Sprite agora existe? " + str(sprite != null))
    else:
        _log("✅ Componentes já existem, não recriando sprite para " + player_name)
    
    # Configurar camadas de colisão para evitar colisão entre jogadores
    if is_local_player:
        # Jogador local: camada 1, colide com ambiente (camada 2)
        set_collision_layer_value(1, true)
        set_collision_layer_value(3, false)  # Remove da camada de jogadores
        set_collision_mask_value(2, true)    # Colide com ambiente
        set_collision_mask_value(3, false)   # Não colide com outros jogadores
        print("🎮 PLAYER LOCAL CAMADAS - layer: 1, mask: 2")
    else:
        # Jogadores remotos: camada 3, colide com ambiente (camada 2)
        set_collision_layer_value(1, false)  # Remove da camada padrão
        set_collision_layer_value(3, true)   # Adiciona à camada de jogadores remotos
        set_collision_mask_value(2, true)    # Colide com ambiente
        set_collision_mask_value(3, false)   # Não colide com outros jogadores
        print("🎮 PLAYER REMOTO CAMADAS - layer: 3, mask: 2")
    
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
    set_collision_mask_value(2, true)  # Ambiente/Ground

func _setup_sprite() -> void:
    _log("🎨 INICIANDO _setup_sprite para " + player_name)
    
    # EVITAR DUPLICAÇÃO: Se o sprite já existe, remove o anterior
    if sprite != null:
        _log("⚠️ REMOVENDO sprite anterior para " + player_name)
        sprite.queue_free()
        sprite = null
    
    # LIMPAR qualquer AnimatedSprite2D existente IMEDIATAMENTE
    var children_to_remove = []
    for child in get_children():
        if child is AnimatedSprite2D:
            children_to_remove.append(child)
    
    for child in children_to_remove:
        _log("🗑️ REMOVENDO AnimatedSprite2D duplicado para " + player_name)
        remove_child(child)
        child.queue_free()
    
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
    
    # Tentar usar sprites existentes se disponíveis, senão criar debug
    if not _try_load_player_sprites():
        _create_debug_texture()

func _try_load_player_sprites() -> bool:
    """Tenta carregar sprites do player diretamente"""
    # Carregar sprites diretamente das pastas
    var loaded = false
    
    # Idle sprites
    var idle_sprites = []
    for i in range(10):  # 0-9 frames
        var path = "res://art/player/idle_east/frame_%03d.png" % i
        if ResourceLoader.exists(path):
            var texture = load(path)
            if texture:
                idle_sprites.append(texture)
    
    # Walk sprites  
    var walk_sprites = []
    for i in range(8):  # 0-7 frames
        var path = "res://art/player/walk_east/frame_%03d.png" % i
        if ResourceLoader.exists(path):
            var texture = load(path)
            if texture:
                walk_sprites.append(texture)
    
    # Jump sprites
    var jump_sprites = []
    for i in range(9):  # 0-8 frames
        var path = "res://art/player/jump_east/frame_%03d.png" % i
        if ResourceLoader.exists(path):
            var texture = load(path)
            if texture:
                jump_sprites.append(texture)
                
    # Attack sprites
    var attack_sprites = []
    for i in range(5):  # 0-4 frames
        var path = "res://art/player/attack_east/frame_%03d.png" % i
        if ResourceLoader.exists(path):
            var texture = load(path)
            if texture:
                attack_sprites.append(texture)
    
    # Adicionar sprites às animações se encontrou
    if not idle_sprites.is_empty():
        _add_frames_to_animation("idle", idle_sprites)
        loaded = true
    
    if not walk_sprites.is_empty():
        _add_frames_to_animation("walk", walk_sprites)
        loaded = true
        
    if not jump_sprites.is_empty():
        _add_frames_to_animation("jump", jump_sprites)
        loaded = true
        
    if not attack_sprites.is_empty():
        _add_frames_to_animation("attack", attack_sprites)
        loaded = true
    
    if loaded:
        _log("✅ Player sprites carregados com sucesso para " + player_name)
    
    return loaded

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
    
    if is_local_player:
        # Client-side prediction para jogador local
        _process_local_input_with_prediction(delta)
        _send_sync_update_with_sequence()
    else:
        # Interpolação para jogadores remotos
        _apply_interpolation(delta)
    
    move_and_slide()
    
    # Atualizar animação
    if not is_attacking:
        _update_animation()
    
    _apply_flip_for_current_anim()

func _process_local_input_with_prediction(delta: float) -> void:
    """Processa input com client-side prediction"""
    # Capturar input
    var input_dir: float = 0.0
    if Input.is_action_pressed("ui_left"):
        input_dir -= 1.0
    if Input.is_action_pressed("ui_right"):
        input_dir += 1.0
    
    var jump_pressed = Input.is_action_just_pressed("ui_up") and is_on_floor() and not is_attacking
    var attack_pressed = Input.is_action_just_pressed("attack")
    
    # Criar input data para enviar ao servidor
    var input_data = {
        "sequence": input_sequence,
        "input_dir": input_dir,
        "jump": jump_pressed,
        "attack": attack_pressed,
        "timestamp": Time.get_ticks_msec() / 1000.0
    }
    
    # Armazenar input para reconciliação posterior
    input_buffer.append(input_data)
    if input_buffer.size() > 60:  # Manter apenas últimos 60 inputs (1s a 60fps)
        input_buffer.pop_front()
    
    # Aplicar movimento imediatamente (prediction)
    _apply_input(input_data, delta)
    
    input_sequence += 1

func _send_sync_update_with_sequence() -> void:
    """Envia atualização com sequence number para reconciliação"""
    if not is_local_player:
        return
    
    var current_time = Time.get_ticks_msec() / 1000.0
    if current_time - last_sync_time >= sync_interval:
        # Log apenas a cada 3 segundos para não poluir
        if current_time - last_log_time >= log_interval:
            # Sync data sent
            last_log_time = current_time
        
        # Emitir com sequence atual para reconciliação
        player_update_with_sequence.emit(global_position, velocity, current_animation, facing_sign, current_hp, input_sequence)
        last_sync_time = current_time

func apply_sync_data(data: Dictionary) -> void:
    """Aplica dados de sincronização com interpolação ou reconciliação"""
    print("🚨 APPLY_SYNC_DATA EXECUTADA!")  # Most basic log possible
    _log("📥 APPLY_SYNC_DATA called - is_local_player: " + str(is_local_player) + " data keys: " + str(data.keys()))
    var current_time = Time.get_ticks_msec() / 1000.0
    
    if is_local_player:
        # Calling reconciliation
        # Reconciliação para jogador local
        _apply_server_reconciliation(data, current_time)
    else:
        # Interpolação para jogadores remotos  
        _add_to_interpolation_buffer(data, current_time)
    
    # Atualizar dados não relacionados à posição
    if "animation" in data:
        _play_animation(data.animation)
    if "facing" in data:
        facing_sign = data.facing
    if "hp" in data:
        current_hp = data.hp

func _try_attack() -> void:
    """Tenta executar ataque"""
    _log("⚔️ _try_attack chamado - _can_attack: " + str(_can_attack) + " is_attacking: " + str(is_attacking))
    if not _can_attack or is_attacking:
        _log("❌ Ataque bloqueado - cooldown ou já atacando")
        return
    
    is_attacking = true
    _can_attack = false
    
    _play_animation("attack")
    
    # Tocar som de ataque
    _play_attack_sound()
    
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
    # EnemyClient removido - usando tipo genérico
    if body.has_method("take_damage"):
        # Calcular dano baseado nos atributos do player
        var damage = _get_attack_damage()
        
        # Enviar ataque para servidor em vez de aplicar dano diretamente
        var main_node = get_tree().get_first_node_in_group("main")
        if main_node and main_node.current_map_node and main_node.current_map_node.has_method("handle_player_attack"):
            main_node.current_map_node.handle_player_attack(body.global_position, damage)
            _log("⚔️ Ataque enviado ao servidor: " + str(damage))
    elif body is EnemyMultiplayer:
        # Compatibilidade com sistema antigo (caso ainda tenha alguns)
        var damage = _get_attack_damage()
        body.take_damage(damage)
        _log("💥 Dano aplicado (sistema antigo): " + str(damage))
    
    if is_instance_valid(hitbox):
        hitbox.queue_free()

func take_damage(amount: int) -> void:
    """Recebe dano com cálculo de defesa"""
    var reduced_damage = _calculate_damage_after_defense(amount)
    current_hp = max(0, current_hp - reduced_damage)
    _log("❤️ HP: " + str(current_hp) + "/" + str(max_hp) + " (Dano recebido: " + str(reduced_damage) + ")")
    
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

func _play_attack_sound() -> void:
    """Toca o som de ataque através do main"""
    var tree = get_tree()
    if tree == null:
        return
    var main_node = tree.get_first_node_in_group("main")
    if main_node and main_node.has_method("play_sfx_id"):
        main_node.play_sfx_id("attack")

func _get_attack_damage() -> int:
    """Calcula dano de ataque baseado nos atributos"""
    var tree = get_tree()
    if tree == null:
        return 10  # Dano base fallback
    var main_node = tree.get_first_node_in_group("main")
    if main_node and main_node.has_method("get_player_damage"):
        var damage = main_node.get_player_damage()
        _log("🗡️ Dano calculado: " + str(damage))
        return damage
    else:
        _log("⚠️ get_player_damage() não encontrado, usando fallback")
        return 10  # Dano base fallback

func _calculate_damage_after_defense(raw_damage: int) -> int:
    """Calcula dano final após aplicar defesa"""
    var tree = get_tree()
    if tree == null:
        return raw_damage  # Sem defesa aplicada
    var main_node = tree.get_first_node_in_group("main")
    if main_node and main_node.has_method("get_damage_reduction"):
        var defense = main_node.get_damage_reduction()
        # Defesa reduz o dano, mas sempre causa pelo menos 1 de dano
        var reduced_damage = max(1, raw_damage - defense)
        return reduced_damage
    else:
        return raw_damage  # Sem defesa aplicada

func update_max_hp() -> void:
    """Atualiza HP máximo baseado na vitalidade"""
    var tree = get_tree()
    if tree == null:
        _log("⚠️ get_tree() null em update_max_hp(), adiando atualização")
        call_deferred("update_max_hp")
        return
        
    var main_node = tree.get_first_node_in_group("main")
    if main_node and "player_hp_max" in main_node:
        max_hp = main_node.player_hp_max
        # Se HP atual é maior que novo máximo, ajustar
        if current_hp > max_hp:
            current_hp = max_hp

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

# === CLIENT-SIDE PREDICTION & INTERPOLATION ===

func _apply_input(input_data: Dictionary, _delta: float) -> void:
    """Aplica input específico (usado tanto para prediction quanto reconciliação)"""
    var input_dir = input_data.get("input_dir", 0.0)
    var jump = input_data.get("jump", false)
    var attack = input_data.get("attack", false)
    
    # Movimento horizontal
    velocity.x = input_dir * speed
    
    # Atualizar direção
    if input_dir != 0.0:
        facing_sign = int(sign(input_dir))
    
    # Pulo
    if jump:
        velocity.y = -jump_force
        _play_animation("jump")
        _log("🦘 " + player_name + " prediction pulo!")
    
    # Ataque
    if attack:
        _try_attack()

func _apply_server_reconciliation(server_data: Dictionary, current_time: float) -> void:
    """Reconcilia posição do servidor com predições locais"""
    _log("🚨 RECONCILIATION FUNCTION CALLED - server_data keys: " + str(server_data.keys()))
    
    if not "position" in server_data:
        _log("❌ No position in server_data, returning early")
        return
    
    var server_pos = Vector2(server_data.position.x, server_data.position.y)
    var server_seq = server_data.get("sequence", -1)
    
    # Calcular diferença apenas horizontal (ignorar gravidade)
    var horizontal_error = abs(global_position.x - server_pos.x)
    
    # DEBUG: SEMPRE mostrar logs a cada 3 segundos para debug
    var should_log = (current_time - last_log_time >= log_interval)
    if should_log:
        _log("🔍 RECONCILIATION DEBUG: local_pos=" + str(global_position) + " server_pos=" + str(server_pos) + " h_error=" + str(horizontal_error) + " threshold=" + str(reconciliation_threshold) + " velocity.x=" + str(velocity.x))
        last_log_time = current_time
    
    # Mostrar bloqueios sempre que ocorrerem
    if horizontal_error <= reconciliation_threshold:
        if should_log:
            _log("✅ Reconciliação BLOQUEADA: erro " + str(horizontal_error) + "px <= threshold " + str(reconciliation_threshold) + "px")
    elif velocity.x == 0.0:
        if should_log:
            _log("✅ Reconciliação BLOQUEADA: velocity.x = 0.0 (player parado)")
    
    # Só reconciliar se erro horizontal for significativo E se não estiver parado
    if horizontal_error > reconciliation_threshold and velocity.x != 0.0:
        # Horizontal reconciliation applied
        
        # Correção: definir apenas posição X do servidor
        global_position.x = server_pos.x
        # Manter Y local para preservar física de gravidade
        
        # Re-aplicar apenas inputs horizontais posteriores
        if server_seq >= 0:
            for input_data in input_buffer:
                if input_data.sequence > server_seq:
                    # Aplicar apenas movimento horizontal
                    var input_dir = input_data.get("input_dir", 0.0)
                    if input_dir != 0.0:
                        velocity.x = input_dir * speed
                        global_position.x += velocity.x * get_physics_process_delta_time()
    
    # Atualizar dados do servidor para referência
    server_position = server_pos
    if "velocity" in server_data:
        server_velocity = Vector2(server_data.velocity.x, server_data.velocity.y)
    server_timestamp = current_time

func _add_to_interpolation_buffer(data: Dictionary, timestamp: float) -> void:
    """Adiciona estado ao buffer de interpolação"""
    if not "position" in data:
        return
        
    var state = {
        "position": Vector2(data.position.x, data.position.y),
        "velocity": Vector2(data.velocity.x, data.velocity.y) if "velocity" in data else Vector2.ZERO,
        "timestamp": timestamp
    }
    
    interpolation_buffer.append(state)
    
    # Manter buffer limitado
    if interpolation_buffer.size() > max_buffer_size:
        interpolation_buffer.pop_front()
    
    # Ordenar por timestamp
    interpolation_buffer.sort_custom(func(a, b): return a.timestamp < b.timestamp)

func _apply_interpolation(delta: float) -> void:
    """Aplica interpolação suave entre estados recebidos"""
    if interpolation_buffer.size() < 2:
        return
    
    var current_time = Time.get_ticks_msec() / 1000.0
    var render_time = current_time - interpolation_delay
    
    # Encontrar dois estados para interpolar
    var from_state = null
    var to_state = null
    
    for i in range(interpolation_buffer.size() - 1):
        var current_state = interpolation_buffer[i]
        var next_state = interpolation_buffer[i + 1]
        
        if render_time >= current_state.timestamp and render_time <= next_state.timestamp:
            from_state = current_state
            to_state = next_state
            break
    
    if from_state != null and to_state != null:
        # Calcular fator de interpolação
        var time_diff = to_state.timestamp - from_state.timestamp
        var lerp_factor = 0.0
        if time_diff > 0:
            lerp_factor = (render_time - from_state.timestamp) / time_diff
            lerp_factor = clamp(lerp_factor, 0.0, 1.0)
        
        # Interpolar posição suavemente
        var target_pos = from_state.position.lerp(to_state.position, lerp_factor)
        global_position = global_position.lerp(target_pos, delta * 10.0)  # Suavização
        
        # Interpolar velocidade
        velocity = from_state.velocity.lerp(to_state.velocity, lerp_factor)
    
    # Limpar estados antigos
    _cleanup_interpolation_buffer(render_time)

func _cleanup_interpolation_buffer(render_time: float) -> void:
    """Remove estados antigos do buffer de interpolação"""
    while interpolation_buffer.size() > 0 and interpolation_buffer[0].timestamp < render_time - 0.5:
        interpolation_buffer.pop_front()
