extends Node2D

var main: Node

# Elementos do mundo
var ground_body: StaticBody2D
var walls: Array[StaticBody2D] = []
var background: Sprite2D
const SHOW_BACKGROUND := false
const SHOW_PLATFORM_VISUAL := true
const GROUND_VISUAL_OFFSET := 8.0
const GROUND_COLOR := Color(0.18, 0.22, 0.18, 1.0)
const WALL_COLOR := Color(0.12, 0.16, 0.12, 1.0)

# Sistema de inimigos sincronizados
var enemies: Dictionary = {}  # enemy_id -> MultiplayerEnemy (OrcEnemy, SlimeEnemy, etc.)

# Configurações
const GROUND_HEIGHT: float = 30.0
const WALL_THICKNESS: float = 40.0
const BOTTOM_MARGIN: float = 120.0

func setup(main_ref: Node) -> void:
    main = main_ref
    _create_world()
    
    # ✨ SERVIDOR AUTHORITATIVE: Cliente nunca spawna inimigos!
    # Todos os inimigos são controlados pelo servidor Python
    print("🌲 Cliente DISPLAY-ONLY: Aguardando inimigos do servidor...")
    main.set_enemies_to_kill(5)  # Meta para o HUD
    
    _setup_enemy_sync()
    
    # 📡 Solicitar estado atual dos inimigos do servidor
    _request_enemies_from_server()

func _create_world() -> void:
    var viewport_size = _get_viewport_size()
    _create_background(viewport_size)
    _create_ground(viewport_size)
    _create_walls(viewport_size)
    _create_camera()

func _get_viewport_size() -> Vector2:
    var viewport = get_viewport()
    if viewport:
        return viewport.get_visible_rect().size
    return Vector2(1024, 768)

func _create_background(viewport_size: Vector2) -> void:
    if not SHOW_BACKGROUND:
        return
    var bg_texture = load("res://art/bg/forest_bg.png") as Texture2D
    if bg_texture:
        background = Sprite2D.new()
        background.texture = bg_texture
        background.z_index = -1
        # Calcular escala para cobrir a tela toda
        var texture_size = bg_texture.get_size()
        var scale_x = viewport_size.x / float(texture_size.x)
        var scale_y = viewport_size.y / float(texture_size.y)
        var bg_scale = max(scale_x, scale_y)
        background.scale = Vector2(bg_scale, bg_scale)
        background.position = Vector2.ZERO
        add_child(background)

func _create_ground(viewport_size: Vector2) -> void:
    ground_body = StaticBody2D.new()
    var collision = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    
    shape.size = Vector2(viewport_size.x, GROUND_HEIGHT)
    collision.shape = shape
    ground_body.add_child(collision)
    
    # Alinhar com o servidor: ground_y server-side = 184.0 (y dos pés do player)
    var ground_y = 184.0 + (GROUND_HEIGHT * 0.5) + GROUND_VISUAL_OFFSET
    ground_body.position = Vector2(0, ground_y)
    
    # Configurar camadas de colisão
    ground_body.set_collision_layer_value(2, true)  # Ground na camada 2 (ambiente)
    ground_body.set_collision_mask_value(1, true)
    ground_body.set_collision_mask_value(3, true)
    
    add_child(ground_body)

    # Visual helper for platforms
    if SHOW_PLATFORM_VISUAL:
        _add_visual_rect(ground_body, shape.size, GROUND_COLOR)

func _create_walls(viewport_size: Vector2) -> void:
    # Parede esquerda
    var left_wall = _create_wall(Vector2(WALL_THICKNESS, viewport_size.y + 200))
    left_wall.position = Vector2(-viewport_size.x * 0.5 + WALL_THICKNESS * 0.5, 0)
    walls.append(left_wall)
    
    # Parede direita  
    var right_wall = _create_wall(Vector2(WALL_THICKNESS, viewport_size.y + 200))
    right_wall.position = Vector2(viewport_size.x * 0.5 - WALL_THICKNESS * 0.5, 0)
    walls.append(right_wall)
    
    # Teto
    var ceiling = _create_wall(Vector2(viewport_size.x, WALL_THICKNESS))
    ceiling.position = Vector2(0, -viewport_size.y * 0.5 + WALL_THICKNESS * 0.5)
    walls.append(ceiling)

