extends CharacterBody2D
class_name EnemyMultiplayer

# ============================================================================
# ENEMY MULTIPLAYER - VISUAL RENDERING ONLY (SERVER-AUTHORITATIVE)
# ============================================================================
# Este inimigo é APENAS para renderização visual.
# TODA lógica de IA, movimento e combate está no SERVIDOR Python.
# Este script apenas:
# - Renderiza a posição/animação recebida do servidor
# - Mostra o visual do inimigo baseado no estado do servidor

# Enemy info (apenas para renderização)
var enemy_id: String = ""
var enemy_type: String = "orc"
var current_hp: int = 100
var max_hp: int = 100
var current_animation: String = "idle"

# Referência ao MultiplayerManager
var multiplayer_manager: MultiplayerManager

# Componentes visuais
var sprite: AnimatedSprite2D
var hp_bar: ProgressBar
var frames: SpriteFrames

# Configurações visuais
const SPRITE_SCALE: Vector2 = Vector2(0.3, 0.3)
const FPS_IDLE: int = 4
const FPS_WALK: int = 6
const FPS_ATTACK: int = 8

# ============================================================================
# INICIALIZAÇÃO
# ============================================================================

func _ready():
    _setup_visual_components()
    _setup_multiplayer_manager()

func _setup_visual_components():
    """Configura componentes visuais"""
    # Sprite animado
    sprite = AnimatedSprite2D.new()
    add_child(sprite)
    sprite.scale = SPRITE_SCALE
    
    # HP Bar
    _create_hp_bar()
    
    # Carregar frames baseado no tipo de inimigo
    _load_enemy_sprites()

func _setup_multiplayer_manager():
    """Encontra referência ao MultiplayerManager"""
    multiplayer_manager = get_node("/root/MultiplayerManager")
    if not multiplayer_manager:
        print("❌ MultiplayerManager não encontrado!")

func _create_hp_bar():
    """Cria barra de HP visual"""
    hp_bar = ProgressBar.new()
    add_child(hp_bar)
    hp_bar.position = Vector2(-25, -60)
    hp_bar.size = Vector2(50, 8)
    hp_bar.min_value = 0
    hp_bar.max_value = 100
    hp_bar.value = 100
    hp_bar.show_percentage = false
    
    # Estilo da barra de HP
    var style_bg = StyleBoxFlat.new()
    style_bg.bg_color = Color.RED
    style_bg.corner_radius_top_left = 2
    style_bg.corner_radius_top_right = 2
    style_bg.corner_radius_bottom_left = 2
    style_bg.corner_radius_bottom_right = 2
    hp_bar.add_theme_stylebox_override("background", style_bg)
    
    var style_fill = StyleBoxFlat.new()
    style_fill.bg_color = Color.GREEN
    style_fill.corner_radius_top_left = 2
    style_fill.corner_radius_top_right = 2
    style_fill.corner_radius_bottom_left = 2
    style_fill.corner_radius_bottom_right = 2
    hp_bar.add_theme_stylebox_override("fill", style_fill)

func _load_enemy_sprites():
    """Carrega sprites baseado no tipo de inimigo"""
    frames = SpriteFrames.new()
    var enemy_base_path = "res://art/enemies/" + enemy_type + "/"
    
    # Animação idle
    frames.add_animation("idle")
    frames.set_animation_speed("idle", FPS_IDLE)
    for i in range(4):  # 4 frames idle
        var texture_path = enemy_base_path + "idle/frame_%03d.png" % i
        if ResourceLoader.exists(texture_path):
            frames.add_frame("idle", load(texture_path))
    
    # Animação walk
    frames.add_animation("walk")
    frames.set_animation_speed("walk", FPS_WALK)
    for i in range(6):  # 6 frames walk
        var texture_path = enemy_base_path + "walk/frame_%03d.png" % i
        if ResourceLoader.exists(texture_path):
            frames.add_frame("walk", load(texture_path))
    
    # Animação attack
    frames.add_animation("attack")
    frames.set_animation_speed("attack", FPS_ATTACK)
    for i in range(4):  # 4 frames attack
        var texture_path = enemy_base_path + "attack/frame_%03d.png" % i
        if ResourceLoader.exists(texture_path):
            frames.add_frame("attack", load(texture_path))
    
    # Animação death
    frames.add_animation("death")
    frames.set_animation_speed("death", FPS_WALK)
    for i in range(3):  # 3 frames death
        var texture_path = enemy_base_path + "death/frame_%03d.png" % i
        if ResourceLoader.exists(texture_path):
            frames.add_frame("death", load(texture_path))
    
    sprite.sprite_frames = frames

