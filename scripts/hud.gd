extends CanvasLayer
signal on_select_map(map_name: String)

var title_label: Label
var vida_bar: ProgressBar
var xp_bar: ProgressBar
var status_button: Button
var inventory_button: Button
var maps_button: Button
var auto_attack_button: Button
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

var player_ref: CharacterBody2D

func _init() -> void:
    layer = 10

func _ready() -> void:
    _create_hud()

func _create_hud() -> void:
    # Criar container principal corretamente posicionado na área cinza
    var margin := MarginContainer.new()
    margin.anchor_left = 0.8  # Começa em 80% da tela (área cinza direita)
    margin.anchor_top = 0
    margin.anchor_right = 1
    margin.anchor_bottom = 1
    margin.add_theme_constant_override("margin_left", 5)
    margin.add_theme_constant_override("margin_right", 5)
    margin.add_theme_constant_override("margin_top", 5)
    margin.add_theme_constant_override("margin_bottom", 5)
    
    # Criar painel principal
    var right_panel := VBoxContainer.new()
    right_panel.add_theme_constant_override("separation", 3)
    margin.add_child(right_panel)
    
    # === SEÇÃO 1: TÍTULO ===
    title_label = Label.new()
    title_label.text = "Cidade - Multiplayer"
    title_label.add_theme_font_size_override("font_size", 12)
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    right_panel.add_child(title_label)
    
    # === SEÇÃO 2: STATUS BARS (ocupando mais espaço) ===
    var status_section := VBoxContainer.new()
    status_section.add_theme_constant_override("separation", 3)
    status_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
    
    # Vida
    var vida_container := VBoxContainer.new()
    var vida_label := Label.new()
    vida_label.text = "Vida:"
    vida_label.add_theme_font_size_override("font_size", 10)
    vida_container.add_child(vida_label)
    
    vida_bar = ProgressBar.new()
    vida_bar.value = 95
    vida_bar.max_value = 100
    vida_bar.show_percentage = false
    vida_bar.custom_minimum_size.y = 20  # Barras maiores
    # Estilo HP (vermelho)
    var hp_bg := StyleBoxFlat.new()
    hp_bg.bg_color = Color(0.12, 0.12, 0.12)
    hp_bg.corner_radius_top_left = 4
    hp_bg.corner_radius_top_right = 4
    hp_bg.corner_radius_bottom_left = 4
    hp_bg.corner_radius_bottom_right = 4
    var hp_fill := StyleBoxFlat.new()
    hp_fill.bg_color = Color(0.85, 0.18, 0.18)
    hp_fill.corner_radius_top_left = 4
    hp_fill.corner_radius_top_right = 4
    hp_fill.corner_radius_bottom_left = 4
    hp_fill.corner_radius_bottom_right = 4
    vida_bar.add_theme_stylebox_override("background", hp_bg)
    vida_bar.add_theme_stylebox_override("fill", hp_fill)
    vida_container.add_child(vida_bar)
    
    var vida_text := Label.new()
    vida_text.text = "95/100"
    vida_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vida_text.add_theme_font_size_override("font_size", 9)
    vida_container.add_child(vida_text)
    
    status_section.add_child(vida_container)
    
    # Experiência
    var xp_container := VBoxContainer.new()
    var xp_label := Label.new()
    xp_label.text = "Experiência:"
    xp_label.add_theme_font_size_override("font_size", 10)
    xp_container.add_child(xp_label)
    
    xp_bar = ProgressBar.new()
    xp_bar.value = 90
    xp_bar.max_value = 100
    xp_bar.show_percentage = false
    xp_bar.custom_minimum_size.y = 20  # Barras maiores
    # Estilo XP (azul)
    var xp_bg := StyleBoxFlat.new()
    xp_bg.bg_color = Color(0.12, 0.12, 0.12)
    xp_bg.corner_radius_top_left = 4
    xp_bg.corner_radius_top_right = 4
    xp_bg.corner_radius_bottom_left = 4
    xp_bg.corner_radius_bottom_right = 4
    var xp_fill := StyleBoxFlat.new()
    xp_fill.bg_color = Color(0.2, 0.5, 1.0)
    xp_fill.corner_radius_top_left = 4
    xp_fill.corner_radius_top_right = 4
    xp_fill.corner_radius_bottom_left = 4
    xp_fill.corner_radius_bottom_right = 4
    xp_bar.add_theme_stylebox_override("background", xp_bg)
    xp_bar.add_theme_stylebox_override("fill", xp_fill)
    xp_container.add_child(xp_bar)
    
    var xp_text := Label.new()
    xp_text.text = "1644/1826"
    xp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    xp_text.add_theme_font_size_override("font_size", 9)
    xp_container.add_child(xp_text)
    
    status_section.add_child(xp_container)
    right_panel.add_child(status_section)
    
    # === SEÇÃO 3: CONFIGURAÇÕES ===
    var config_section := VBoxContainer.new()
    config_section.add_theme_constant_override("separation", 3)
    
    var config_label := Label.new()
    config_label.text = "Configurações:"
    config_label.add_theme_font_size_override("font_size", 10)
    config_section.add_child(config_label)
    
    auto_attack_button = Button.new()
    auto_attack_button.text = "Auto Attack"
    auto_attack_button.custom_minimum_size.y = 28  # Botões maiores
    auto_attack_button.toggle_mode = true
    auto_attack_button.pressed.connect(_on_auto_attack_pressed)
    config_section.add_child(auto_attack_button)
    
    right_panel.add_child(config_section)
    
    # === SEÇÃO 4: MENUS COM ÍCONES ===
    var menu_section := VBoxContainer.new()
    menu_section.add_theme_constant_override("separation", 5)
    menu_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
    
    var menu_label := Label.new()
    menu_label.text = "Menus:"
    menu_label.add_theme_font_size_override("font_size", 10)
    menu_section.add_child(menu_label)
    
    # Grid horizontal para os botões com ícones (3 colunas para ocupar toda largura)
    var buttons_grid := GridContainer.new()
    buttons_grid.columns = 3
    buttons_grid.add_theme_constant_override("h_separation", 3)
    buttons_grid.add_theme_constant_override("v_separation", 3)
    
    # Status button com ícone
    var status_container := VBoxContainer.new()
    status_container.alignment = BoxContainer.ALIGNMENT_CENTER
    
    status_button = Button.new()
    status_button.custom_minimum_size = Vector2(50, 50)
    status_button.icon = _create_status_icon()
    status_button.pressed.connect(_on_status_pressed)
    status_container.add_child(status_button)
    
    var status_label := Label.new()
    status_label.text = "Status"
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.add_theme_font_size_override("font_size", 8)
    status_container.add_child(status_label)
    
    buttons_grid.add_child(status_container)
    
    # Inventory button com ícone
    var inventory_container := VBoxContainer.new()
    inventory_container.alignment = BoxContainer.ALIGNMENT_CENTER
    
    inventory_button = Button.new()
    inventory_button.custom_minimum_size = Vector2(50, 50)
    inventory_button.icon = _create_inventory_icon()
    inventory_button.pressed.connect(_on_inventory_pressed)
    inventory_container.add_child(inventory_button)
    
    var inventory_label := Label.new()
    inventory_label.text = "Inventário"
    inventory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    inventory_label.add_theme_font_size_override("font_size", 8)
    inventory_container.add_child(inventory_label)
    
    buttons_grid.add_child(inventory_container)
    
    # Maps button com ícone
    var maps_container := VBoxContainer.new()
    maps_container.alignment = BoxContainer.ALIGNMENT_CENTER
    
    maps_button = Button.new()
    maps_button.custom_minimum_size = Vector2(50, 50)
    maps_button.icon = _create_maps_icon()
    maps_button.pressed.connect(_on_maps_pressed)
    maps_container.add_child(maps_button)
    
    var maps_label := Label.new()
    maps_label.text = "Mapas"
    maps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    maps_label.add_theme_font_size_override("font_size", 8)
    maps_container.add_child(maps_label)
    
    buttons_grid.add_child(maps_container)
    
    menu_section.add_child(buttons_grid)
    right_panel.add_child(menu_section)
    
    add_child(margin)
    
    # Criar elementos complementares
    _create_popup_menu()
    _create_dialogs()
    _create_points_distribution_window()
    _create_inventory_window()