func _create_wall(size: Vector2) -> StaticBody2D:
    var wall = StaticBody2D.new()
    var collision = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    
    shape.size = size
    collision.shape = shape
    wall.add_child(collision)
    
    # Configurar camadas de colisão
    wall.set_collision_layer_value(2, true)  # Paredes na camada 2 (ambiente)
    wall.set_collision_mask_value(1, true)
    wall.set_collision_mask_value(3, true)
    
    add_child(wall)
    
    # Visual helper for walls
    if SHOW_PLATFORM_VISUAL:
        _add_visual_rect(wall, shape.size, WALL_COLOR)
    return wall

func _create_camera() -> void:
    var camera = Camera2D.new()
    camera.position = Vector2.ZERO
    add_child(camera)
    camera.call_deferred("make_current")

func _add_visual_rect(parent: Node2D, size: Vector2, color: Color) -> void:
    var poly := Polygon2D.new()
    var hw = size.x * 0.5
    var hh = size.y * 0.5
    poly.polygon = PackedVector2Array([
        Vector2(-hw, -hh),
        Vector2(hw, -hh),
        Vector2(hw, hh),
        Vector2(-hw, hh),
    ])
    poly.color = color
    poly.z_index = -1
    parent.add_child(poly)

# FUNÇÃO REMOVIDA - Sistema agora é server-side authoritative
# Os inimigos são criados e controlados pelo servidor Python
# O cliente apenas recebe e exibe os estados via _create_enemy_from_server_data()

func get_player_spawn_position() -> Vector2:
    # Spawn aproximado; servidor enviará posição autoritativa
    # Mantemos Y compatível (~159) para evitar saltos visuais ao carregar
    return Vector2(-200.0, 159.0)

func _request_enemies_from_server() -> void:
    """Solicita o estado atual dos inimigos do servidor"""
    if not main or not main.multiplayer_manager:
        print("❌ Sem MultiplayerManager para solicitar inimigos")
        return
    
    var request_data = {
        "type": "request_enemies_state",
        "map_name": "Floresta"
    }
    
    main.multiplayer_manager._send_message(request_data)
    print("📡 Solicitando inimigos da Floresta ao servidor...")

func _setup_enemy_sync() -> void:
    """Configura sincronização de inimigos"""
    if main and "multiplayer_manager" in main:
        var manager = main.multiplayer_manager
        manager.enemy_death_received.connect(_on_enemy_death_received)
        manager.enemy_position_sync_received.connect(_on_enemy_position_sync_received)
        
        # 🆕 Novos sinais para servidor authoritative
        if manager.has_signal("enemies_state_received"):
            manager.enemies_state_received.connect(_on_enemies_state_received)
        if manager.has_signal("enemies_update_received"):
            manager.enemies_update_received.connect(_on_enemies_update_received)
        
        # Manter eventos de players (não são mais usados para ownership)
        manager.player_connected.connect(_on_player_connected)
        manager.player_disconnected.connect(_on_player_disconnected)
        manager.map_change_received.connect(_on_player_map_changed)

func _determine_enemy_owner(enemy_index: int, my_player_id: String) -> String:
    """Determina qual player controla este inimigo baseado em um algoritmo determinístico"""
    if not main or not main.multiplayer_manager:
        print("⚠️ Sem MultiplayerManager, assumindo controle local para inimigo %d" % enemy_index)
        return my_player_id
    
    if my_player_id.is_empty():
        print("⚠️ Player ID vazio! Gerando ID temporário...")
        my_player_id = "temp_" + str(randi())
    
    # Obter apenas players que estão no mapa atual (Floresta)
    var players_in_forest = _get_players_in_current_map()
    
    # Se não há players na floresta, assumir controle local
    if players_in_forest.is_empty():
        print("⚠️ Nenhum player na Floresta! Assumindo controle local para inimigo %d" % enemy_index)
        return my_player_id
    
    # Distribuir inimigos entre os players de forma round-robin ESTÁVEL
    var owner_index = enemy_index % players_in_forest.size()
    var owner_id = players_in_forest[owner_index]
    
    print("🎯 Inimigo %d será controlado por player %s (de %s players na Floresta: %s)" % [enemy_index, owner_id, players_in_forest.size(), players_in_forest])
    return owner_id

func _register_enemy(enemy: MultiplayerEnemy) -> void:
    """Registra inimigo no sistema de sincronização"""
    if enemy and enemy.enemy_id != "":
        enemies[enemy.enemy_id] = enemy
        var control_status = "CONTROLADO" if enemy.is_controlled_locally else "REMOTO"
        print("🐺 Inimigo registrado: " + enemy.enemy_id + " (" + control_status + ")")

