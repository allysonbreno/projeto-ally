extends CanvasLayer
signal on_select_map(map_name: String)

var title_label: Label
var vida_bar: ProgressBar
var xp_bar: ProgressBar
var status_button: Button
var inventory_button: Button
var maps_button: Button
var auto_attack_button: CheckBox
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
    # === FUNDO LARANJA SÓLIDO (#FF7F00) ===
    var background_panel := Panel.new()
    background_panel.anchor_left = 0.68  # Ajustado para não passar da borda
    background_panel.anchor_top = 0
    background_panel.anchor_right = 1
    background_panel.anchor_bottom = 1
    
    # Estilo do fundo laranja pixel art
    var bg_style := StyleBoxFlat.new()
    bg_style.bg_color = Color("#FF7F00")  # Laranja sólido
    bg_style.corner_radius_top_left = 0
    bg_style.corner_radius_top_right = 0
    bg_style.corner_radius_bottom_left = 0
    bg_style.corner_radius_bottom_right = 0
    bg_style.border_width_left = 2
    bg_style.border_width_right = 2
    bg_style.border_width_top = 2
    bg_style.border_width_bottom = 2
    bg_style.border_color = Color("#CC5500")  # Borda mais escura
    background_panel.add_theme_stylebox_override("panel", bg_style)
    add_child(background_panel)
    
    # Container principal com margem para pixel art
    var margin := MarginContainer.new()
    margin.anchor_left = 0.68  # Ajustado para não passar da borda
    margin.anchor_top = 0
    margin.anchor_right = 1
    margin.anchor_bottom = 1
    margin.add_theme_constant_override("margin_left", 1)  # Margem mínima para tocar a borda
    margin.add_theme_constant_override("margin_right", 8)
    margin.add_theme_constant_override("margin_top", 8)
    margin.add_theme_constant_override("margin_bottom", 8)
    
    var main_container := VBoxContainer.new()
    main_container.add_theme_constant_override("separation", 12)
    margin.add_child(main_container)
    
    # === TÍTULO ===
    title_label = Label.new()
    title_label.text = "Cidade - Multiplayer"
    title_label.add_theme_font_size_override("font_size", 12)
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_color_override("font_color", Color.WHITE)
    title_label.add_theme_color_override("font_shadow_color", Color.BLACK)
    title_label.add_theme_constant_override("shadow_offset_x", 1)
    title_label.add_theme_constant_override("shadow_offset_y", 1)
    main_container.add_child(title_label)
    
    # === BARRA DE VIDA (HP) COM TEXTO INTERNO ===
    vida_bar = _create_pixel_progress_bar("HP: 100/100", Color("#CC0000"), Color("#FF3333"))
    vida_bar.value = 100  # Valor inicial padrão
    vida_bar.max_value = 100
    main_container.add_child(vida_bar)
    
    # === BARRA DE EXPERIÊNCIA (XP) COM TEXTO INTERNO ===
    xp_bar = _create_pixel_progress_bar("XP: 0/100", Color("#0066CC"), Color("#3399FF"))
    xp_bar.value = 0  # Valor inicial padrão
    xp_bar.max_value = 100
    main_container.add_child(xp_bar)
    
    # Espaçador
    var spacer1 := Control.new()
    spacer1.custom_minimum_size.y = 16
    main_container.add_child(spacer1)
    
    # === ÍCONES HORIZONTAIS ===
    var icons_container := HBoxContainer.new()
    icons_container.alignment = BoxContainer.ALIGNMENT_CENTER
    icons_container.add_theme_constant_override("separation", 12)
    
    # Status
    var status_container := VBoxContainer.new()
    status_container.alignment = BoxContainer.ALIGNMENT_CENTER
    status_button = _create_pixel_button(_load_icon("res://art/icons/status.png"), 48)
    status_button.pressed.connect(_on_status_pressed)
    status_container.add_child(status_button)
    var status_lbl := Label.new()
    status_lbl.text = "Status"
    status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_lbl.add_theme_font_size_override("font_size", 8)
    status_lbl.add_theme_color_override("font_color", Color.WHITE)
    status_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
    status_lbl.add_theme_constant_override("shadow_offset_x", 1)
    status_lbl.add_theme_constant_override("shadow_offset_y", 1)
    status_container.add_child(status_lbl)
    icons_container.add_child(status_container)
    
    # Inventário
    var inventory_container := VBoxContainer.new()
    inventory_container.alignment = BoxContainer.ALIGNMENT_CENTER
    inventory_button = _create_pixel_button(_load_icon("res://art/icons/inventario.png"), 48)
    inventory_button.pressed.connect(_on_inventory_pressed)
    inventory_container.add_child(inventory_button)
    var inventory_lbl := Label.new()
    inventory_lbl.text = "Inventário"
    inventory_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    inventory_lbl.add_theme_font_size_override("font_size", 8)
    inventory_lbl.add_theme_color_override("font_color", Color.WHITE)
    inventory_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
    inventory_lbl.add_theme_constant_override("shadow_offset_x", 1)
    inventory_lbl.add_theme_constant_override("shadow_offset_y", 1)
    inventory_container.add_child(inventory_lbl)
    icons_container.add_child(inventory_container)
    
    # Mapas
    var maps_container := VBoxContainer.new()
    maps_container.alignment = BoxContainer.ALIGNMENT_CENTER
    maps_button = _create_pixel_button(_load_icon("res://art/icons/mapa.png"), 48)
    maps_button.pressed.connect(_on_maps_pressed)
    maps_container.add_child(maps_button)
    var maps_lbl := Label.new()
    maps_lbl.text = "Mapas"
    maps_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    maps_lbl.add_theme_font_size_override("font_size", 8)
    maps_lbl.add_theme_color_override("font_color", Color.WHITE)
    maps_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
    maps_lbl.add_theme_constant_override("shadow_offset_x", 1)
    maps_lbl.add_theme_constant_override("shadow_offset_y", 1)
    maps_container.add_child(maps_lbl)
    icons_container.add_child(maps_container)
    
    main_container.add_child(icons_container)
    
    # Espaçador
    var spacer2 := Control.new()
    spacer2.custom_minimum_size.y = 16
    main_container.add_child(spacer2)
    
    # === AUTO ATTACK TOGGLE ESTILIZADO ===
    auto_attack_button = _create_pixel_toggle("Auto Attack")
    auto_attack_button.toggled.connect(_on_auto_attack_toggled)
    main_container.add_child(auto_attack_button)
    
    add_child(margin)
    
    # Criar elementos complementares
    _create_popup_menu()
    _create_dialogs()
    _create_points_distribution_window()
    _create_inventory_window()

