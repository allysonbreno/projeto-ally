extends CharacterBody2D
class_name MultiplayerPlayer

# ============================================================================
# MULTIPLAYER PLAYER - VISUAL RENDERING ONLY (SERVER-AUTHORITATIVE)
# ============================================================================
# Este player é APENAS para renderização visual.
# TODA lógica de movimento, física e validação está no SERVIDOR Python.
# Este script apenas:
# - Renderiza a posição recebida do servidor
# - Mostra animações baseadas no estado do servidor
# - Captura input local (se for player local) e envia para servidor

# Sinais para comunicação com o jogo
signal player_update(pos: Vector2, velocity: Vector2, animation: String, facing: int, hp: int)
signal player_update_with_sequence(pos: Vector2, velocity: Vector2, animation: String, facing: int, hp: int, sequence: int)
signal player_action(action: String, action_data: Dictionary)

# Player info
var player_id: String = ""
var player_name: String = ""
var is_local_player: bool = false
var character_type: String = "warrior"  # Default to warrior

# Referência ao MultiplayerManager
var multiplayer_manager: MultiplayerManager

# Componentes visuais
var sprite: AnimatedSprite2D
var name_label: Label
var current_animation: String = "idle"
var last_flip_h: bool = false  # memorização da última direção visual

# Configurações visuais
const SPRITE_SCALE: Vector2 = Vector2(1.0, 1.0)
const FPS_IDLE: int = 4
const FPS_WALK: int = 15
const FPS_ATTACK: int = 4
const FPS_JUMP: int = 3

# Input local (apenas para player local)
var input_buffer: Dictionary = {
    "move_left": false,
    "move_right": false,
    "jump": false,
    "attack": false
}
var input_sequence: int = 0  # Contador para client prediction

# ============================================================================
# INICIALIZAÇÃO
# ============================================================================

func _ready():
    _setup_visual_components()
    _setup_multiplayer_manager()

func _setup_visual_components():
    """Configura componentes visuais"""
    print("🎨 [PLAYER] Configurando componentes visuais...")
    
    # Sprite animado
    sprite = AnimatedSprite2D.new()
    add_child(sprite)
    sprite.scale = SPRITE_SCALE
    print("🎨 [PLAYER] AnimatedSprite2D criado, scale: ", SPRITE_SCALE)
    
    # Carregar frames de animação
    _load_sprite_frames()
    print("🎨 [PLAYER] Frames carregados")
    
    # Definir animação inicial
    if sprite.sprite_frames:
        sprite.animation = "idle"
        sprite.play()
        print("🎨 [PLAYER] Animação 'idle' iniciada")
    else:
        print("❌ [PLAYER] sprite_frames é null!")
    
    # Tornar visível
    sprite.visible = true
    print("🎨 [PLAYER] Sprite marcado como visível")
    
    # Nametag
    name_label = Label.new()
    add_child(name_label)
    name_label.position = Vector2(-30, -80)
    name_label.add_theme_color_override("font_color", Color.WHITE)
    name_label.add_theme_color_override("font_shadow_color", Color.BLACK)
    name_label.add_theme_constant_override("shadow_offset_x", 1)
    name_label.add_theme_constant_override("shadow_offset_y", 1)
    name_label.text = "PLAYER"
    name_label.visible = true
    print("🎨 [PLAYER] Label criado e visível")

func _setup_multiplayer_manager():
    """Encontra referência ao MultiplayerManager"""
    # Tentar encontrar o MultiplayerManager no jogo pai
    var current_node = get_parent()
    while current_node:
        if current_node.has_method("get") and current_node.get("multiplayer_manager"):
            multiplayer_manager = current_node.get("multiplayer_manager")
            print("✅ MultiplayerManager encontrado via parent!")
            return
        current_node = current_node.get_parent()
    
    # Fallback: tentar caminho direto
    multiplayer_manager = get_node_or_null("/root/MultiplayerManager")
    if not multiplayer_manager:
        print("⚠️ MultiplayerManager não encontrado! Será definido depois.")