func _on_enemy_death_received(enemy_id: String, killer_id: String) -> void:
    """Processa morte de inimigo de outro player"""
    print("🔍 RECEBIDO morte de inimigo: " + enemy_id + " matador: " + killer_id)
    print("🔍 Inimigos disponíveis: " + str(enemies.keys()))
    
    if enemy_id in enemies:
        var enemy = enemies[enemy_id]
        if is_instance_valid(enemy):
            print("💀 REMOVENDO inimigo morto por outro player: " + enemy_id)
            enemy.queue_free()
            enemies.erase(enemy_id)
            print("✅ Inimigo " + enemy_id + " removido com sucesso")
        else:
            print("❌ Inimigo " + enemy_id + " já foi destruído")
            enemies.erase(enemy_id)
    else:
        print("❌ Inimigo " + enemy_id + " NÃO ENCONTRADO na lista de inimigos")

func _on_enemy_position_sync_received(sync_data: Dictionary) -> void:
    """Processa sincronização de posição de inimigo remoto"""
    var enemy_id = sync_data.get("enemy_id", "")
    var controller_id = sync_data.get("controller_id", "")
    var sync_position = sync_data.get("position", {})
    var velocity = sync_data.get("velocity", {})
    var flip_h = sync_data.get("flip_h", false)
    var animation = sync_data.get("animation", "idle")
    
    # Verificar se não é uma sincronização de nós mesmos
    var my_player_id = ""
    if main and main.multiplayer_manager:
        my_player_id = main.multiplayer_manager.get_local_player_id()
    
    if controller_id == my_player_id:
        return  # Ignorar nossa própria sincronização
    
    if enemy_id in enemies:
        var enemy = enemies[enemy_id]
        if is_instance_valid(enemy) and not enemy.is_controlled_locally:
            # Usar método de sincronização do inimigo para garantir consistência
            if "x" in sync_position and "y" in sync_position and "x" in velocity and "y" in velocity:
                var enemy_position = Vector2(sync_position.x, sync_position.y)
                var sync_velocity = Vector2(velocity.x, velocity.y)
                enemy.apply_remote_sync(enemy_position, sync_velocity, flip_h, animation)
                print("🔄 Sincronizando inimigo " + enemy_id + " de " + controller_id + " para posição " + str(enemy_position))
        else:
            if is_instance_valid(enemy) and enemy.is_controlled_locally:
                print("⚠️ IGNORANDO sincronização para inimigo controlado localmente: " + enemy_id)

func _on_enemy_damage_received(enemy_data: Dictionary) -> void:
    """Processa dano ao inimigo de outro player"""
    var enemy_id = enemy_data.get("enemy_id", "")
    var damage = enemy_data.get("damage", 0)
    var new_hp = enemy_data.get("new_hp", 0)
    
    if enemy_id in enemies:
        var enemy = enemies[enemy_id]
        if is_instance_valid(enemy):
            # Aplicar dano visual sem afetar HP real (já foi processado pelo atacante)
            enemy.hp = new_hp
            if main and main.has_method("show_damage_popup_at_world"):
                main.show_damage_popup_at_world(enemy.global_position, "-" + str(damage), Color(1, 0.2, 0.2, 1))
            print("⚔️ Inimigo " + enemy_id + " sincronizado com HP: " + str(new_hp))

# Função removida - sistema agora é server-side

func _on_player_connected(_player_info: Dictionary) -> void:
    """Quando novo player conecta, reassignar ownership dos inimigos"""
    # Player connected, reassigning ownership
    # Temporariamente desabilitado para evitar conflitos
    # _reassign_all_enemy_ownership()

func _on_player_disconnected(_player_id: String) -> void:
    """Quando player desconecta, reassignar ownership dos inimigos"""
    # Player disconnected, reassigning ownership
    # Temporariamente desabilitado para evitar conflitos
    # _reassign_all_enemy_ownership()

func _on_player_map_changed(_player_id: String, _current_map: String) -> void:
    """Quando player muda de mapa, reassignar ownership dos inimigos"""
    print("🗺️ Player mudou de mapa, reassignando ownership...")
    # Temporariamente desabilitado para evitar conflitos
    # _reassign_all_enemy_ownership()

