extends CanvasLayer
signal on_select_map(map_name: String)

var title_label: Label

var hp_bar: ProgressBar
var hp_value_label: Label
var xp_bar: ProgressBar
var xp_value_label: Label

var map_button: Button
var status_button: Button
var inventory_button: Button
var auto_attack_checkbox: CheckBox
var popup_menu: PopupMenu
var status_dialog: AcceptDialog
var inventory_window: Window
var dialog: AcceptDialog

# Interface de distribuição de pontos
var points_window: Window
var strength_label: Label
var defense_label: Label
var intelligence_label: Label
var vitality_label: Label
var available_points_label: Label
var strength_button: Button
var defense_button: Button
var intelligence_button: Button
var vitality_button: Button

var player_ref: Player

func _init() -> void:
    layer = 10

func _ready() -> void:
    # ===== Barra do topo =====
    var top: HBoxContainer = HBoxContainer.new()
    top.anchor_left = 0; top.anchor_top = 0
    top.anchor_right = 1; top.anchor_bottom = 0
    top.offset_left = 16; top.offset_top = 16; top.offset_right = -16
    top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_child(top)

    # sem título à esquerda
    var left_spacer := Control.new()
    left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(left_spacer)

    # Título central (maior)
    title_label = Label.new()
    title_label.text = "Cidade"
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_label.add_theme_font_size_override("font_size", 28)
    top.add_child(title_label)

    # Lado direito: barras + botão Mapas
    var right_box := HBoxContainer.new()
    right_box.alignment = BoxContainer.ALIGNMENT_END
    top.add_child(right_box)

    var bars := VBoxContainer.new()
    right_box.add_child(bars)

    # ---- Linha HP ----
    var hp_row := HBoxContainer.new()
    hp_row.custom_minimum_size = Vector2(300, 24)
    bars.add_child(hp_row)

    var hp_text := Label.new()
    hp_text.text = "HP"
    hp_text.add_theme_font_size_override("font_size", 16)
    hp_text.custom_minimum_size = Vector2(32, 0)
    hp_row.add_child(hp_text)

    hp_bar = ProgressBar.new()
    hp_bar.min_value = 0
    hp_bar.max_value = 100
    hp_bar.value = 100
    hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hp_bar.custom_minimum_size = Vector2(240, 20)
    # estilo HP (vermelho)
    var hp_bg := StyleBoxFlat.new()
    hp_bg.bg_color = Color(0.12, 0.12, 0.12)
    hp_bg.corner_radius_top_left = 6
    hp_bg.corner_radius_top_right = 6
    hp_bg.corner_radius_bottom_left = 6
    hp_bg.corner_radius_bottom_right = 6
    var hp_fill := StyleBoxFlat.new()
    hp_fill.bg_color = Color(0.85, 0.18, 0.18)
    hp_fill.corner_radius_top_left = 6
    hp_fill.corner_radius_top_right = 6
    hp_fill.corner_radius_bottom_left = 6
    hp_fill.corner_radius_bottom_right = 6
    hp_bar.add_theme_stylebox_override("background", hp_bg)
    hp_bar.add_theme_stylebox_override("fill", hp_fill)
    hp_row.add_child(hp_bar)

    # valor "100/100"
    hp_value_label = Label.new()
    hp_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hp_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    hp_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hp_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hp_row.add_child(hp_value_label)
    _update_hp_text(100, 100)

    # ---- Linha XP ----
    var xp_row := HBoxContainer.new()
    xp_row.custom_minimum_size = Vector2(300, 20)
    bars.add_child(xp_row)

    var xp_text := Label.new()
    xp_text.text = "XP"
    xp_text.add_theme_font_size_override("font_size", 16)
    xp_text.custom_minimum_size = Vector2(32, 0)
    xp_row.add_child(xp_text)

    xp_bar = ProgressBar.new()
    xp_bar.min_value = 0
    xp_bar.max_value = 100
    xp_bar.value = 0
    xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    xp_bar.custom_minimum_size = Vector2(240, 16)
    # estilo XP (azul)
    var xp_bg := StyleBoxFlat.new()
    xp_bg.bg_color = Color(0.12, 0.12, 0.12)
    xp_bg.corner_radius_top_left = 6
    xp_bg.corner_radius_top_right = 6
    xp_bg.corner_radius_bottom_left = 6
    xp_bg.corner_radius_bottom_right = 6
    var xp_fill := StyleBoxFlat.new()
    xp_fill.bg_color = Color(0.2, 0.5, 1.0)
    xp_fill.corner_radius_top_left = 6
    xp_fill.corner_radius_top_right = 6
    xp_fill.corner_radius_bottom_left = 6
    xp_fill.corner_radius_bottom_right = 6
    xp_bar.add_theme_stylebox_override("background", xp_bg)
    xp_bar.add_theme_stylebox_override("fill", xp_fill)
    xp_row.add_child(xp_bar)

    xp_value_label = Label.new()
    xp_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    xp_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    xp_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    xp_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    xp_row.add_child(xp_value_label)
    _update_xp_text(0, 100)

    # Auto Attack checkbox
    auto_attack_checkbox = CheckBox.new()
    auto_attack_checkbox.text = "Auto Attack"
    auto_attack_checkbox.focus_mode = Control.FOCUS_NONE
    auto_attack_checkbox.toggled.connect(_on_auto_attack_toggled)
    bars.add_child(auto_attack_checkbox)

    # Botões container
    var buttons_container := HBoxContainer.new()
    right_box.add_child(buttons_container)
    
    # Botão Status
    status_button = Button.new()
    status_button.text = "Status"
    status_button.focus_mode = Control.FOCUS_NONE
    status_button.pressed.connect(_open_status_dialog)
    buttons_container.add_child(status_button)
    
    # Botão Inventário
    inventory_button = Button.new()
    inventory_button.text = "Inventário"
    inventory_button.focus_mode = Control.FOCUS_NONE
    inventory_button.pressed.connect(_open_inventory_window)
    buttons_container.add_child(inventory_button)
    
    # Botão Mapas
    map_button = Button.new()
    map_button.text = "Mapas"
    map_button.focus_mode = Control.FOCUS_NONE
    map_button.pressed.connect(_open_map_menu)
    buttons_container.add_child(map_button)

    # Popup do menu
    popup_menu = PopupMenu.new()
    add_child(popup_menu)
    popup_menu.add_item("Floresta")
    popup_menu.id_pressed.connect(func(id):
        var selected_map := popup_menu.get_item_text(id)
        on_select_map.emit(selected_map)
    )

    # Dialog
    dialog = AcceptDialog.new()
    dialog.title = "Aviso"
    add_child(dialog)
    
    # Status Dialog
    status_dialog = AcceptDialog.new()
    status_dialog.title = "Status do Personagem"
    add_child(status_dialog)
    
    # Interface de distribuição de pontos
    _create_points_distribution_window()
    
    # Interface de inventário
    _create_inventory_window()