# ============================================================================
# PROCESSO PRINCIPAL (SERVER-SIDE RENDERING)
# ============================================================================

func _process(_delta):
    """Processamento principal - apenas renderização baseada em dados do servidor"""
    _update_visual_from_server()

func _update_visual_from_server():
    """Atualiza visual baseado nos dados recebidos do servidor"""
    if not multiplayer_manager or enemy_id == "":
        return
    
    # TODO: Obter dados do inimigo do servidor
    # Por enquanto vamos manter como está até o servidor enviar dados de inimigos
    
    # Atualizar HP bar
    _update_hp_bar()

func _update_hp_bar():
    """Atualiza barra de HP"""
    if hp_bar:
        hp_bar.value = (float(current_hp) / float(max_hp)) * 100.0
        
        # Ocultar HP bar se estiver com HP cheio
        if current_hp >= max_hp:
            hp_bar.visible = false
        else:
            hp_bar.visible = true

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
# CONFIGURAÇÃO DO INIMIGO
# ============================================================================

func setup_enemy(id: String, type: String, initial_hp: int = 100):
    """Configura os dados do inimigo"""
    enemy_id = id
    enemy_type = type
    current_hp = initial_hp
    max_hp = initial_hp
    
    # Recarregar sprites se mudou o tipo
    _load_enemy_sprites()
    
    print("👹 Inimigo configurado: " + enemy_id + " (" + enemy_type + ")")

func set_server_position(pos: Vector2):
    """Define posição diretamente do servidor"""
    position = pos

func set_server_data(data: Dictionary):
    """Define todos os dados do servidor de uma vez"""
    # Posição
    var server_pos = data.get("position", {})
    if not server_pos.is_empty():
        var target_pos = Vector2(server_pos.get("x", position.x), server_pos.get("y", position.y))
        position = position.lerp(target_pos, 0.5)  # Interpolação suave
    
    # HP
    var server_hp = data.get("hp", current_hp)
    if server_hp != current_hp:
        current_hp = server_hp
        _update_hp_bar()
    
    # Animação
    var server_animation = data.get("animation", "idle")
    _update_animation(server_animation)
    
    # Direção (flip sprite)
    var facing = data.get("facing_left", false)
    if sprite:
        sprite.flip_h = facing

func take_damage(damage: int):
    """Aplica dano visual (apenas feedback visual - dano real é no servidor)"""
    current_hp = max(0, current_hp - damage)
    _update_hp_bar()
    
    # Efeito visual de dano
    var tween = create_tween()
    tween.tween_method(_flash_red, 0.0, 1.0, 0.2)

func _flash_red(progress: float):
    """Efeito visual de flash vermelho ao tomar dano"""
    if sprite:
        sprite.modulate = Color.WHITE.lerp(Color.RED, sin(progress * PI * 4) * 0.5)

func die():
    """Morte visual do inimigo"""
    _update_animation("death")
    
    # Fade out após animação
    var tween = create_tween()
    tween.tween_delay(1.0)
    tween.tween_property(self, "modulate:a", 0.0, 0.5)
    tween.tween_callback(queue_free)

# ============================================================================
# GETTERS
# ============================================================================

func get_enemy_id() -> String:
    return enemy_id

func get_enemy_type() -> String:
    return enemy_type

func get_current_hp() -> int:
    return current_hp

func is_alive() -> bool:
    return current_hp > 0