func _reassign_all_enemy_ownership() -> void:
    """Reassigna ownership de todos os inimigos vivos baseado nos players atualmente no mapa"""
    if not main or not main.multiplayer_manager:
        return
    
    # Obter lista atual de players no mesmo mapa
    var current_players = _get_players_in_current_map()
    if current_players.is_empty():
        return
    
    # Reassigning enemy ownership
    
    # Reassignar cada inimigo vivo
    var enemy_index = 0
    for enemy_id in enemies.keys():
        var enemy = enemies[enemy_id]
        if is_instance_valid(enemy):
            var old_owner = enemy.owner_player_id
            var new_owner = current_players[enemy_index % current_players.size()]
            
            # Atualizar ownership usando método do inimigo
            if enemy.has_method("assume_control"):
                enemy.assume_control(new_owner)
            else:
                # Fallback para compatibilidade
                enemy.owner_player_id = new_owner
                var my_player_id = main.multiplayer_manager.get_local_player_id()
                enemy.is_controlled_locally = (new_owner == my_player_id)
            
            if old_owner != new_owner:
                var _control_status = "CONTROLADO" if enemy.is_controlled_locally else "REMOTO"
                # Enemy ownership updated
            
            enemy_index += 1

func _get_players_in_current_map() -> Array[String]:
    """Retorna lista de players que estão no mapa atual"""
    if not main or not main.multiplayer_manager:
        return []
    
    var current_map = "Floresta"  # Este é o mapa da floresta
    var my_player_id = main.multiplayer_manager.get_local_player_id()
    var players_in_map: Array[String] = []
    
    # Adicionar jogador local se estiver neste mapa
    if main.has_method("get_current_map") and main.get_current_map() == current_map:
        players_in_map.append(my_player_id)
    
    # Verificar jogadores remotos
    var all_players = main.multiplayer_manager.get_players_data()
    for player_id in all_players.keys():
        if player_id != my_player_id:
            var player_info = all_players[player_id]
            var player_map = player_info.get("current_map", "Cidade")
            if player_map == current_map:
                players_in_map.append(player_id)
    
    players_in_map.sort()  # Manter ordem determinística
    return players_in_map

func handle_player_attack(attack_position: Vector2, damage: int) -> void:
    """Envia ataque do player para o servidor (SERVER AUTHORITATIVE)"""
    # Encontrar inimigo mais próximo da posição de ataque
    var closest_enemy = null
    var closest_distance = 50.0  # Distância máxima para acertar
    
    for enemy_id in enemies.keys():
        var enemy = enemies[enemy_id]
        if is_instance_valid(enemy):
            var distance = enemy.global_position.distance_to(attack_position)
            if distance < closest_distance:
                closest_enemy = enemy
                closest_distance = distance
    
    # 📡 ENVIAR ataque para o servidor (não aplicar localmente)
    if closest_enemy and main and main.multiplayer_manager:
        var attack_data = {
            "type": "player_attack_enemy",
            "enemy_id": closest_enemy.enemy_id,
            "damage": damage,
            "attack_position": {"x": attack_position.x, "y": attack_position.y}
        }
        
        main.multiplayer_manager._send_message(attack_data)
        print("📡 Ataque enviado ao servidor: " + str(damage) + " em " + closest_enemy.enemy_id)
        
        # Feedback visual imediato (opcional)
        if main and main.has_method("show_damage_popup_at_world"):
            main.show_damage_popup_at_world(closest_enemy.global_position, "-" + str(damage), Color(0.8, 0.8, 0.2, 1))

# ===== FUNÇÕES SERVER AUTHORITATIVE =====

func _on_enemies_state_received(enemies_data: Array) -> void:
    """Recebe estado inicial dos inimigos do servidor"""
    print("📡 Recebidos " + str(enemies_data.size()) + " inimigos do servidor")
    
    for i in range(enemies_data.size()):
        var enemy_data = enemies_data[i]
        print("DEBUG - Processando inimigo " + str(i+1) + ": " + str(enemy_data.get("enemy_id", "unknown")))
        _create_enemy_from_server_data(enemy_data)

func _on_enemies_update_received(enemies_data: Array) -> void:
    """Recebe atualizações dos inimigos do servidor"""
    print("📡 Recebendo atualização de " + str(enemies_data.size()) + " inimigos do servidor")
    for enemy_data in enemies_data:
        _update_enemy_from_server_data(enemy_data)

