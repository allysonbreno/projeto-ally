# MAP LAYOUT TEMPLATE - PROJETO ALLY v2.9.1+
# Este template garante consistência de layout em todos os mapas
# Área cinza direita (80%-100%) sempre reservada para HUD

extends Node2D

# Configurações padrão para todos os mapas
const SHOW_BACKGROUND := true
const SHOW_PLATFORM_VISUAL := true
const GROUND_VISUAL_OFFSET := 8.0

# Layout padrão - SEMPRE manter estes valores para consistência
const HUD_RESERVED_AREA_START := 0.8  # 80% da tela = início da área cinza
const RIGHT_WALL_POSITION := 200.0    # Parede direita sempre em x=200
const LEFT_WALL_POSITION := -542.0    # Parede esquerda expandida (+30px)

# Configurações físicas padrão
const GROUND_HEIGHT: float = 30.0
const WALL_THICKNESS: float = 40.0

# Cores padrão (podem ser customizadas por mapa)
var ground_color := Color(0.20, 0.20, 0.24, 1.0)
var wall_color := Color(0.15, 0.15, 0.18, 1.0)

# Elementos básicos do mundo
var main: Node
var ground_body: StaticBody2D
var walls: Array[StaticBody2D] = []
var background: Sprite2D

func setup(main_ref: Node) -> void:
    main = main_ref
    _create_world()

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
    return Vector2(1152, 648)  # Resolução padrão

# TEMPLATE BACKGROUND - DEVE SER IMPLEMENTADO POR CADA MAPA
func _create_background(viewport_size: Vector2) -> void:
    if not SHOW_BACKGROUND:
        return
    
    # SUBSTITUIR 'your_map_bg.png' pelo arquivo específico do mapa
    var bg_texture = load("res://art/bg/your_map_bg.png") as Texture2D
    if bg_texture:
        background = Sprite2D.new()
        background.texture = bg_texture
        background.z_index = -1
        
        # ALGORITMO PADRÃO - NÃO ALTERAR
        var texture_size = bg_texture.get_size()
        var scale_x = viewport_size.x / float(texture_size.x)
        var scale_y = viewport_size.y / float(texture_size.y)
        
        # Usar menor escala para evitar background gigante
        var bg_scale = min(scale_x, scale_y) * 1.2
        background.scale = Vector2(bg_scale, bg_scale)
        
        # POSICIONAMENTO PADRÃO - Background à esquerda, HUD à direita
        var bg_width = texture_size.x * bg_scale
        background.position = Vector2(-viewport_size.x * 0.5 + bg_width * 0.5, 0)
        add_child(background)

# TEMPLATE GROUND - PODE SER CUSTOMIZADO POR MAPA
func _create_ground(viewport_size: Vector2) -> void:
    ground_body = StaticBody2D.new()
    var collision = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    
    shape.size = Vector2(viewport_size.x, GROUND_HEIGHT)
    collision.shape = shape
    ground_body.add_child(collision)
    
    # POSIÇÃO DO GROUND - Deve ser customizada por mapa específico
    # Exemplo para cidade: 265.0, para floresta: 184.0
    var ground_y = _get_map_ground_level() + (GROUND_HEIGHT * 0.5) + GROUND_VISUAL_OFFSET
    ground_body.position = Vector2(0, ground_y)
    
    # Configurar camadas de colisão padrão
    ground_body.set_collision_layer_value(2, true)  # Ground na camada 2 (ambiente)
    ground_body.set_collision_mask_value(1, true)
    ground_body.set_collision_mask_value(3, true)
    
    add_child(ground_body)

    # Visual helper for platforms
    if SHOW_PLATFORM_VISUAL:
        _add_visual_rect(ground_body, shape.size, ground_color)

# TEMPLATE WALLS - LAYOUT PADRÃO PARA TODOS OS MAPAS
func _create_walls(viewport_size: Vector2) -> void:
    # PAREDE ESQUERDA - POSIÇÃO PADRÃO (expandida para movimento)
    var left_wall = _create_wall(Vector2(WALL_THICKNESS, viewport_size.y + 200))
    left_wall.position = Vector2(LEFT_WALL_POSITION + WALL_THICKNESS * 0.5, 0)
    walls.append(left_wall)
    
    # PAREDE DIREITA - POSIÇÃO PADRÃO (reserva espaço para HUD)
    var right_wall = _create_wall(Vector2(WALL_THICKNESS, viewport_size.y + 200))
    right_wall.position = Vector2(RIGHT_WALL_POSITION, 0)
    walls.append(right_wall)
    
    # TETO - POSIÇÃO PADRÃO
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
    
    # Configurar camadas de colisão padrão
    wall.set_collision_layer_value(2, true)  # Paredes na camada 2 (ambiente)
    wall.set_collision_mask_value(1, true)
    wall.set_collision_mask_value(3, true)
    
    add_child(wall)
    
    # Visual helper for walls
    if SHOW_PLATFORM_VISUAL:
        _add_visual_rect(wall, shape.size, wall_color)
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
    poly.z_index = -2  # SEMPRE atrás do background (que está em -1)
    parent.add_child(poly)

# FUNÇÃO VIRTUAL - DEVE SER IMPLEMENTADA POR CADA MAPA
func _get_map_ground_level() -> float:
    # Sobrescrever esta função em cada mapa específico
    # Exemplos:
    # Cidade: return 265.0
    # Floresta: return 184.0
    return 184.0  # Default

# FUNÇÃO VIRTUAL - DEVE SER IMPLEMENTADA POR CADA MAPA
func get_player_spawn_position() -> Vector2:
    # Sobrescrever esta função em cada mapa específico
    # Exemplos:
    # Cidade: return Vector2(0.0, 240.0)
    # Floresta: return Vector2(-200.0, 159.0)
    return Vector2(0.0, 159.0)  # Default

# ====== DOCUMENTAÇÃO DE USO ======
# 
# Para criar um novo mapa:
# 1. Estender este template: extends "res://scripts/base_map_template.gd"
# 2. Sobrescrever _create_background() com o arquivo de background correto
# 3. Sobrescrever _get_map_ground_level() com o nível do chão do mapa
# 4. Sobrescrever get_player_spawn_position() com a posição de spawn
# 5. Opcionalmente customizar cores (ground_color, wall_color)
# 
# IMPORTANTE: NÃO alterar as constantes de layout (RIGHT_WALL_POSITION, 
# LEFT_WALL_POSITION, HUD_RESERVED_AREA_START) para manter consistência
# da interface em todos os mapas.
#