func _load_sprite_frames():
    """Carrega frames de animação do player baseado no character_type"""
    print("🖼️ [PLAYER] Carregando sprite frames para character_type: ", character_type)
    var frames = SpriteFrames.new()
    
    # Define o caminho base baseado no character_type
    var base_path = "res://characters/" + character_type + "/"
    print("🖼️ [PLAYER] Caminho base das animações: ", base_path)
    
    # Animação idle
    frames.add_animation("idle")
    frames.set_animation_speed("idle", FPS_IDLE)
    var idle_count = 0
    for i in range(8):  # 8 frames idle
        var texture_path = base_path + "idle_east/frame_%03d.png" % i
        if ResourceLoader.exists(texture_path):
            frames.add_frame("idle", load(texture_path))
            idle_count += 1
    print("🖼️ [PLAYER] Frames idle carregados: ", idle_count)
    
    # Animação walk
    frames.add_animation("walk")
    frames.set_animation_speed("walk", FPS_WALK)
    var walk_count = 0
    for i in range(8):  # 8 frames walk
        var texture_path = base_path + "walk_east/frame_%03d.png" % i
        if ResourceLoader.exists(texture_path):
            frames.add_frame("walk", load(texture_path))
            walk_count += 1
    print("🖼️ [PLAYER] Frames walk carregados: ", walk_count)
    
    # Animação attack
    frames.add_animation("attack")
    frames.set_animation_speed("attack", FPS_ATTACK)
    var attack_count = 0
    for i in range(8):  # 8 frames attack
        var texture_path = base_path + "attack_east/frame_%03d.png" % i
        if ResourceLoader.exists(texture_path):
            frames.add_frame("attack", load(texture_path))
            attack_count += 1
    print("🖼️ [PLAYER] Frames attack carregados: ", attack_count)
    
    # Animação jump
    frames.add_animation("jump")
    frames.set_animation_speed("jump", FPS_JUMP)
    var jump_count = 0
    for i in range(3):  # 3 frames jump
        var texture_path = base_path + "jump_east/frame_%03d.png" % i
        if ResourceLoader.exists(texture_path):
            frames.add_frame("jump", load(texture_path))
            jump_count += 1
    print("🖼️ [PLAYER] Frames jump carregados: ", jump_count)
    
    sprite.sprite_frames = frames
    print("🖼️ [PLAYER] SpriteFrames definido no sprite. Animações disponíveis: ", frames.get_animation_names())

# ============================================================================
# PROCESSO PRINCIPAL (SERVER-SIDE RENDERING)
# ============================================================================

func _process(_delta):
    """Processamento principal - apenas renderização baseada em dados do servidor"""
    if is_local_player:
        _handle_local_input()
    
    _update_visual_from_server()

func _handle_local_input():
    """Captura input local e envia para servidor (apenas se for player local)"""
    if not multiplayer_manager or not multiplayer_manager.is_logged_in:
        return
    
    # Capturar input atual (usando actions corretas do projeto)
    var current_input = {
        "move_left": Input.is_action_pressed("ui_left"),
        "move_right": Input.is_action_pressed("ui_right"),
        "jump": Input.is_action_just_pressed("ui_up"),
        "attack": Input.is_action_just_pressed("attack")
    }
    
    # Debug: Log input quando há mudança
    if current_input["move_left"] or current_input["move_right"] or current_input["jump"] or current_input["attack"]:
        print("🎮 [INPUT] Capturado: ", current_input)
    
    # Verificar se houve mudança no input
    var input_changed = false
    for key in current_input:
        if current_input[key] != input_buffer[key]:
            input_changed = true
            break
    
    # Enviar input apenas se houve mudança (otimização)
    if input_changed:
        input_buffer = current_input
        multiplayer_manager.send_input(input_buffer)
        
        # Incrementar sequência para client prediction
        input_sequence += 1
        
        # Emitir sinal de atualização do player local (para compatibilidade)
        var facing_direction = 1 if not sprite or not sprite.flip_h else -1
        player_update.emit(position, velocity, current_animation, facing_direction, 100)  # HP fixo por enquanto
        
        # Emitir sinal com sequência (para client prediction avançado)
        player_update_with_sequence.emit(position, velocity, current_animation, facing_direction, 100, input_sequence)
        
        # Emitir ação se foi pressionada
        if current_input.get("attack", false):
            # TODO: Conectar handler para player_action no main
            print("🗡️ [ACTION] Ataque executado!")
            # player_action.emit("attack", {"damage": 34})