# === FUNÇÕES DE CRIAÇÃO DE ELEMENTOS PIXEL ART ===
func _create_pixel_progress_bar(text: String, bg_color: Color, fill_color: Color) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.custom_minimum_size.y = 24
    bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bar.show_percentage = false
    
    # Estilo pixel art para fundo
    var bg_style := StyleBoxFlat.new()
    bg_style.bg_color = bg_color
    bg_style.corner_radius_top_left = 0
    bg_style.corner_radius_top_right = 0
    bg_style.corner_radius_bottom_left = 0
    bg_style.corner_radius_bottom_right = 0
    bg_style.border_width_left = 2
    bg_style.border_width_right = 2
    bg_style.border_width_top = 2
    bg_style.border_width_bottom = 2
    bg_style.border_color = Color.BLACK
    
    # Estilo pixel art para preenchimento
    var fill_style := StyleBoxFlat.new()
    fill_style.bg_color = fill_color
    fill_style.corner_radius_top_left = 0
    fill_style.corner_radius_top_right = 0
    fill_style.corner_radius_bottom_left = 0
    fill_style.corner_radius_bottom_right = 0
    
    bar.add_theme_stylebox_override("background", bg_style)
    bar.add_theme_stylebox_override("fill", fill_style)
    
    # Adicionar label de texto interno
    var label := Label.new()
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 10)
    label.add_theme_color_override("font_color", Color.WHITE)
    label.add_theme_color_override("font_shadow_color", Color.BLACK)
    label.add_theme_constant_override("shadow_offset_x", 1)
    label.add_theme_constant_override("shadow_offset_y", 1)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.anchor_left = 0
    label.anchor_top = 0
    label.anchor_right = 1
    label.anchor_bottom = 1
    bar.add_child(label)
    
    return bar

