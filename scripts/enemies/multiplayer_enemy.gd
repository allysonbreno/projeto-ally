extends CharacterBody2D
class_name MultiplayerEnemy

var gravity: float = 900.0
var enemy_id: String = ""
var attack_timer: float = 0.0
var is_attacking: bool = false

# Sistema de ownership para sincronização
var owner_player_id: String = ""
var is_controlled_locally: bool = true
var last_position_sync: float = 0.0
var last_heartbeat_received: float = 0.0
const POSITION_SYNC_RATE: float = 0.1  # Sincronizar posição a cada 100ms
const HEARTBEAT_TIMEOUT: float = 3.0  # 3 segundos sem heartbeat = inimigo órfão
var has_received_initial_sync: bool = false  # Se já recebeu alguma sincronização

var target_player: Node2D  # Pode ser qualquer player multiplayer
var main: Node

var sprite: AnimatedSprite2D
var frames: SpriteFrames

# Sistema escalável de inimigos
var enemy_type: String = ""  # Será definido pelas classes filhas
var enemy_base_path: String = "res://art/enemies/"

const SPRITE_SCALE: Vector2 = Vector2(1.0, 1.0)
const COLLIDER_SIZE: Vector2 = Vector2(24, 40)

# PROPRIEDADES VIRTUAIS - Devem ser sobrescritas pelas classes filhas
var speed: float = 100.0
var hp: int = 100
var max_hp: int = 100
var attack_interval: float = 0.7
var contact_range: float = 26.0
var attack_damage: int = 10

# FPS configuráveis por animação
var fps_idle: int = 12
var fps_walk: int = 15
var fps_attack: int = 12

func _ready() -> void:
    # Gerar ID único apenas se não foi definido externamente
    if enemy_id == "":
        enemy_id = enemy_type + "_" + str(randi()) + "_" + str(Time.get_unix_time_from_system())
    
    # Inicializar timestamps
    last_position_sync = Time.get_unix_time_from_system()
    
    # Só inicializar heartbeat se for controlado remotamente
    if not is_controlled_locally:
        last_heartbeat_received = 0  # Aguardar primeira sincronização
    else:
        last_heartbeat_received = Time.get_unix_time_from_system()
        has_received_initial_sync = true
    
    # Log apenas se controlado localmente
    if is_controlled_locally:
        print("👺 Inimigo " + enemy_id + " criado - CONTROLADO LOCALMENTE")
    
    var shape: RectangleShape2D = RectangleShape2D.new()
    shape.size = COLLIDER_SIZE
    var col: CollisionShape2D = CollisionShape2D.new()
    col.shape = shape
    add_child(col)

    set_collision_layer_value(2, true)
    set_collision_mask_value(1, true)
    set_collision_mask_value(2, true)  # Colisão entre inimigos
    set_collision_mask_value(3, true)
    
    # Adicionar ao grupo de inimigos para detecção
    add_to_group("enemies")

    sprite = AnimatedSprite2D.new()
    add_child(sprite)
    frames = SpriteFrames.new()
    sprite.frames = frames
    sprite.centered = true
    sprite.scale = SPRITE_SCALE

    # Carregar sprites diretamente das pastas
    _load_enemy_sprites()
    
    # Configurar idle como primeira animação (fallback se não existe)
    if not frames.has_animation("idle") and frames.has_animation("walk") and frames.get_frame_count("walk") > 0:
        frames.add_animation("idle")
        frames.set_animation_speed("idle", fps_idle)
        frames.set_animation_loop("idle", true)
        frames.add_frame("idle", frames.get_frame_texture("walk", 0))

    sprite.play("idle")

func _physics_process(delta: float) -> void:
    # Se for display-only (server authoritative), não processar física
    if not is_controlled_locally:
        return
    
    if not is_on_floor():
        velocity.y += gravity * delta

    if is_attacking:
        velocity.x = 0.0
        move_and_slide()
        return

    # Se este inimigo é controlado por este player, processar movimento
    if is_controlled_locally:
        _process_local_movement(delta)
        _sync_position_if_needed()
    else:
        # Apenas verificar órfãos se já teve ownership inicial definido
        if has_received_initial_sync:
            _check_orphan_status()
        # Não assumir controle automaticamente - apenas quando reassignado
    
    move_and_slide()

func _process_local_movement(delta: float) -> void:
    """Processa movimento apenas para inimigos controlados localmente"""
    # Verificar se realmente devemos processar movimento
    if not is_controlled_locally:
        return
    
    # Encontrar o jogador mais próximo (local ou remoto)
    _find_closest_player()
    
    if target_player and target_player.is_inside_tree():
        var to_player: Vector2 = target_player.global_position - global_position
        var horiz: float = float(sign(to_player.x))
        velocity.x = horiz * speed
        
        if absf(velocity.x) > 1.0:
            sprite.flip_h = (velocity.x < 0)
            _play_if_not("walk")
        else:
            _play_if_not("idle")

        attack_timer -= delta
        if attack_timer <= 0.0 and to_player.length() <= contact_range + 6.0:
            _do_attack()
    else:
        velocity.x = 0.0
        _play_if_not("idle")

