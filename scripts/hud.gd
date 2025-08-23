extends CanvasLayer
signal on_select_map(map_name: String)

var title_label: Label

var hp_bar: ProgressBar
var hp_value_label: Label
var xp_bar: ProgressBar
var xp_value_label: Label

var map_button: Button
var status_button: Button
var popup_menu: PopupMenu
var status_dialog: AcceptDialog
var dialog: AcceptDialog

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

    # Botões container
    var buttons_container := HBoxContainer.new()
    right_box.add_child(buttons_container)
    
    # Botão Status
    status_button = Button.new()
    status_button.text = "Status"
    status_button.focus_mode = Control.FOCUS_NONE
    status_button.pressed.connect(_open_status_dialog)
    buttons_container.add_child(status_button)
    
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

func _open_map_menu() -> void:
    popup_menu.position = map_button.get_global_position() + Vector2(0, map_button.size.y)
    popup_menu.popup()

func _open_status_dialog() -> void:
    var main_node = get_parent()
    if main_node and main_node.has_method("get_player_level"):
        var level = main_node.get_player_level()
        var hp = main_node.player_hp
        var hp_max = main_node.player_hp_max
        var xp = main_node.player_xp
        var xp_max = main_node.player_xp_max
        
        var status_text = "Nível: %d\nHP: %d/%d\nXP: %d/%d" % [level, hp, hp_max, xp, xp_max]
        status_dialog.dialog_text = status_text
        status_dialog.popup_centered()
    else:
        status_dialog.dialog_text = "Nível: 1\nHP: 100/100\nXP: 0/100"
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

# ================== helpers ==================
func _update_hp_text(cur: int, maxv: int) -> void:
    hp_value_label.text = str(cur, "/", maxv)

func _update_xp_text(cur: int, maxv: int) -> void:
    xp_value_label.text = str(cur, "/", maxv)