func _create_pixel_button(icon: Texture2D, size: int) -> Button:
    var button := Button.new()
    button.custom_minimum_size = Vector2(size, size)
    button.icon = icon
    button.expand_icon = true
    
    # Estilo para botão circular transparente (ícones já têm suas próprias bordas)
    var normal_style := StyleBoxFlat.new()
    normal_style.bg_color = Color.TRANSPARENT
    normal_style.corner_radius_top_left = 0
    normal_style.corner_radius_top_right = 0
    normal_style.corner_radius_bottom_left = 0
    normal_style.corner_radius_bottom_right = 0
    
    var pressed_style := StyleBoxFlat.new()
    pressed_style.bg_color = Color(1, 1, 1, 0.2)  # Leve brilho quando pressionado
    pressed_style.corner_radius_top_left = 0
    pressed_style.corner_radius_top_right = 0
    pressed_style.corner_radius_bottom_left = 0
    pressed_style.corner_radius_bottom_right = 0
    
    var hover_style := StyleBoxFlat.new()
    hover_style.bg_color = Color(1, 1, 1, 0.1)  # Leve brilho no hover
    hover_style.corner_radius_top_left = 0
    hover_style.corner_radius_top_right = 0
    hover_style.corner_radius_bottom_left = 0
    hover_style.corner_radius_bottom_right = 0
    
    button.add_theme_stylebox_override("normal", normal_style)
    button.add_theme_stylebox_override("pressed", pressed_style)
    button.add_theme_stylebox_override("hover", hover_style)
    
    return button

func _create_pixel_toggle(text: String) -> CheckBox:
    var toggle := CheckBox.new()
    toggle.text = text
    toggle.add_theme_font_size_override("font_size", 12)
    toggle.add_theme_color_override("font_color", Color.WHITE)
    toggle.add_theme_color_override("font_shadow_color", Color.BLACK)
    toggle.add_theme_constant_override("shadow_offset_x", 1)
    toggle.add_theme_constant_override("shadow_offset_y", 1)
    
    # Estilo pixel art para checkbox
    var unchecked_style := StyleBoxFlat.new()
    unchecked_style.bg_color = Color("#DDDDDD")
    unchecked_style.corner_radius_top_left = 0
    unchecked_style.corner_radius_top_right = 0
    unchecked_style.corner_radius_bottom_left = 0
    unchecked_style.corner_radius_bottom_right = 0
    unchecked_style.border_width_left = 2
    unchecked_style.border_width_right = 2
    unchecked_style.border_width_top = 2
    unchecked_style.border_width_bottom = 2
    unchecked_style.border_color = Color.BLACK
    
    var checked_style := StyleBoxFlat.new()
    checked_style.bg_color = Color("#66FF66")
    checked_style.corner_radius_top_left = 0
    checked_style.corner_radius_top_right = 0
    checked_style.corner_radius_bottom_left = 0
    checked_style.corner_radius_bottom_right = 0
    checked_style.border_width_left = 2
    checked_style.border_width_right = 2
    checked_style.border_width_top = 2
    checked_style.border_width_bottom = 2
    checked_style.border_color = Color.BLACK
    
    toggle.add_theme_stylebox_override("normal", unchecked_style)
    toggle.add_theme_stylebox_override("pressed", checked_style)
    
    return toggle

