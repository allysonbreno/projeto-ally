extends Node

# Containers fixos
var map_container: Node
var hud: CanvasLayer

# Estado global simples
var player_hp_max: int = 100
var player_hp: int = 100
var enemies_to_kill: int = 0

# Evitar shadowing com a classe global InputSetup
const InputSetupScript := preload("res://scripts/input_setup.gd")

func _ready() -> void:
    # 1) Configurar inputs em runtime
    InputSetupScript.setup()

    # 2) Criar containers (HUD fixo + área de mapas)
    map_container = Node.new()
    map_container.name = "MapContainer"
    add_child(map_container)

    var HUD = load("res://scripts/hud.gd")
    hud = HUD.new()
    add_child(hud)
    hud.on_select_map.connect(_on_select_map)
    hud.update_health(player_hp, player_hp_max)
    hud.set_map_title("Cidade")

    # 3) Carregar mapa inicial (Cidade)
    load_city()

func reset_player() -> void:
    player_hp = player_hp_max
    hud.update_health(player_hp, player_hp_max)

func damage_player(amount: int) -> void:
    player_hp = max(0, player_hp - amount)
    hud.update_health(player_hp, player_hp_max)
    if player_hp <= 0:
        # Morreu → voltar p/ cidade com popup
        await get_tree().process_frame
        load_city()
        hud.set_subtitle("")  # limpar contador na cidade
        hud.show_popup("Você morreu e voltou para a cidade.")

func load_city() -> void:
    _clear_map()
    var City = load("res://scripts/city_map.gd")
    var city = City.new()
    map_container.add_child(city)
    city.setup(self) # passar referência do "Main"
    hud.set_map_title("Cidade")
    hud.set_subtitle("")   # limpar qualquer contador ao entrar na cidade
    reset_player()

func load_forest() -> void:
    _clear_map()
    var Forest = load("res://scripts/forest_map.gd")
    var forest = Forest.new()
    map_container.add_child(forest)
    forest.setup(self) # passa o "Main"
    hud.set_map_title("Floresta")

func _clear_map() -> void:
    for c in map_container.get_children():
        c.queue_free()

# Chamado pelo HUD quando usuário escolhe um mapa
func _on_select_map(map_name: String) -> void:
    match map_name:
        "Floresta":
            load_forest()
        _:
            pass

# Chamado pelo mapa da floresta para setar quantidade de inimigos
func set_enemies_to_kill(count: int) -> void:
    enemies_to_kill = count
    hud.set_subtitle("Inimigos restantes: %d" % enemies_to_kill)

# Chamado pelos inimigos ao morrerem
func on_enemy_killed() -> void:
    enemies_to_kill = max(0, enemies_to_kill - 1)
    hud.set_subtitle("Inimigos restantes: %d" % enemies_to_kill)
    if enemies_to_kill == 0:
        # Completou o mapa → volta à cidade
        await get_tree().process_frame
        load_city()
        hud.show_popup("Mapa completo! Você voltou para a cidade.")
        hud.set_subtitle("")
