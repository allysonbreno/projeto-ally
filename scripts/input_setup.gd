# singleton util simple (não autoload)
class_name InputSetup

static func add_action(name: String, events: Array[InputEvent]) -> void:
    if not InputMap.has_action(name):
        InputMap.add_action(name)
    # limpa padrões
    for e in InputMap.action_get_events(name):
        InputMap.action_erase_event(name, e)
    # adiciona novos
    for ev in events:
        InputMap.action_add_event(name, ev)

static func key(scancode: Key) -> InputEventKey:
    var e := InputEventKey.new()
    e.physical_keycode = scancode
    return e

static func mouse_button(button_index: MouseButton) -> InputEventMouseButton:
    var e := InputEventMouseButton.new()
    e.button_index = button_index
    return e

static func setup() -> void:
    add_action("move_left", [key(KEY_A), key(KEY_LEFT)])
    add_action("move_right", [key(KEY_D), key(KEY_RIGHT)])
    add_action("jump", [key(KEY_SPACE), key(KEY_W), key(KEY_UP)])
    add_action("attack", [mouse_button(MOUSE_BUTTON_LEFT), key(KEY_J)])
    add_action("map_menu", [key(KEY_M)])