func _find_closest_player() -> void:
    """Encontra o jogador mais próximo (local ou remoto)"""
    if not main:
        return
    
    var closest_distance = INF
    target_player = null
    
    # Verifica jogador local
    if "local_player" in main and main.local_player and main.local_player.is_inside_tree():
        var distance = global_position.distance_to(main.local_player.global_position)
        if distance < closest_distance:
            closest_distance = distance
            target_player = main.local_player
    
    # Verifica jogadores remotos
    if "remote_players" in main:
        for player_id in main.remote_players.keys():
            var remote_player = main.remote_players[player_id]
            if remote_player and remote_player.is_inside_tree():
                var distance = global_position.distance_to(remote_player.global_position)
                if distance < closest_distance:
                    closest_distance = distance
                    target_player = remote_player

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
    
    # Causar dano ao jogador mais próximo
    if target_player:
        # Se for o jogador local, causa dano através do main
        if "local_player" in main and target_player == main.local_player:
            if main.has_method("damage_player"):
                main.damage_player(attack_damage, target_player.global_position)
        # Para jogadores remotos, por enquanto só mostra dano visual
        # TODO: Implementar sistema de dano sincronizado para multiplayer

    await get_tree().create_timer(max(0.0, anim_len - hit_time)).timeout
    is_attacking = false
    attack_timer = max(attack_interval, anim_len * 0.9)

func take_damage(amount: int) -> void:
    hp -= amount
    if main and main.has_method("show_damage_popup_at_world"):
        main.show_damage_popup_at_world(global_position, "-" + str(amount), Color(1, 0.5, 0.1, 1))
    
    # Enviar notificação de dano para outros players
    _notify_damage(amount, hp)
    
    if hp <= 0:
        # Enviar notificação de morte antes de morrer
        _notify_death()
        _drop_item()
        queue_free()
        if main and main.has_method("on_enemy_killed"):
            main.on_enemy_killed()

func _sync_position_if_needed() -> void:
    """Sincroniza posição se necessário (apenas para inimigos controlados localmente)"""
    var current_time = Time.get_unix_time_from_system()
    
    if current_time - last_position_sync >= POSITION_SYNC_RATE:
        last_position_sync = current_time
        _send_position_sync()

func _send_position_sync() -> void:
    """Envia sincronização de posição para outros players"""
    var multiplayer_manager = _get_multiplayer_manager()
    if multiplayer_manager and multiplayer_manager.has_method("send_enemy_position_sync"):
        multiplayer_manager.send_enemy_position_sync(enemy_id, global_position, velocity, sprite.flip_h, sprite.animation)

func apply_remote_sync(sync_position: Vector2, new_velocity: Vector2, flip_h: bool, animation: String) -> void:
    """Aplica sincronização recebida de outro player (apenas para inimigos remotos)"""
    if is_controlled_locally:
        return  # Ignorar se for controlado localmente
    
    # Atualizar timestamp do último heartbeat
    last_heartbeat_received = Time.get_unix_time_from_system()
    has_received_initial_sync = true
    
    # Aplicar posição e dados remotos usando movimento com colisão
    # Calcular direção para a posição sincronizada
    var target_direction = (sync_position - global_position)
    if target_direction.length() > 2.0:  # Se está muito longe, teletransportar
        global_position = sync_position
    else:
        # Se está próximo, mover com colisão
        velocity = target_direction.normalized() * min(target_direction.length() * 10, speed)
        move_and_slide()
    
    # Aplicar velocidade sincronizada apenas se não colidiu
    if get_slide_collision_count() == 0:
        velocity = new_velocity
    sprite.flip_h = flip_h
    _play_if_not(animation)

func _check_orphan_status() -> void:
    """Verifica se este inimigo está órfão (sem dono ativo)"""
    if is_controlled_locally or not has_received_initial_sync:
        return
    
    var current_time = Time.get_unix_time_from_system()
    
    # Apenas assumir controle se realmente não houver sincronização por muito tempo
    if last_heartbeat_received > 0 and current_time - last_heartbeat_received > HEARTBEAT_TIMEOUT:
        print("🔴 Inimigo " + enemy_id + " órfão detectado após " + str(HEARTBEAT_TIMEOUT) + "s! Assumindo controle...")
        _assume_control_emergency()

func assume_control(new_owner_id: String) -> void:
    """Força assumir controle deste inimigo"""
    owner_player_id = new_owner_id
    var my_player_id = ""
    if main and main.has_method("get_local_player_id"):
        my_player_id = main.get_local_player_id()
    elif main and "multiplayer_manager" in main:
        my_player_id = main.multiplayer_manager.get_local_player_id()
    
    is_controlled_locally = (new_owner_id == my_player_id)
    last_heartbeat_received = Time.get_unix_time_from_system()
    has_received_initial_sync = true
    
    var control_status = "CONTROLADO" if is_controlled_locally else "REMOTO"
    print("🔄 Inimigo " + enemy_id + " ownership mudou para " + new_owner_id + " (" + control_status + ")")