func _open_map_menu() -> void:
    popup_menu.position = map_button.get_global_position() + Vector2(0, map_button.size.y)
    popup_menu.popup()

func _open_status_dialog() -> void:
    var main_node = get_parent()
    if main_node and main_node.has_method("get_player_stats"):
        var stats = main_node.get_player_stats()
        
        # Se tem pontos disponíveis, abre a interface de distribuição
        if stats.available_points > 0:
            _open_points_distribution_window()
        else:
            # Senão, mostra apenas o status
            var status_text = "=== STATUS DO PERSONAGEM ===\n\n"
            status_text += "Nível: %d\n" % stats.level
            status_text += "HP: %d/%d\n" % [stats.hp, stats.hp_max]
            status_text += "XP: %d/%d\n\n" % [stats.xp, stats.xp_max]
            status_text += "=== ATRIBUTOS ===\n"
            status_text += "Força: %d (+%d dano)\n" % [stats.strength, stats.strength]
            status_text += "Defesa: %d (-%d dano recebido)\n" % [stats.defense, stats.defense]
            status_text += "Inteligência: %d\n" % stats.intelligence
            status_text += "Vitalidade: %d (+%d HP máximo)" % [stats.vitality, stats.vitality * 20]
            
            status_dialog.dialog_text = status_text
            status_dialog.popup_centered()
    else:
        status_dialog.dialog_text = "Erro ao carregar status"
        status_dialog.popup_centered()