# ================== CRIAÇÃO DE ÍCONES ==================
func _load_icon(path: String) -> Texture2D:
    if ResourceLoader.exists(path):
        return load(path)
    else:
        print("⚠️ Ícone não encontrado: ", path)
        return null

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
func _on_auto_attack_toggled(pressed: bool) -> void:
    var main_node = get_parent()
    if main_node and main_node.has_method("set_auto_attack"):
        main_node.set_auto_attack(pressed)

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
    _open_points_distribution_window()

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
    points_window.title = ""  # Sem título padrão, vamos criar customizado
    points_window.size = Vector2i(480, 550)
    points_window.visible = false
    points_window.borderless = true  # Remove borda padrão
    points_window.close_requested.connect(func(): points_window.visible = false)
    add_child(points_window)
    
    # === PAINEL PRINCIPAL COM MOLDURA FANTASIA ===
    var main_panel := Panel.new()
    main_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    
    # Estilo de moldura de madeira escura pixel art
    var frame_style := StyleBoxFlat.new()
    frame_style.bg_color = Color("#2D1B0E")  # Madeira escura
    frame_style.corner_radius_top_left = 0
    frame_style.corner_radius_top_right = 0
    frame_style.corner_radius_bottom_left = 0
    frame_style.corner_radius_bottom_right = 0
    frame_style.border_width_left = 4
    frame_style.border_width_right = 4
    frame_style.border_width_top = 4
    frame_style.border_width_bottom = 4
    frame_style.border_color = Color("#1A0F08")  # Borda mais escura
    main_panel.add_theme_stylebox_override("panel", frame_style)
    points_window.add_child(main_panel)
    
    # === BARRA DE TÍTULO PERSONALIZADA ===
    var title_bar := Panel.new()
    title_bar.anchor_right = 1
    title_bar.anchor_bottom = 0
    title_bar.offset_left = 8
    title_bar.offset_top = 8
    title_bar.offset_right = -8
    title_bar.offset_bottom = 45
    
    # Estilo da barra de título (metal dourado)
    var title_style := StyleBoxFlat.new()
    title_style.bg_color = Color("#8B6914")  # Dourado escuro
    title_style.corner_radius_top_left = 0
    title_style.corner_radius_top_right = 0
    title_style.corner_radius_bottom_left = 0
    title_style.corner_radius_bottom_right = 0
    title_style.border_width_left = 2
    title_style.border_width_right = 2
    title_style.border_width_top = 2
    title_style.border_width_bottom = 2
    title_style.border_color = Color("#B8860B")  # Dourado claro
    title_bar.add_theme_stylebox_override("panel", title_style)
    main_panel.add_child(title_bar)
    
    # Título decorativo
    var title := Label.new()
    title.text = "⚔ STATUS DO PERSONAGEM ⚔"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    title.add_theme_font_size_override("font_size", 14)
    title.add_theme_color_override("font_color", Color("#FFF8DC"))  # Branco cremoso
    title.add_theme_color_override("font_shadow_color", Color("#000000"))
    title.add_theme_constant_override("shadow_offset_x", 1)
    title.add_theme_constant_override("shadow_offset_y", 1)
    title_bar.add_child(title)
    
    # Botão fechar decorativo
    var close_button := Button.new()
    close_button.text = "✕"
    close_button.anchor_left = 0.9
    close_button.anchor_right = 1
    close_button.anchor_top = 0.1
    close_button.anchor_bottom = 0.9
    close_button.offset_left = -5
    close_button.offset_right = -5
    close_button.offset_top = 2
    close_button.offset_bottom = -2
    close_button.pressed.connect(func(): points_window.visible = false)
    
    # Estilo do botão fechar
    var close_style := StyleBoxFlat.new()
    close_style.bg_color = Color("#8B0000")  # Vermelho escuro
    close_style.corner_radius_top_left = 0
    close_style.corner_radius_top_right = 0
    close_style.corner_radius_bottom_left = 0
    close_style.corner_radius_bottom_right = 0
    close_style.border_width_left = 1
    close_style.border_width_right = 1
    close_style.border_width_top = 1
    close_style.border_width_bottom = 1
    close_style.border_color = Color("#FF0000")
    close_button.add_theme_stylebox_override("normal", close_style)
    close_button.add_theme_color_override("font_color", Color.WHITE)
    close_button.add_theme_font_size_override("font_size", 12)
    title_bar.add_child(close_button)
    
    # === CONTAINER PRINCIPAL DO CONTEÚDO ===
    var content_container := VBoxContainer.new()
    content_container.name = "content_container"
    content_container.anchor_right = 1
    content_container.anchor_bottom = 1
    content_container.offset_left = 20
    content_container.offset_top = 60
    content_container.offset_right = -20
    content_container.offset_bottom = -20
    content_container.add_theme_constant_override("separation", 15)
    main_panel.add_child(content_container)
    
    # === INFORMAÇÕES BÁSICAS COM VISUAL RPG ===
    var basic_section := VBoxContainer.new()
    basic_section.add_theme_constant_override("separation", 8)
    
    # Nível com decoração
    var level_container := HBoxContainer.new()
    level_container.alignment = BoxContainer.ALIGNMENT_CENTER
    var level_icon := Label.new()
    level_icon.text = "⭐"
    level_icon.add_theme_font_size_override("font_size", 16)
    level_container.add_child(level_icon)
    var level_label := Label.new()
    level_label.name = "level_label"
    level_label.add_theme_font_size_override("font_size", 16)
    level_label.add_theme_color_override("font_color", Color("#FFD700"))  # Dourado
    level_label.add_theme_color_override("font_shadow_color", Color.BLACK)
    level_label.add_theme_constant_override("shadow_offset_x", 1)
    level_label.add_theme_constant_override("shadow_offset_y", 1)
    level_container.add_child(level_label)
    basic_section.add_child(level_container)
    
    # Barra de HP decorativa
    var hp_container := VBoxContainer.new()
    var hp_title := Label.new()
    hp_title.text = "💖 VIDA"
    hp_title.add_theme_font_size_override("font_size", 12)
    hp_title.add_theme_color_override("font_color", Color("#FF6B6B"))
    hp_title.add_theme_color_override("font_shadow_color", Color.BLACK)
    hp_title.add_theme_constant_override("shadow_offset_x", 1)
    hp_title.add_theme_constant_override("shadow_offset_y", 1)
    hp_container.add_child(hp_title)
    
    var hp_bar := ProgressBar.new()
    hp_bar.name = "hp_bar"
    hp_bar.custom_minimum_size.y = 20
    hp_bar.show_percentage = false
    # Estilo da barra HP
    var hp_bg_style := StyleBoxFlat.new()
    hp_bg_style.bg_color = Color("#4A0000")  # Vermelho muito escuro
    hp_bg_style.corner_radius_top_left = 0
    hp_bg_style.corner_radius_top_right = 0
    hp_bg_style.corner_radius_bottom_left = 0
    hp_bg_style.corner_radius_bottom_right = 0
    hp_bg_style.border_width_left = 2
    hp_bg_style.border_width_right = 2
    hp_bg_style.border_width_top = 2
    hp_bg_style.border_width_bottom = 2
    hp_bg_style.border_color = Color.BLACK
    var hp_fill_style := StyleBoxFlat.new()
    hp_fill_style.bg_color = Color("#DC143C")  # Vermelho vibrante
    hp_fill_style.corner_radius_top_left = 0
    hp_fill_style.corner_radius_top_right = 0
    hp_fill_style.corner_radius_bottom_left = 0
    hp_fill_style.corner_radius_bottom_right = 0
    hp_bar.add_theme_stylebox_override("background", hp_bg_style)
    hp_bar.add_theme_stylebox_override("fill", hp_fill_style)
    
    # Label dentro da barra HP
    var hp_label := Label.new()
    hp_label.name = "hp_label"
    hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    hp_label.add_theme_font_size_override("font_size", 11)
    hp_label.add_theme_color_override("font_color", Color.WHITE)
    hp_label.add_theme_color_override("font_shadow_color", Color.BLACK)
    hp_label.add_theme_constant_override("shadow_offset_x", 1)
    hp_label.add_theme_constant_override("shadow_offset_y", 1)
    hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hp_bar.add_child(hp_label)
    hp_container.add_child(hp_bar)
    basic_section.add_child(hp_container)
    
    # Barra de XP decorativa
    var xp_container := VBoxContainer.new()
    var xp_title := Label.new()
    xp_title.text = "✨ EXPERIÊNCIA"
    xp_title.add_theme_font_size_override("font_size", 12)
    xp_title.add_theme_color_override("font_color", Color("#4169E1"))
    xp_title.add_theme_color_override("font_shadow_color", Color.BLACK)
    xp_title.add_theme_constant_override("shadow_offset_x", 1)
    xp_title.add_theme_constant_override("shadow_offset_y", 1)
    xp_container.add_child(xp_title)
    
    var status_xp_bar := ProgressBar.new()
    status_xp_bar.name = "xp_bar"
    status_xp_bar.custom_minimum_size.y = 20
    status_xp_bar.show_percentage = false
    # Estilo da barra XP
    var xp_bg_style := StyleBoxFlat.new()
    xp_bg_style.bg_color = Color("#000080")  # Azul muito escuro
    xp_bg_style.corner_radius_top_left = 0
    xp_bg_style.corner_radius_top_right = 0
    xp_bg_style.corner_radius_bottom_left = 0
    xp_bg_style.corner_radius_bottom_right = 0
    xp_bg_style.border_width_left = 2
    xp_bg_style.border_width_right = 2
    xp_bg_style.border_width_top = 2
    xp_bg_style.border_width_bottom = 2
    xp_bg_style.border_color = Color.BLACK
    var xp_fill_style := StyleBoxFlat.new()
    xp_fill_style.bg_color = Color("#1E90FF")  # Azul vibrante
    xp_fill_style.corner_radius_top_left = 0
    xp_fill_style.corner_radius_top_right = 0
    xp_fill_style.corner_radius_bottom_left = 0
    xp_fill_style.corner_radius_bottom_right = 0
    status_xp_bar.add_theme_stylebox_override("background", xp_bg_style)
    status_xp_bar.add_theme_stylebox_override("fill", xp_fill_style)
    
    # Label dentro da barra XP
    var status_xp_label := Label.new()
    status_xp_label.name = "xp_label"
    status_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    status_xp_label.add_theme_font_size_override("font_size", 11)
    status_xp_label.add_theme_color_override("font_color", Color.WHITE)
    status_xp_label.add_theme_color_override("font_shadow_color", Color.BLACK)
    status_xp_label.add_theme_constant_override("shadow_offset_x", 1)
    status_xp_label.add_theme_constant_override("shadow_offset_y", 1)
    status_xp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    status_xp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    status_xp_bar.add_child(status_xp_label)
    xp_container.add_child(status_xp_bar)
    basic_section.add_child(xp_container)
    
    content_container.add_child(basic_section)
    
    # === DIVISOR DECORATIVO ===
    var divider := Panel.new()
    divider.custom_minimum_size.y = 3
    var divider_style := StyleBoxFlat.new()
    divider_style.bg_color = Color("#8B6914")  # Dourado
    divider_style.corner_radius_top_left = 0
    divider_style.corner_radius_top_right = 0
    divider_style.corner_radius_bottom_left = 0
    divider_style.corner_radius_bottom_right = 0
    divider.add_theme_stylebox_override("panel", divider_style)
    content_container.add_child(divider)
    
    # === SEÇÃO DE ATRIBUTOS ===
    var attributes_section := VBoxContainer.new()
    attributes_section.add_theme_constant_override("separation", 10)
    
    # Título dos atributos
    var attr_title := Label.new()
    attr_title.text = "⚔ ATRIBUTOS ⚔"
    attr_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    attr_title.add_theme_font_size_override("font_size", 16)
    attr_title.add_theme_color_override("font_color", Color("#DAA520"))  # Dourado
    attr_title.add_theme_color_override("font_shadow_color", Color.BLACK)
    attr_title.add_theme_constant_override("shadow_offset_x", 1)
    attr_title.add_theme_constant_override("shadow_offset_y", 1)
    attributes_section.add_child(attr_title)
    
    # Pontos disponíveis com selo decorativo
    var points_container := Panel.new()
    points_container.custom_minimum_size.y = 35
    var points_style := StyleBoxFlat.new()
    points_style.bg_color = Color("#4B0082")  # Roxo escuro
    points_style.corner_radius_top_left = 0
    points_style.corner_radius_top_right = 0
    points_style.corner_radius_bottom_left = 0
    points_style.corner_radius_bottom_right = 0
    points_style.border_width_left = 2
    points_style.border_width_right = 2
    points_style.border_width_top = 2
    points_style.border_width_bottom = 2
    points_style.border_color = Color("#9932CC")  # Roxo claro
    points_container.add_theme_stylebox_override("panel", points_style)
    
    available_points_label = Label.new()
    available_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    available_points_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    available_points_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    available_points_label.add_theme_font_size_override("font_size", 14)
    available_points_label.add_theme_color_override("font_color", Color("#FFD700"))  # Dourado
    available_points_label.add_theme_color_override("font_shadow_color", Color.BLACK)
    available_points_label.add_theme_constant_override("shadow_offset_x", 1)
    available_points_label.add_theme_constant_override("shadow_offset_y", 1)
    points_container.add_child(available_points_label)
    attributes_section.add_child(points_container)
    
    content_container.add_child(attributes_section)
    
    # === GRID DE ATRIBUTOS DECORATIVOS ===
    var attr_grid := VBoxContainer.new()
    attr_grid.add_theme_constant_override("separation", 8)
    
    # Função helper para criar linha de atributo
    var create_attr_row = func(attr_name: String, icon: String, color: Color) -> HBoxContainer:
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 10)
        
        # Ícone do atributo
        var attr_icon := Label.new()
        attr_icon.text = icon
        attr_icon.add_theme_font_size_override("font_size", 16)
        attr_icon.custom_minimum_size.x = 25
        row.add_child(attr_icon)
        
        # Nome do atributo
        var name_label := Label.new()
        name_label.text = attr_name
        name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        name_label.add_theme_font_size_override("font_size", 12)
        name_label.add_theme_color_override("font_color", color)
        name_label.add_theme_color_override("font_shadow_color", Color.BLACK)
        name_label.add_theme_constant_override("shadow_offset_x", 1)
        name_label.add_theme_constant_override("shadow_offset_y", 1)
        row.add_child(name_label)
        
        # Valor do atributo
        var value_label := Label.new()
        value_label.custom_minimum_size.x = 150
        value_label.add_theme_font_size_override("font_size", 11)
        value_label.add_theme_color_override("font_color", Color.WHITE)
        value_label.add_theme_color_override("font_shadow_color", Color.BLACK)
        value_label.add_theme_constant_override("shadow_offset_x", 1)
        value_label.add_theme_constant_override("shadow_offset_y", 1)
        row.add_child(value_label)
        
        # Botão de + decorativo
        var plus_button := Button.new()
        plus_button.text = "+"
        plus_button.custom_minimum_size = Vector2(25, 25)
        plus_button.add_theme_font_size_override("font_size", 14)
        
        # Estilo do botão +
        var plus_normal := StyleBoxFlat.new()
        plus_normal.bg_color = Color("#228B22")  # Verde floresta
        plus_normal.corner_radius_top_left = 0
        plus_normal.corner_radius_top_right = 0
        plus_normal.corner_radius_bottom_left = 0
        plus_normal.corner_radius_bottom_right = 0
        plus_normal.border_width_left = 2
        plus_normal.border_width_right = 2
        plus_normal.border_width_top = 2
        plus_normal.border_width_bottom = 2
        plus_normal.border_color = Color("#32CD32")  # Verde lime
        
        var plus_pressed := StyleBoxFlat.new()
        plus_pressed.bg_color = Color("#006400")  # Verde escuro
        plus_pressed.corner_radius_top_left = 0
        plus_pressed.corner_radius_top_right = 0
        plus_pressed.corner_radius_bottom_left = 0
        plus_pressed.corner_radius_bottom_right = 0
        plus_pressed.border_width_left = 2
        plus_pressed.border_width_right = 2
        plus_pressed.border_width_top = 2
        plus_pressed.border_width_bottom = 2
        plus_pressed.border_color = Color("#32CD32")
        
        var plus_disabled := StyleBoxFlat.new()
        plus_disabled.bg_color = Color("#696969")  # Cinza escuro
        plus_disabled.corner_radius_top_left = 0
        plus_disabled.corner_radius_top_right = 0
        plus_disabled.corner_radius_bottom_left = 0
        plus_disabled.corner_radius_bottom_right = 0
        plus_disabled.border_width_left = 2
        plus_disabled.border_width_right = 2
        plus_disabled.border_width_top = 2
        plus_disabled.border_width_bottom = 2
        plus_disabled.border_color = Color("#A9A9A9")  # Cinza claro
        
        plus_button.add_theme_stylebox_override("normal", plus_normal)
        plus_button.add_theme_stylebox_override("pressed", plus_pressed)
        plus_button.add_theme_stylebox_override("disabled", plus_disabled)
        plus_button.add_theme_color_override("font_color", Color.WHITE)
        plus_button.add_theme_color_override("font_color_disabled", Color("#DCDCDC"))
        
        row.add_child(plus_button)
        return row
    
    # Criar linhas de atributos
    var strength_row = create_attr_row.call("Força", "💪", Color("#FF4500"))  # Laranja vermelho
    strength_label = strength_row.get_child(2)  # Label do valor
    strength_button = strength_row.get_child(3)  # Botão +
    strength_button.pressed.connect(_add_strength_point)
    attr_grid.add_child(strength_row)
    
    var defense_row = create_attr_row.call("Defesa", "🛡️", Color("#4682B4"))  # Azul aço
    defense_label = defense_row.get_child(2)
    defense_button = defense_row.get_child(3)
    defense_button.pressed.connect(_add_defense_point)
    attr_grid.add_child(defense_row)
    
    var intelligence_row = create_attr_row.call("Inteligência", "🧠", Color("#9370DB"))  # Roxo médio
    intelligence_label = intelligence_row.get_child(2)
    intelligence_button = intelligence_row.get_child(3)
    intelligence_button.pressed.connect(_add_intelligence_point)
    attr_grid.add_child(intelligence_row)
    
    var vitality_row = create_attr_row.call("Vitalidade", "❤️", Color("#DC143C"))  # Vermelho carmesim
    vitality_label = vitality_row.get_child(2)
    vitality_button = vitality_row.get_child(3)
    vitality_button.pressed.connect(_add_vitality_point)
    attr_grid.add_child(vitality_row)
    
    attributes_section.add_child(attr_grid)