# ================== CRIAÇÃO DE ÍCONES ==================
func _create_status_icon() -> ImageTexture:
    # Ícone de braço forte (flexão)
    var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
    img.fill(Color.TRANSPARENT)
    
    # Braço superior (horizontal)
    for x in range(8, 24):
        for y in range(10, 14):
            img.set_pixel(x, y, Color.SADDLE_BROWN)
    
    # Antebraço (vertical)
    for x in range(18, 22):
        for y in range(14, 26):
            img.set_pixel(x, y, Color.SADDLE_BROWN)
    
    # Músculo (círculo)
    for x in range(12, 20):
        for y in range(8, 16):
            var dx = x - 16
            var dy = y - 12
            if dx*dx + dy*dy <= 20:
                img.set_pixel(x, y, Color.PERU)
    
    # Punho
    for x in range(17, 23):
        for y in range(24, 28):
            img.set_pixel(x, y, Color.SADDLE_BROWN)
    
    var texture := ImageTexture.new()
    texture.set_image(img)
    return texture

func _create_inventory_icon() -> ImageTexture:
    # Ícone de bolsa/mochila
    var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
    img.fill(Color.TRANSPARENT)
    
    # Corpo da bolsa
    for x in range(6, 26):
        for y in range(8, 26):
            img.set_pixel(x, y, Color.SADDLE_BROWN)
    
    # Alça
    for x in range(10, 22):
        for y in range(4, 8):
            img.set_pixel(x, y, Color.DIM_GRAY)
    
    # Alça lateral esquerda
    for x in range(8, 10):
        for y in range(6, 18):
            img.set_pixel(x, y, Color.DIM_GRAY)
    
    # Alça lateral direita
    for x in range(22, 24):
        for y in range(6, 18):
            img.set_pixel(x, y, Color.DIM_GRAY)
    
    # Fecho
    for x in range(14, 18):
        for y in range(12, 16):
            img.set_pixel(x, y, Color.GOLD)
    
    # Bolsos laterais
    for x in range(4, 8):
        for y in range(14, 22):
            img.set_pixel(x, y, Color.BROWN)
    
    for x in range(24, 28):
        for y in range(14, 22):
            img.set_pixel(x, y, Color.BROWN)
    
    var texture := ImageTexture.new()
    texture.set_image(img)
    return texture

