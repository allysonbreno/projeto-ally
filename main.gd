extends Node

# Containers
var map_container: Node
var hud: CanvasLayer

# Estado do player
var player_hp_max: int = 100
var player_hp: int = 100
var enemies_to_kill: int = 0

# Sistema de XP e Level
var player_level: int = 1
var player_xp: int = 0
var player_xp_max: int = 100

# Inputs
const InputSetupScript := preload("res://scripts/input_setup.gd")

# --- Áudio ---
# nomes lógicos dos sfx; arquivos procurados: res://audio/<nome>.{ogg,mp3,wav,opus}
const SFX_NAMES: Array[String] = ["attack", "hit", "hurt", "die", "complete"]
const SFX_EXTS: Array[String] = [".ogg", ".mp3", ".wav", ".opus"]
const SFX_DB := { "attack": -2.0, "hit": -3.0, "hurt": -4.0, "die": -3.0, "complete": -2.0 } # volumes
var sfx_players: Dictionary = {} # sfx_name -> AudioStreamPlayer

func _ready() -> void:
    # inputs
    InputSetupScript.setup()

    # containers
    map_container = Node.new()
    map_container.name = "MapContainer"
    add_child(map_container)

    var HUD = load("res://scripts/hud.gd")
    hud = HUD.new()
    add_child(hud)
    hud.on_select_map.connect(_on_select_map)
    hud.update_health(player_hp, player_hp_max)
    hud.update_xp(player_xp, player_xp_max)
    hud.set_map_title("Cidade")

    # sfx
    _setup_sfx_players()

    # mapa inicial
    load_city()

func _setup_sfx_players() -> void:
    for sfx_name in SFX_NAMES:
        var stream: AudioStream = _resolve_audio_stream(sfx_name)
        if stream != null:
            var p: AudioStreamPlayer = AudioStreamPlayer.new()
            p.stream = stream
            if SFX_DB.has(sfx_name):
                p.volume_db = float(SFX_DB[sfx_name])
            add_child(p)
            sfx_players[sfx_name] = p

func _resolve_audio_stream(base_name: String) -> AudioStream:
    for ext in SFX_EXTS:
        var path: String = "res://audio/%s%s" % [base_name, ext]
        if ResourceLoader.exists(path):
            var res: Resource = load(path)
            if res is AudioStream:
                return res
    return null

func play_sfx_id(sfx_name: String) -> void:
    if sfx_players.has(sfx_name):
        var p: AudioStreamPlayer = sfx_players[sfx_name]
        p.play()

# ---- Lógica de jogo / HUD ----
func reset_player() -> void:
    player_hp = player_hp_max
    hud.update_health(player_hp, player_hp_max)

func damage_player(amount: int, hit_world_pos: Vector2 = Vector2.ZERO) -> void:
    player_hp = max(0, player_hp - amount)
    hud.update_health(player_hp, player_hp_max)
    play_sfx_id("hurt")
    show_damage_popup_at_world(hit_world_pos, "-" + str(amount), Color(1, 0.3, 0.3, 1.0))

    if player_hp <= 0:
        await get_tree().process_frame
        load_city()
        hud.set_subtitle("")
        hud.show_popup("Você morreu e voltou para a cidade.")
        play_sfx_id("die")

func load_city() -> void:
    _clear_map()
    var City = load("res://scripts/city_map.gd")
    var city = City.new()
    map_container.add_child(city)
    city.setup(self)
    hud.set_map_title("Cidade")
    hud.set_subtitle("")
    reset_player()

func load_forest() -> void:
    _clear_map()
    var Forest = load("res://scripts/forest_map.gd")
    var forest = Forest.new()
    map_container.add_child(forest)
    forest.setup(self)
    hud.set_map_title("Floresta")

func _clear_map() -> void:
    for c in map_container.get_children():
        c.queue_free()

func _on_select_map(map_name: String) -> void:
    match map_name:
        "Floresta":
            load_forest()
        _:
            pass

func set_enemies_to_kill(count: int) -> void:
    enemies_to_kill = count
    hud.set_subtitle("Inimigos restantes: %d" % enemies_to_kill)

func on_enemy_killed() -> void:
    enemies_to_kill = max(0, enemies_to_kill - 1)
    hud.set_subtitle("Inimigos restantes: %d" % enemies_to_kill)
    
    # Ganha XP ao matar inimigo
    gain_xp(50)
    
    if enemies_to_kill == 0:
        await get_tree().process_frame
        load_city()
        hud.show_popup("Mapa completo! Você voltou para a cidade.")
        hud.set_subtitle("")
        play_sfx_id("complete")

# ---- Sistema de XP e Level ----
func gain_xp(amount: int) -> void:
    player_xp += amount
    hud.update_xp(player_xp, player_xp_max)
    
    # Verifica se subiu de level
    while player_xp >= player_xp_max:
        level_up()

func level_up() -> void:
    player_xp -= player_xp_max
    player_level += 1
    player_xp_max = int(player_xp_max * 1.2)  # Aumenta 20% XP necessário
    
    hud.update_xp(player_xp, player_xp_max)
    
    # Mostra mensagem flutuante acima do player
    _show_level_up_message()

func get_player_level() -> int:
    return player_level

func _show_level_up_message() -> void:
    # Encontra o player na cena atual
    var player = _find_player_in_scene()
    if player:
        var player_pos = player.global_position + Vector2(0, -40)  # 40 pixels acima do player
        show_damage_popup_at_world(player_pos, "LEVEL UP! Nível %d" % player_level, Color(1, 1, 0, 1))  # Amarelo dourado

func _find_player_in_scene() -> Player:
    # Procura o player no map_container atual
    if map_container:
        for child in map_container.get_children():
            for grandchild in child.get_children():
                if grandchild is Player:
                    return grandchild
    return null

# ---- Dano flutuante (coordenadas de tela) ----
func show_damage_popup_at_world(world_pos: Vector2, txt: String, color: Color) -> void:
    if hud == null:
        return
    hud.show_damage_popup_at_world(world_pos, txt, color)