func _update_visual_from_server():
    """Atualiza visual baseado nos dados recebidos do servidor"""
    if not multiplayer_manager:
        return
    
    # Obter dados mais recentes do servidor
    var server_data = multiplayer_manager.get_player_data(player_id)
    if server_data.is_empty():
        return
    
    # Atualizar posição (interpolação suave)
    var server_pos = server_data.get("position", {})
    if not server_pos.is_empty():
        var target_position = Vector2(server_pos.get("x", position.x), server_pos.get("y", position.y))
        position = position.lerp(target_position, 0.3)  # Interpolação suave
    
    # Atualizar animação
    var server_animation = server_data.get("animation", "idle")
    _update_animation(server_animation)
    
    # Atualizar direção (flip sprite)
    var facing = server_data.get("facing", 1)
    if facing < 0:
        sprite.flip_h = true
    else:
        sprite.flip_h = false

    # Fix de flip baseado na velocidade: parado mantém última direção
    var __vel_fix = server_data.get("velocity", {})
    var __vx = __vel_fix.get("x", 0.0)
    if abs(__vx) > 1.0:
        # Lógica correta: andando à direita -> flip false; à esquerda -> flip true
        sprite.flip_h = __vx < 0.0
        last_flip_h = sprite.flip_h
    else:
        # Sem movimento horizontal: manter última direção
        sprite.flip_h = last_flip_h

    # Atualizar label do nome a partir do estado do servidor (garante nomes distintos)
    if name_label and server_data.has("name"):
        var __new_name = str(server_data.get("name", name_label.text))
        if __new_name != "" and name_label.text != __new_name:
            name_label.text = __new_name

# ============================================================================
# SISTEMA DE ANIMAÇÃO (BASEADO EM DADOS DO SERVIDOR)
# ============================================================================

func _update_animation(new_animation: String):
    """Atualiza animação baseada no estado do servidor"""
    if new_animation != current_animation:
        current_animation = new_animation
        
        # Verificar se a animação existe
        if sprite.sprite_frames and sprite.sprite_frames.has_animation(current_animation):
            sprite.play(current_animation)
        else:
            sprite.play("idle")  # Fallback

# ============================================================================
# CONFIGURAÇÃO DO PLAYER
# ============================================================================

func setup_player(p_id: String, p_name: String, player_is_local: bool, p_character_type: String = "warrior"):
    """Configura os dados do player"""
    player_id = p_id
    player_name = p_name
    is_local_player = player_is_local
    character_type = p_character_type
    
    # Recarregar frames de animação com o novo character_type
    if sprite:
        _load_sprite_frames()
    
    # Atualizar nametag
    if name_label:
        name_label.text = player_name
        
        # Cor diferente para player local
        if is_local_player:
            name_label.add_theme_color_override("font_color", Color.CYAN)
        else:
            name_label.add_theme_color_override("font_color", Color.WHITE)
    
    print("🎮 Player configurado: " + player_name + " (Local: " + str(is_local_player) + ")")

func set_server_position(pos: Vector2):
    """Define posição diretamente do servidor (sem interpolação)"""
    position = pos

func set_server_data(data: Dictionary):
    """Define todos os dados do servidor de uma vez"""
    # Posição
    var server_pos = data.get("position", {})
    if not server_pos.is_empty():
        position = Vector2(server_pos.get("x", position.x), server_pos.get("y", position.y))
    
    # Animação
    var server_animation = data.get("animation", "idle")
    _update_animation(server_animation)
    
    # Direção
    var facing = data.get("facing", 1)
    if sprite:
        sprite.flip_h = (facing < 0)

func apply_sync_data(data: Dictionary):
    """Aplica dados de sincronização do servidor (mesmo que set_server_data)"""
    set_server_data(data)

func update_max_hp():
    """Atualiza HP máximo (compatibilidade com sistema de atributos)"""
    # No sistema server-authoritative, o HP é controlado pelo servidor
    # Esta função existe apenas para compatibilidade
    pass

func set_auto_attack(_enabled: bool):
    """Define auto-attack (compatibilidade com sistema de combate)"""
    # No sistema server-authoritative, auto-attack seria controlado pelo servidor
    # Esta função existe apenas para compatibilidade
    pass

# ============================================================================
# GETTERS
# ============================================================================

func get_player_id() -> String:
    return player_id

func get_player_name() -> String:
    return player_name

func is_local() -> bool:
    return is_local_player
