extends Node2D

var main: Node

# Elementos do mundo
var ground_body: StaticBody2D
var walls: Array[StaticBody2D] = []
var background: Sprite2D

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
    var bg_texture = load("res://art/bg/city_bg.png") as Texture2D
    if bg_texture:
        background = Sprite2D.new()
        background.texture = bg_texture
        background.z_index = -1
        
        # Calcular escala para cobrir a tela toda com margem
        var texture_size = bg_texture.get_size()
        var scale_x = viewport_size.x / float(texture_size.x)
        var scale_y = viewport_size.y / float(texture_size.y)
        var bg_scale = max(scale_x, scale_y)
        
        background.scale = Vector2(bg_scale, bg_scale)
        background.position = Vector2.ZERO
        add_child(background)

func _create_ground(viewport_size: Vector2) -> void:
    # Creating ground collision
    ground_body = StaticBody2D.new()
    var collision = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    
    shape.size = Vector2(viewport_size.x, GROUND_HEIGHT)
    collision.shape = shape
    ground_body.add_child(collision)
    
    var ground_y = (viewport_size.y * 0.5) - BOTTOM_MARGIN + (GROUND_HEIGHT * 0.5)
    ground_body.position = Vector2(0, ground_y)
    # Ground created
    
    # Configurar camadas de colisão
    ground_body.set_collision_layer_value(2, true)  # Ground na camada 2 (ambiente)
    ground_body.set_collision_mask_value(1, true)
    ground_body.set_collision_mask_value(3, true)
    # Ground collision layers configured
    
    add_child(ground_body)
    # Ground added to scene

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
    return wall

func _create_camera() -> void:
    var camera = Camera2D.new()
    camera.position = Vector2.ZERO
    add_child(camera)
    camera.call_deferred("make_current")

func get_player_spawn_position() -> Vector2:
    var viewport_size = _get_viewport_size()
    var spawn_y = (viewport_size.y * 0.5) - BOTTOM_MARGIN - 20.0
    return Vector2(0.0, spawn_y)