# ================== API pública ==================
func set_player(p: Player) -> void:
    player_ref = p

func update_health(current: int, maxv: int) -> void:
    hp_bar.max_value = maxv
    hp_bar.value = current
    _update_hp_text(current, maxv)

func update_xp(current: int, maxv: int) -> void:
    xp_bar.max_value = maxv
    xp_bar.value = current
    _update_xp_text(current, maxv)

func set_map_title(t: String) -> void:
    title_label.text = t

# Mantido por compatibilidade; não faz nada agora.
func set_subtitle(_t: String) -> void:
    pass

func show_popup(texto: String) -> void:
    dialog.dialog_text = texto
    dialog.popup_centered()

# Dano flutuante (em tela)
func show_damage_popup_at_world(world_pos: Vector2, txt: String, color: Color) -> void:
    var cam: Camera2D = get_viewport().get_camera_2d()
    var screen_pos: Vector2 = world_pos
    if cam != null:
        var vp: Vector2 = get_viewport().get_visible_rect().size
        screen_pos = (world_pos - cam.global_position) * cam.zoom + vp * 0.5

    var lbl: Label = Label.new()
    lbl.text = txt
    lbl.modulate = color
    lbl.position = screen_pos
    add_child(lbl)

    var t: Tween = create_tween()
    t.tween_property(lbl, "position", screen_pos + Vector2(0, -28), 0.6)
    t.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6)
    await t.finished
    lbl.queue_free()

# ================== Interface de Pontos ==================
func _create_points_distribution_window() -> void:
    points_window = Window.new()
    points_window.title = "Distribuir Pontos de Atributo"
    points_window.size = Vector2i(400, 350)
    points_window.visible = false
    points_window.close_requested.connect(func(): points_window.visible = false)
    add_child(points_window)
    
    var vbox := VBoxContainer.new()
    points_window.add_child(vbox)
    vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    vbox.add_theme_constant_override("separation", 10)
    
    # Título
    var title := Label.new()
    title.text = "Distribuir Pontos de Atributo"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 18)
    vbox.add_child(title)
    
    # Pontos disponíveis
    available_points_label = Label.new()
    available_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    available_points_label.add_theme_font_size_override("font_size", 14)
    vbox.add_child(available_points_label)
    
    # Separador
    var separator := HSeparator.new()
    vbox.add_child(separator)
    
    # Força
    var strength_container := HBoxContainer.new()
    vbox.add_child(strength_container)
    strength_label = Label.new()
    strength_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    strength_container.add_child(strength_label)
    strength_button = Button.new()
    strength_button.text = "+"
    strength_button.custom_minimum_size = Vector2(30, 30)
    strength_button.pressed.connect(_add_strength_point)
    strength_container.add_child(strength_button)
    
    # Defesa
    var defense_container := HBoxContainer.new()
    vbox.add_child(defense_container)
    defense_label = Label.new()
    defense_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    defense_container.add_child(defense_label)
    defense_button = Button.new()
    defense_button.text = "+"
    defense_button.custom_minimum_size = Vector2(30, 30)
    defense_button.pressed.connect(_add_defense_point)
    defense_container.add_child(defense_button)
    
    # Inteligência
    var intelligence_container := HBoxContainer.new()
    vbox.add_child(intelligence_container)
    intelligence_label = Label.new()
    intelligence_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    intelligence_container.add_child(intelligence_label)
    intelligence_button = Button.new()
    intelligence_button.text = "+"
    intelligence_button.custom_minimum_size = Vector2(30, 30)
    intelligence_button.pressed.connect(_add_intelligence_point)
    intelligence_container.add_child(intelligence_button)
    
    # Vitalidade
    var vitality_container := HBoxContainer.new()
    vbox.add_child(vitality_container)
    vitality_label = Label.new()
    vitality_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vitality_container.add_child(vitality_label)
    vitality_button = Button.new()
    vitality_button.text = "+"
    vitality_button.custom_minimum_size = Vector2(30, 30)
    vitality_button.pressed.connect(_add_vitality_point)
    vitality_container.add_child(vitality_button)
    
    # Botão Fechar
    var close_button := Button.new()
    close_button.text = "Fechar"
    close_button.pressed.connect(func(): points_window.visible = false)
    vbox.add_child(close_button)

