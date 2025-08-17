extends CanvasLayer
signal on_select_map(map_name: String)

var health_bar: ProgressBar
var title_label: Label
var subtitle_label: Label
var map_button: Button
var popup_menu: PopupMenu
var dialog: AcceptDialog

func _init() -> void:
    layer = 10

func _ready() -> void:
    # Barra superior fixa
    var top: HBoxContainer = HBoxContainer.new()
    top.anchor_left = 0
    top.anchor_top = 0
    top.anchor_right = 1
    top.anchor_bottom = 0
    top.offset_left = 16
    top.offset_top = 16
    top.offset_right = -16
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
    health_bar.min_value = 0
    health_bar.max_value = 100
    health_bar.value = 100
    health_bar.custom_minimum_size = Vector2(200, 24)
    top.add_child(health_bar)

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