func _open_points_distribution_window() -> void:
    _update_points_display()
    points_window.popup_centered()

func _update_points_display() -> void:
    var main_node = get_parent()
    if main_node and main_node.has_method("get_player_stats"):
        var stats = main_node.get_player_stats()
        
        # Navegar pela nova estrutura da janela usando busca por nome
        var main_panel = points_window.get_child(0)  # Panel principal
        var content_container = main_panel.get_node("content_container")  # Buscar por nome
        var basic_section = content_container.get_child(0)  # Seção básica
        
        # Atualizar nível
        var level_container = basic_section.get_child(0)  # HBoxContainer do nível
        var level_label = level_container.get_child(1)  # Label do nível (segundo child)
        level_label.text = "Nível %d" % stats.level
        
        # Atualizar HP
        var hp_container = basic_section.get_child(1)  # VBoxContainer do HP
        var status_hp_bar = hp_container.get_child(1)  # ProgressBar do HP
        var hp_label = status_hp_bar.get_child(0)  # Label interno do HP
        status_hp_bar.value = stats.hp
        status_hp_bar.max_value = stats.hp_max
        hp_label.text = "%d/%d" % [stats.hp, stats.hp_max]
        
        # Atualizar XP
        var xp_container = basic_section.get_child(2)  # VBoxContainer do XP
        var status_xp_bar = xp_container.get_child(1)  # ProgressBar do XP
        var xp_label = status_xp_bar.get_child(0)  # Label interno do XP
        status_xp_bar.value = stats.xp
        status_xp_bar.max_value = stats.xp_max
        xp_label.text = "%d/%d" % [stats.xp, stats.xp_max]
        
        # Atualizar pontos disponíveis
        if stats.available_points > 0:
            available_points_label.text = "💎 Pontos Disponíveis: %d 💎" % stats.available_points
        else:
            available_points_label.text = "⭕ Nenhum ponto disponível"
        
        # Atualizar atributos
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
    # Atualizar texto interno da barra de HP
    if vida_bar and vida_bar.get_child_count() > 0:
        var label = vida_bar.get_child(0) as Label
        if label:
            label.text = "HP: %d/%d" % [cur, maxv]

func _update_xp_text(cur: int, maxv: int) -> void:
    # Atualizar texto interno da barra de XP
    if xp_bar and xp_bar.get_child_count() > 0:
        var label = xp_bar.get_child(0) as Label
        if label:
            label.text = "XP: %d/%d" % [cur, maxv]

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