func _open_points_distribution_window() -> void:
    _update_points_display()
    points_window.popup_centered()

func _update_points_display() -> void:
    var main_node = get_parent()
    if main_node and main_node.has_method("get_player_stats"):
        var stats = main_node.get_player_stats()
        
        available_points_label.text = "Pontos Disponíveis: %d" % stats.available_points
        strength_label.text = "Força: %d (+%d dano)" % [stats.strength, stats.strength]
        defense_label.text = "Defesa: %d (-%d dano recebido)" % [stats.defense, stats.defense]
        intelligence_label.text = "Inteligência: %d" % stats.intelligence
        vitality_label.text = "Vitalidade: %d (+%d HP máximo)" % [stats.vitality, stats.vitality * 20]
        
        # Habilita/desabilita botões baseado em pontos disponíveis
        var has_points = stats.available_points > 0
        strength_button.disabled = not has_points
        defense_button.disabled = not has_points
        intelligence_button.disabled = not has_points
        vitality_button.disabled = not has_points

# ================== Funções de Distribuição ==================
func _add_strength_point() -> void:
    var main_node = get_parent()
    if main_node and main_node.has_method("add_attribute_point"):
        main_node.add_attribute_point("strength")
        _update_points_display()

func _add_defense_point() -> void:
    var main_node = get_parent()
    if main_node and main_node.has_method("add_attribute_point"):
        main_node.add_attribute_point("defense")
        _update_points_display()

func _add_intelligence_point() -> void:
    var main_node = get_parent()
    if main_node and main_node.has_method("add_attribute_point"):
        main_node.add_attribute_point("intelligence")
        _update_points_display()

func _add_vitality_point() -> void:
    var main_node = get_parent()
    if main_node and main_node.has_method("add_attribute_point"):
        main_node.add_attribute_point("vitality")
        _update_points_display()

# ================== helpers ==================
func _update_hp_text(cur: int, maxv: int) -> void:
    hp_value_label.text = str(cur, "/", maxv)

func _update_xp_text(cur: int, maxv: int) -> void:
    xp_value_label.text = str(cur, "/", maxv)

func _on_auto_attack_toggled(button_pressed: bool) -> void:
    var main_node = get_parent()
    if main_node and main_node.has_method("set_auto_attack"):
        main_node.set_auto_attack(button_pressed)