func _create_maps_icon() -> ImageTexture:
    # Ícone de mapa
    var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
    img.fill(Color.TRANSPARENT)
    
    # Papel do mapa
    for x in range(4, 28):
        for y in range(6, 26):
            img.set_pixel(x, y, Color.BEIGE)
    
    # Borda do mapa
    for x in range(4, 28):
        img.set_pixel(x, 6, Color.SADDLE_BROWN)
        img.set_pixel(x, 25, Color.SADDLE_BROWN)
    for y in range(6, 26):
        img.set_pixel(4, y, Color.SADDLE_BROWN)
        img.set_pixel(27, y, Color.SADDLE_BROWN)
    
    # Linhas do mapa (rios/estradas)
    for x in range(8, 24):
        img.set_pixel(x, 12, Color.BLUE)
        img.set_pixel(x, 18, Color.BROWN)
    
    for y in range(10, 22):
        img.set_pixel(16, y, Color.FOREST_GREEN)
    
    # Montanhas (triângulos)
    img.set_pixel(10, 16, Color.GRAY)
    img.set_pixel(9, 17, Color.GRAY)
    img.set_pixel(10, 17, Color.GRAY)
    img.set_pixel(11, 17, Color.GRAY)
    
    img.set_pixel(22, 14, Color.GRAY)
    img.set_pixel(21, 15, Color.GRAY)
    img.set_pixel(22, 15, Color.GRAY)
    img.set_pixel(23, 15, Color.GRAY)
    
    # X marcando local
    for i in range(5):
        img.set_pixel(14 + i, 20 + i, Color.RED)
        img.set_pixel(18 - i, 20 + i, Color.RED)
    
    var texture := ImageTexture.new()
    texture.set_image(img)
    return texture

# ================== EVENTOS DOS BOTÕES ==================
func _on_auto_attack_pressed() -> void:
    var main_node = get_parent()
    if main_node and main_node.has_method("set_auto_attack"):
        main_node.set_auto_attack(auto_attack_button.button_pressed)

func _on_status_pressed() -> void:
    _open_status_dialog()

func _on_inventory_pressed() -> void:
    _open_inventory_window()

func _on_maps_pressed() -> void:
    _open_map_menu()

# ================== CRIAÇÃO DE ELEMENTOS COMPLEMENTARES ==================
func _create_popup_menu() -> void:
    popup_menu = PopupMenu.new()
    add_child(popup_menu)
    popup_menu.add_item("Floresta")
    popup_menu.id_pressed.connect(func(id):
        var selected_map := popup_menu.get_item_text(id)
        on_select_map.emit(selected_map)
    )

func _create_dialogs() -> void:
    dialog = AcceptDialog.new()
    dialog.title = "Aviso"
    add_child(dialog)
    
    status_dialog = AcceptDialog.new()
    status_dialog.title = "Status do Personagem"
    add_child(status_dialog)

func _open_map_menu() -> void:
    popup_menu.position = maps_button.get_global_position() + Vector2(0, maps_button.size.y)
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
func set_player(p: CharacterBody2D) -> void:
    player_ref = p

func update_health(current: int, maxv: int) -> void:
    if vida_bar == null:
        print("⚠️ vida_bar é null em update_health(), não atualizando")
        return
    vida_bar.max_value = maxv
    vida_bar.value = current
    _update_hp_text(current, maxv)

func update_xp(current: int, maxv: int) -> void:
    if xp_bar == null:
        print("⚠️ xp_bar é null em update_xp(), não atualizando")
        return
    xp_bar.max_value = maxv
    xp_bar.value = current
    _update_xp_text(current, maxv)

func set_map_title(t: String) -> void:
    if title_label == null:
        print("⚠️ title_label é null em set_map_title(), não atualizando")
        return
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
    # Atualizar texto diretamente na barra de vida
    var vida_text_label = vida_bar.get_parent().get_child(2)  # Label com texto
    if vida_text_label:
        vida_text_label.text = str(cur, "/", maxv)

func _update_xp_text(cur: int, maxv: int) -> void:
    # Atualizar texto diretamente na barra de XP
    var xp_text_label = xp_bar.get_parent().get_child(2)  # Label com texto
    if xp_text_label:
        xp_text_label.text = str(cur, "/", maxv)

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