func _assume_control_emergency() -> void:
    """Assume controle de emergência para inimigos sem dono"""
    is_controlled_locally = true
    var my_player_id = ""
    if main and main.has_method("get_local_player_id"):
        my_player_id = main.get_local_player_id()
    elif main and "multiplayer_manager" in main:
        my_player_id = main.multiplayer_manager.get_local_player_id()
    
    owner_player_id = my_player_id
    last_heartbeat_received = Time.get_unix_time_from_system()
    print("🔴 EMERGÊNCIA: Inimigo " + enemy_id + " assumindo controle local!")

# FUNÇÃO VIRTUAL - Deve ser sobrescrita pelas classes filhas
func _drop_item() -> void:
    print("⚠️ _drop_item() não implementado para " + enemy_type)

func _notify_damage(damage: int, new_hp: int) -> void:
    """Notifica servidor sobre dano recebido"""
    var multiplayer_manager = _get_multiplayer_manager()
    if multiplayer_manager and multiplayer_manager.has_method("send_enemy_damage"):
        multiplayer_manager.send_enemy_damage(enemy_id, damage, new_hp)

func _notify_death() -> void:
    """Notifica servidor sobre morte"""
    var multiplayer_manager = _get_multiplayer_manager()
    if multiplayer_manager and multiplayer_manager.has_method("send_enemy_death"):
        multiplayer_manager.send_enemy_death(enemy_id, global_position)

func _get_multiplayer_manager():
    """Encontra o MultiplayerManager"""
    # Tentar encontrar no main primeiro
    if main and "multiplayer_manager" in main:
        return main.multiplayer_manager
    
    # Buscar na árvore
    var tree = get_tree()
    if tree:
        var nodes = tree.get_nodes_in_group("multiplayer_manager")
        if nodes.size() > 0:
            return nodes[0]
    
    return null

# helpers
func _add_preloaded_animation(anim_name: String, textures: Array, fps: int, loop: bool) -> void:
    if textures.is_empty():
        return
    frames.add_animation(anim_name)
    frames.set_animation_loop(anim_name, loop)
    frames.set_animation_speed(anim_name, fps)
    for texture in textures:
        if texture is Texture2D:
            frames.add_frame(anim_name, texture)

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

func _load_enemy_sprites() -> void:
    """Carrega sprites do inimigo usando sistema escalável"""
    
    # Carregar animações: idle, walk, attack
    _load_animation("idle", fps_idle, true)
    _load_animation("walk", fps_walk, true) 
    _load_animation("attack", fps_attack, false)

func _load_animation(animation_name: String, fps: int, loop: bool) -> void:
    """Carrega uma animação específica do sistema de pastas"""
    var animation_frames = []
    var base_path = enemy_base_path + enemy_type + "/" + animation_name + "/"
    
    # Tentar carregar até 20 frames (0-19)
    for i in range(20):
        var path = base_path + "frame_%03d.png" % i
        if ResourceLoader.exists(path):
            var texture = load(path)
            if texture:
                animation_frames.append(texture)
        else:
            # Se não encontrou frame sequencial, parar busca
            break
    
    # Fallback: tentar carregar do sistema antigo se não encontrou nada
    if animation_frames.size() == 0 and animation_name == "walk":
        _load_legacy_walk_animation(animation_frames)
    elif animation_frames.size() == 0 and animation_name == "attack":
        _load_legacy_attack_animation(animation_frames)
    
    # Criar animação se tem frames
    if animation_frames.size() > 0:
        frames.add_animation(animation_name)
        frames.set_animation_speed(animation_name, fps)
        frames.set_animation_loop(animation_name, loop)
        for frame in animation_frames:
            frames.add_frame(animation_name, frame)
        print("✅ Carregada animação '" + animation_name + "' com " + str(animation_frames.size()) + " frames")
    else:
        print("⚠️ Nenhum frame encontrado para animação '" + animation_name + "'")

func _load_legacy_walk_animation(animation_frames: Array) -> void:
    """Fallback para carregar animação walk do sistema antigo"""
    for i in range(10):
        var path = "res://art/enemy_forest/walk_east/frame_%03d.png" % i
        if ResourceLoader.exists(path):
            var texture = load(path)
            if texture:
                animation_frames.append(texture)

func _load_legacy_attack_animation(animation_frames: Array) -> void:
    """Fallback para carregar animação attack do sistema antigo"""
    for i in range(10):
        var path = "res://art/enemy_forest/attack_east/frame_%03d.png" % i
        if ResourceLoader.exists(path):
            var texture = load(path)
            if texture:
                animation_frames.append(texture)
