extends CanvasLayer
signal on_select_map(map_name: String)

var health_bar: ProgressBar
var title_label: Label
var subtitle_label: Label
var map_button: Button
var popup_menu: PopupMenu
var dialog: AcceptDialog

# ataque / cooldown
var player_ref: Player
var atk_icon: TextureRect
var atk_fallback_label: Label
var atk_cd_bar: ProgressBar

func _init() -> void:
    layer = 10

func _ready() -> void:
    # Barra superior
    var top: HBoxContainer = HBoxContainer.new()
    top.anchor_left = 0; top.anchor_top = 0
    top.anchor_right = 1; top.anchor_bottom = 0
    top.offset_left = 16; top.offset_top = 16; top.offset_right = -16
    top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_child(top)

    title_label = Label.new()
    title_label.text = "Cidade"
    title_label.add_theme_font_size_override("font_size", 22)
    top.add_child(title_label)

    subtitle_label = Label.new()
    subtitle_label.text = ""
    subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(subtitle_label)

    health_bar = ProgressBar.new()
    health_bar.min_value = 0; health_bar.max_value = 100; health_bar.value = 100
    health_bar.custom_minimum_size = Vector2(200, 24)
    top.add_child(health_bar)

    # Ícone de ataque + barra de cooldown
    var atk_box: VBoxContainer = VBoxContainer.new()
    atk_box.custom_minimum_size = Vector2(48, 48 + 8)
    atk_box.alignment = BoxContainer.ALIGNMENT_CENTER
    top.add_child(atk_box)

    atk_icon = TextureRect.new()
    atk_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    atk_icon.custom_minimum_size = Vector2(48, 48)
    var icon_path: String = "res://art/ui/attack_icon.png"
    if ResourceLoader.exists(icon_path):
        atk_icon.texture = load(icon_path)
    atk_box.add_child(atk_icon)

    atk_fallback_label = Label.new()
    # >>> ternário no formato do GDScript
    atk_fallback_label.text = "J" if atk_icon.texture == null else ""
    atk_fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    atk_fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    atk_fallback_label.custom_minimum_size = Vector2(48, 48)
    if atk_icon.texture == null:
        atk_box.add_child(atk_fallback_label)

    atk_cd_bar = ProgressBar.new()
    atk_cd_bar.min_value = 0
    atk_cd_bar.max_value = 100
    atk_cd_bar.value = 100 # pronto (100%)
    atk_cd_bar.custom_minimum_size = Vector2(48, 6)
    atk_cd_bar.add_theme_stylebox_override("fill", StyleBoxFlat.new())
    atk_box.add_child(atk_cd_bar)

    map_button = Button.new()
    map_button.text = "Mapas"
    map_button.pressed.connect(_open_map_menu)
    top.add_child(map_button)

    popup_menu = PopupMenu.new()
    add_child(popup_menu)
    popup_menu.add_item("Floresta")
    popup_menu.id_pressed.connect(func(id):
        var selected_map := popup_menu.get_item_text(id)
        on_select_map.emit(selected_map)
    )

    dialog = AcceptDialog.new()
    dialog.title = "Aviso"
    add_child(dialog)

func _open_map_menu() -> void:
    popup_menu.position = map_button.get_global_position() + Vector2(0, map_button.size.y)
    popup_menu.popup()

func set_player(p: Player) -> void:
    player_ref = p

func update_health(current: int, maxv: int) -> void:
    health_bar.max_value = maxv
    health_bar.value = current

func set_map_title(t: String) -> void:
    title_label.text = t

func set_subtitle(t: String) -> void:
    subtitle_label.text = t

func show_popup(texto: String) -> void:
    dialog.dialog_text = texto
    dialog.popup_centered()

func _process(_delta: float) -> void:
    if player_ref != null:
        var ratio: float = player_ref.get_attack_cooldown_ratio()
        atk_cd_bar.value = int(round(ratio * 100.0))
        # Desabilita o ícone quando em cooldown
        var alpha: float = 0.4 + 0.6 * ratio
        if atk_icon.texture != null:
            atk_icon.modulate = Color(1, 1, 1, alpha)
        if atk_fallback_label != null:
            atk_fallback_label.modulate = Color(1, 1, 1, alpha)

# ---------------- Dano flutuante (em tela) ----------------
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