func _create_enemy_from_server_data(enemy_data: Dictionary) -> void:
    """Cria um inimigo baseado nos dados do servidor"""
    var enemy_id = enemy_data.get("enemy_id", "")
    print("DEBUG - _create_enemy_from_server_data() chamado para: " + enemy_id)
    
    if enemy_id == "":
        print("ERRO - enemy_id vazio: " + str(enemy_data))
        return
    
    if enemy_id in enemies:
        print("DEBUG - Inimigo " + enemy_id + " já existe, ignorando")
        return
    
    # Criar inimigo para server authoritative (apenas visual)
    const OrcEnemyScene = preload("res://scripts/enemies/orc_enemy.gd")
    var enemy = OrcEnemyScene.new()
    enemy.enemy_id = enemy_id
    enemy.is_controlled_locally = false  # Server authoritative - apenas display
    enemy.main = main
    
    # Desabilitar processamento local (servidor controla tudo)
    enemy.set_physics_process(false)  # Desabilitar movimento local
    
    # 🔧 CONFIGURAR COMO DISPLAY-ONLY (sem colisão física)
    call_deferred("_setup_display_only_enemy", enemy)
    
    # Aplicar estado do servidor
    # Dados do servidor usam chaves planas: 'x', 'y', 'velocity_x', 'velocity_y'
    var ex = float(enemy_data.get("x", 0.0))
    var ey = float(enemy_data.get("y", 0.0))
    enemy.position = Vector2(ex, ey)
    enemy.hp = enemy_data.get("hp", 100)
    
    add_child(enemy)
    enemies[enemy_id] = enemy
    
    print("🎭 Inimigo criado (DISPLAY-ONLY): " + enemy_id + " na posição " + str(enemy.position))
    print("DEBUG - Total de inimigos agora: " + str(enemies.size()))

func _setup_display_only_enemy(enemy: Node) -> void:
    """Configura inimigo para ser display-only (sem colisão com player)"""
    if not is_instance_valid(enemy):
        return
    
    # Remover colisão com players (manter apenas visual)
    enemy.set_collision_layer_value(2, false)  # Remove da camada de inimigos
    enemy.set_collision_mask_value(1, false)   # Não colide com players
    enemy.set_collision_mask_value(2, false)   # Não colide com ambiente
    enemy.set_collision_mask_value(3, false)   # Remove todas as colisões
    
    print("🔧 Inimigo configurado como DISPLAY-ONLY (sem colisões): " + enemy.enemy_id)

func _update_enemy_from_server_data(enemy_data: Dictionary) -> void:
    """Atualiza inimigo baseado nos dados do servidor"""
    var enemy_id = enemy_data.get("enemy_id", "")
    if enemy_id == "" or enemy_id not in enemies:
        # Inimigo não existe, criar
        _create_enemy_from_server_data(enemy_data)
        return
    
    var enemy = enemies[enemy_id]
    if not is_instance_valid(enemy):
        enemies.erase(enemy_id)
        return
    
    # Atualizar estado do inimigo
    # Campos planos do sync: x, y, velocity_x, velocity_y
    var ex = float(enemy_data.get("x", enemy.position.x))
    var ey = float(enemy_data.get("y", enemy.position.y))
    var evx = float(enemy_data.get("velocity_x", 0.0))
    var evy = float(enemy_data.get("velocity_y", 0.0))
    
    # Evitar sobreposição visual com o player local (display-only):
    if main and main.local_player:
        var lp = main.local_player.global_position
        var dx = ex - lp.x
        var min_gap = 22.0  # distância mínima visual
        if abs(dx) < min_gap:
            ex = lp.x + (min_gap if dx >= 0.0 else -min_gap)
    enemy.global_position = Vector2(ex, ey)
    enemy.velocity = Vector2(evx, evy)
    enemy.hp = enemy_data.get("hp", enemy.hp)
    
    # Atualizar animação e sprite
    var animation = enemy_data.get("animation", "idle")
    var facing_left = enemy_data.get("facing_left", false)
    
    if enemy.sprite:
        enemy.sprite.flip_h = facing_left
        if enemy.frames and enemy.frames.has_animation(animation):
            # Garantir que o FPS está correto
            if animation == "idle":
                enemy.frames.set_animation_speed(animation, enemy.fps_idle)
            elif animation == "walk":
                enemy.frames.set_animation_speed(animation, enemy.fps_walk)
            elif animation == "attack":
                enemy.frames.set_animation_speed(animation, enemy.fps_attack)
            
            enemy.sprite.play(animation)
            # Apenas log mudanças de animação, não idle constante
            if animation != "idle":
                print("🎬 Animação aplicada: " + animation + " no inimigo " + enemy_id)
