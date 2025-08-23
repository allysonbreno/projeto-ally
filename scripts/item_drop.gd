extends Area2D
class_name ItemDrop

var item_data: Dictionary = {}
var sprite: Sprite2D
var label: Label

func _ready() -> void:
    # Usar call_deferred para configurar colisão
    call_deferred("_setup_collision")
    
    # Criar sprite
    sprite = Sprite2D.new()
    sprite.centered = true
    add_child(sprite)
    
    # Criar label com nome do item
    label = Label.new()
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.position = Vector2(-30, -40)  # Acima do sprite
    label.size = Vector2(60, 20)
    add_child(label)
    
    # Conectar sinal de entrada do player
    body_entered.connect(_on_player_nearby)
    body_exited.connect(_on_player_left)

func _setup_collision() -> void:
    # Configurar colisão
    set_collision_layer_value(4, true)  # Layer específica para itens
    set_collision_mask_value(1, true)   # Colide com player
    
    # Criar CollisionShape2D para detectar player
    var collision_shape = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    shape.size = Vector2(32, 32)
    collision_shape.shape = shape
    add_child(collision_shape)

func setup_item(item: Dictionary) -> void:
    item_data = item
    
    # Garantir que sprite e label existem
    if not sprite:
        sprite = Sprite2D.new()
        sprite.centered = true
        add_child(sprite)
    
    if not label:
        label = Label.new()
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.position = Vector2(-30, -40)
        label.size = Vector2(60, 20)
        add_child(label)
    
    # Carregar sprite do item
    var icon_path = "res://art/items/" + item.get("icon", "default.png")
    
    if ResourceLoader.exists(icon_path):
        var texture = load(icon_path)
        if texture:
            sprite.texture = texture
            sprite.scale = Vector2(0.6, 0.6)  # Sprite menor no chão
    
    # Configurar label
    label.text = item.get("name", "Item")
    label.visible = false

var player_nearby: bool = false

func _on_player_nearby(body: Node) -> void:
    if body is Player:
        player_nearby = true
        label.visible = true
        # Poderia adicionar efeito visual aqui

func _on_player_left(body: Node) -> void:
    if body is Player:
        player_nearby = false
        label.visible = false

func _input(event: InputEvent) -> void:
    if player_nearby and event.is_action_pressed("ui_accept"):  # Enter
        _pickup_item()

func _pickup_item() -> void:
    # Encontra o main node
    var main_node = get_tree().get_first_node_in_group("main")
    if not main_node:
        main_node = get_node("/root/Main")
    
    if main_node and main_node.has_method("add_item_to_inventory"):
        if main_node.add_item_to_inventory(item_data):
            # Item adicionado com sucesso
            if main_node.has_method("show_damage_popup_at_world"):
                main_node.show_damage_popup_at_world(global_position, "+" + item_data.get("name", "Item"), Color(0, 1, 0, 1))
            queue_free()
        else:
            # Inventário cheio
            if main_node.has_method("show_damage_popup_at_world"):
                main_node.show_damage_popup_at_world(global_position, "Inventário Cheio!", Color(1, 0, 0, 1))
