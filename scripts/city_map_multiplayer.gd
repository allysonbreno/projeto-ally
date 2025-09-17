extends Node2D

var main: Node

# Elementos do mundo
var ground_body: StaticBody2D
var walls: Array[StaticBody2D] = []
var background: Sprite2D
const SHOW_BACKGROUND := true
const SHOW_PLATFORM_VISUAL := true
const GROUND_VISUAL_OFFSET := 8.0  # ajuste fino de alinhamento visual com os pés
const GROUND_COLOR := Color(0.20, 0.20, 0.24, 1.0)
const WALL_COLOR := Color(0.15, 0.15, 0.18, 1.0)

# Configurações
const GROUND_HEIGHT: float = 30.0
const WALL_THICKNESS: float = 40.0
const BOTTOM_MARGIN: float = 150.0

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
    return Vector2(1024, 768)

func _create_background(viewport_size: Vector2) -> void:
    if not SHOW_BACKGROUND:
        return
    var bg_texture = load("res://art/bg/city_bg.png") as Texture2D
    if bg_texture:
        background = Sprite2D.new()
        background.texture = bg_texture
        background.z_index = -1
        # Calcular escala para manter proporção adequada
        var texture_size = bg_texture.get_size()
        var scale_x = viewport_size.x / float(texture_size.x)  # 1152/1024 = 1.125
        var scale_y = viewport_size.y / float(texture_size.y)  # 648/1024 = 0.633
        
        # Usar a menor escala para evitar background gigante
        var bg_scale = min(scale_x, scale_y) * 1.2  # 0.633 * 1.2 = 0.76 (menor que original)
        background.scale = Vector2(bg_scale, bg_scale)
        
        # Posicionar background na esquerda para deixar espaço para HUD à direita
        var bg_width = texture_size.x * bg_scale
        background.position = Vector2(-viewport_size.x * 0.5 + bg_width * 0.5, 0)
        add_child(background)

func _create_ground(viewport_size: Vector2) -> void:
    # Creating ground collision
    ground_body = StaticBody2D.new()
    var collision = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    
    shape.size = Vector2(viewport_size.x, GROUND_HEIGHT)
    collision.shape = shape
    ground_body.add_child(collision)
    
    # Alinhar com o servidor: ground_y server-side = 265.0 (y dos pés do player no caminho de terra)
    # Para que o TOPO da plataforma seja 265, o centro do retângulo deve ser 265 + half_height
    var ground_y = 265.0 + (GROUND_HEIGHT * 0.5) + GROUND_VISUAL_OFFSET
    ground_body.position = Vector2(0, ground_y)
    # Ground created
    
    # Configurar camadas de colisão
    ground_body.set_collision_layer_value(2, true)  # Ground na camada 2 (ambiente)
    ground_body.set_collision_mask_value(1, true)
    ground_body.set_collision_mask_value(3, true)
    # Ground collision layers configured
    
    add_child(ground_body)
    # Ground added to scene

    # Visual helper for platforms
    if SHOW_PLATFORM_VISUAL:
        _add_visual_rect(ground_body, shape.size, GROUND_COLOR)

func _create_walls(viewport_size: Vector2) -> void:
    # Parede esquerda
    var left_wall = _create_wall(Vector2(WALL_THICKNESS, viewport_size.y + 200))
    left_wall.position = Vector2(-viewport_size.x * 0.5 + WALL_THICKNESS * 0.5, 0)
    walls.append(left_wall)
    
    # Parede direita - movida para mais próximo do background 
    var right_wall = _create_wall(Vector2(WALL_THICKNESS, viewport_size.y + 200))
    right_wall.position = Vector2(200, 0)  # Posição fixa mais próxima do centro
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
    poly.z_index = -2  # Atrás do background (que está em -1)
    parent.add_child(poly)

func get_player_spawn_position() -> Vector2:
    # Spawn alinhado ao servidor (Cidade: y = 240 - caminho de terra)
    return Vector2(0.0, 240.0)