# ================== Interface de Inventário ==================
func _create_inventory_window() -> void:
    inventory_window = Window.new()
    inventory_window.title = "Inventário"
    inventory_window.size = Vector2i(350, 500)
    inventory_window.visible = false
    inventory_window.close_requested.connect(func(): inventory_window.visible = false)
    add_child(inventory_window)
    
    var vbox := VBoxContainer.new()
    inventory_window.add_child(vbox)
    vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    vbox.add_theme_constant_override("separation", 10)
    
    # Título
    var title := Label.new()
    title.text = "Inventário"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 18)
    vbox.add_child(title)
    
    # Slot de equipamento (Arma)
    var weapon_label := Label.new()
    weapon_label.text = "Arma Equipada:"
    weapon_label.add_theme_font_size_override("font_size", 14)
    vbox.add_child(weapon_label)
    
    var weapon_container := HBoxContainer.new()
    vbox.add_child(weapon_container)
    
    var weapon_slot := Button.new()
    weapon_slot.custom_minimum_size = Vector2(64, 64)
    weapon_slot.text = "Vazio"
    weapon_slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    weapon_slot.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
    weapon_slot.expand_icon = true
    weapon_slot.pressed.connect(_unequip_weapon)
    weapon_container.add_child(weapon_slot)
    
    var weapon_info := Label.new()
    weapon_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    weapon_info.text = "Nenhuma arma equipada"
    weapon_container.add_child(weapon_info)
    
    # Separador
    var separator := HSeparator.new()
    vbox.add_child(separator)
    
    # Slots do inventário
    var inv_label := Label.new()
    inv_label.text = "Inventário (5 slots):"
    inv_label.add_theme_font_size_override("font_size", 14)
    vbox.add_child(inv_label)
    
    var grid := GridContainer.new()
    grid.columns = 5
    grid.add_theme_constant_override("h_separation", 5)
    vbox.add_child(grid)
    
    # Criar 5 slots
    for i in range(5):
        var slot := Button.new()
        slot.custom_minimum_size = Vector2(60, 60)
        slot.text = str(i + 1)
        slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
        slot.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
        slot.expand_icon = true
        var slot_index = i
        slot.pressed.connect(func(): _equip_item_from_slot(slot_index))
        grid.add_child(slot)
    
    # Botão Fechar
    var close_button := Button.new()
    close_button.text = "Fechar"
    close_button.pressed.connect(func(): inventory_window.visible = false)
    vbox.add_child(close_button)

func _open_inventory_window() -> void:
    _update_inventory_display()
    inventory_window.popup_centered()

func _update_inventory_display() -> void:
    var main_node = get_parent()
    if main_node and main_node.has_method("get_inventory_data"):
        var inventory_data = main_node.get_inventory_data()
        
        # Obter referências aos nós corretamente
        var vbox = inventory_window.get_child(0)  # VBoxContainer principal
        var weapon_container: HBoxContainer = null
        var grid: GridContainer = null
        
        # Procurar pelos nós na estrutura
        for child in vbox.get_children():
            if child is HBoxContainer:
                weapon_container = child
            elif child is GridContainer:
                grid = child
        
        if weapon_container:
            var weapon_slot = weapon_container.get_child(0)  # Button
            var weapon_info = weapon_container.get_child(1)  # Label
            
            if inventory_data.equipped_weapon.is_empty():
                weapon_slot.text = "Vazio"
                weapon_slot.icon = null
                weapon_info.text = "Nenhuma arma equipada"
            else:
                var weapon = inventory_data.equipped_weapon
                weapon_slot.text = ""  # Remove texto quando tem arma
                weapon_info.text = "%s\n+%d Dano" % [weapon.get("name", ""), weapon.get("damage", 0)]
                
                # Carregar ícone da arma
                var icon_path = "res://art/items/" + weapon.get("icon", "default.png")
                if ResourceLoader.exists(icon_path):
                    var icon_texture = load(icon_path)
                    weapon_slot.icon = icon_texture
                else:
                    weapon_slot.text = weapon.get("name", "Arma")  # Fallback para texto
        
        # Atualizar slots do inventário
        if grid:
            for i in range(5):
                var slot = grid.get_child(i)
                var item = inventory_data.slots[i]
                
                if item.is_empty():
                    slot.text = str(i + 1)
                    slot.icon = null
                else:
                    slot.text = ""  # Remove texto quando tem item
                    
                    # Carregar ícone do item
                    var icon_path = "res://art/items/" + item.get("icon", "default.png")
                    if ResourceLoader.exists(icon_path):
                        var icon_texture = load(icon_path)
                        slot.icon = icon_texture
                    else:
                        slot.text = item.get("name", "Item")  # Fallback para texto

func _equip_item_from_slot(slot_index: int) -> void:
    var main_node = get_parent()
    if main_node and main_node.has_method("equip_weapon"):
        main_node.equip_weapon(slot_index)
        _update_inventory_display()

func _unequip_weapon() -> void:
    var main_node = get_parent()
    if main_node and main_node.has_method("unequip_weapon"):
        main_node.unequip_weapon()
        _update_inventory_display()
