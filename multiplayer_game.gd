extends Node2D

var multiplayer_manager: MultiplayerManager
var local_player: CharacterBody2D
var remote_players = {}
var current_map: String = "Cidade"  # Rastrear mapa atual
var current_map_node: Node = null  # ReferÃªncia ao nÃ³ do mapa atual

# ReferÃªncias de cena
var players_container: Node2D
var ui_container: CanvasLayer
var map_container: Node
var hud: CanvasLayer

# Cena do player
const PLAYER_SCENE = preload("res://multiplayer_player.tscn")

# === SISTEMA DE JOGO V2.2 INTEGRADO ===

# Estado do player local
var player_hp_max: int = 100
var player_hp: int = 100
var enemies_to_kill: int = 0

# Sistema de XP e Level
var player_level: int = 1
var player_xp: int = 0
var player_xp_max: int = 100

# Sistema de Atributos
var player_strength: int = 5    # ForÃ§a - aumenta dano
var player_defense: int = 5     # Defesa - reduz dano recebido
var player_intelligence: int = 5 # InteligÃªncia (futuro uso)
var player_vitality: int = 5    # Vitalidade - aumenta HP
var available_points: int = 0   # Pontos disponÃ­veis para distribuir

# Sistema de InventÃ¡rio
var inventory_slots: Array[Dictionary] = []  # 5 slots do inventÃ¡rio
var equipped_weapon: Dictionary = {}         # Slot de equipamento da espada
const MAX_INVENTORY_SLOTS: int = 5

# Sistema de Auto Attack
var auto_attack_enabled: bool = false

# Controle de erro de conexÃ£o
var connection_error_shown: bool = false

# --- Ãudio ---
const SFX_NAMES: Array[String] = ["attack", "hit", "hurt", "die", "complete"]
const SFX_EXTS: Array[String] = [".ogg", ".mp3", ".wav", ".opus"]
const SFX_DB := { "attack": -2.0, "hit": -3.0, "hurt": -4.0, "die": -3.0, "complete": -2.0 }
var sfx_players: Dictionary = {}

func _ready():
    # Adiciona ao grupo main para ser encontrado pelos itens
    add_to_group("main")
    
    # Configurar inputs (importante para multiplayer)
    const InputSetupScript := preload("res://scripts/input_setup.gd")
    InputSetupScript.setup()
    
    # Criar containers se nÃ£o existirem
    if not players_container:
        players_container = Node2D.new()
        players_container.name = "PlayersContainer"
        add_child(players_container)
    
    if not map_container:
        map_container = Node.new()
        map_container.name = "MapContainer"
        add_child(map_container)
    
    # HUD serÃ¡ criado no setup_multiplayer() para evitar duplicaÃ§Ã£o
    # InicializaÃ§Ã£o do HUD movida para setup_multiplayer()
    
    # sfx
    _setup_sfx_players()
    
    # UI bÃ¡sica multiplayer (mantÃ©m contador de jogadores)
    if not ui_container:
        ui_container = CanvasLayer.new()
        ui_container.name = "UIContainer"
        add_child(ui_container)
        
        # Adicionar UI bÃ¡sica
        _setup_ui()
    
    # NOTA: O mapa inicial da cidade serÃ¡ carregado apÃ³s setup_multiplayer()

func _log(message: String):
    """Log local apenas (servidor-side nÃ£o precisa de logs do cliente)"""
    print(message)

func setup_multiplayer(manager: MultiplayerManager):
    """Configura o multiplayer com o manager recebido"""
    multiplayer_manager = manager
    
    # Mover manager para esta cena (sÃ³ se nÃ£o estiver jÃ¡ aqui)
    if multiplayer_manager.get_parent() != self:
        if multiplayer_manager.get_parent():
            multiplayer_manager.get_parent().remove_child(multiplayer_manager)
        add_child(multiplayer_manager)
    
    # Conectar sinais
    _log("ðŸ”— Conectando sinais do MultiplayerManager...")
    _log("ðŸ”— DEBUG: Manager existe? " + str(multiplayer_manager != null))
    
    var connect_result = multiplayer_manager.player_connected.connect(_on_player_connected)
    _log("ðŸ”— DEBUG: connect() retornou: " + str(connect_result) + " (0=sucesso)")
    if connect_result == OK:
        _log("âœ… Sinal player_connected conectado!")
    else:
        _log("âŒ ERRO ao conectar sinal player_connected! CÃ³digo: " + str(connect_result))
    
    # Verificar se o sinal estÃ¡ mesmo conectado
    var signal_connected = multiplayer_manager.player_connected.is_connected(_on_player_connected)
    _log("ðŸ”— DEBUG: Sinal conectado? " + str(signal_connected))
    
    multiplayer_manager.player_disconnected.connect(_on_player_disconnected)
    multiplayer_manager.player_sync_received.connect(_on_player_sync_received) 
    multiplayer_manager.map_change_received.connect(_on_player_map_changed)
    if multiplayer_manager.has_signal("players_list_received"):
        multiplayer_manager.players_list_received.connect(_on_players_list_received)
    if multiplayer_manager.has_signal("player_left_map_received"):
        multiplayer_manager.player_left_map_received.connect(_on_player_left_map_received)
    if multiplayer_manager.has_signal("xp_gain_received"):
        multiplayer_manager.xp_gain_received.connect(_on_xp_gain_received)
    if multiplayer_manager.has_signal("level_up_received"):
        multiplayer_manager.level_up_received.connect(_on_level_up_received)
    if multiplayer_manager.has_signal("player_stats_update_received"):
        multiplayer_manager.player_stats_update_received.connect(_on_player_stats_update_received)
    if multiplayer_manager.has_signal("player_damage_received"):
        multiplayer_manager.player_damage_received.connect(_on_player_damage_received)
    multiplayer_manager.connection_lost.connect(_on_connection_lost)
    multiplayer_manager.server_reconciliation.connect(_on_server_reconciliation)
    _log("âœ… Todos os sinais conectados!")
    
    # Criar jogador local
    _create_local_player()
    
    # IMPORTANTE: Verificar se jÃ¡ existem jogadores conectados e criar eles
    _check_existing_players()
    
    # GARANTIR que map_container existe antes de carregar a cidade
    if not map_container:
        map_container = Node.new()
        map_container.name = "MapContainer"
        add_child(map_container)
        _log("ðŸ—‚ï¸ map_container criado no setup_multiplayer()")
    
    # GARANTIR que HUD existe antes de carregar a cidade
    if not hud:
        _log("ðŸ—ï¸ Criando HUD no setup_multiplayer() pois nÃ£o existe")
        var HUD = load("res://scripts/hud.gd")
        hud = HUD.new()
        add_child(hud)
        
        # Aguardar atÃ© estar na Ã¡rvore de cenas
        call_deferred("_finish_setup_multiplayer")
        hud.update_xp(player_xp, player_xp_max)
        hud.set_map_title("Cidade - Multiplayer")
    
    _log("ðŸŽ® Setup inicial completo, aguardando finalizaÃ§Ã£o...")

func _check_existing_players():
    """Verifica se jÃ¡ existem jogadores conectados e os cria"""
    _log("ðŸ” VERIFICANDO jogadores jÃ¡ existentes...")
    
    if not multiplayer_manager:
        _log("âŒ Manager nÃ£o existe para verificaÃ§Ã£o")
        return
    
    var players_data = multiplayer_manager.get_players_data()
    var my_id = multiplayer_manager.get_local_player_id()
    
    _log("ðŸ” Players data disponÃ­vel: " + str(players_data.keys()))
    _log("ðŸ” Meu ID local: " + my_id)
    
    for player_id in players_data.keys():
        if player_id != my_id:
            var player_info = players_data[player_id]
            _log("ðŸ” ENCONTRADO jogador existente: " + player_info.get("name", "") + " (ID: " + player_id + ")")
            _log("ðŸ” FORÃ‡ANDO criaÃ§Ã£o via _on_player_connected...")
            
            # ForÃ§ar criaÃ§Ã£o do jogador remoto
            _on_player_connected(player_info)

func _create_local_player():
    """Cria o jogador local"""
    local_player = PLAYER_SCENE.instantiate()
    local_player.name = "LocalPlayer"
    
    # Configurar como jogador local
    local_player.setup_player(
        multiplayer_manager.get_local_player_id(),
        multiplayer_manager.get_local_player_name(),
        true  # is_local
    )
    
    # Definir referÃªncia ao multiplayer_manager
    local_player.multiplayer_manager = multiplayer_manager
    
    # Conectar sinais do player
    local_player.player_update.connect(_on_local_player_update)
    local_player.player_update_with_sequence.connect(_on_local_player_update_with_sequence)
    local_player.player_action.connect(_on_local_player_action)
    
    # Atualizar HP mÃ¡ximo baseado nos atributos (deferred para garantir que estÃ¡ na Ã¡rvore)
    if local_player.has_method("update_max_hp"):
        local_player.call_deferred("update_max_hp")
    
    # Garantir que players_container existe
    if not players_container:
        players_container = Node2D.new()
        players_container.name = "PlayersContainer"
        add_child(players_container)
    
    players_container.add_child(local_player)
    
    # Posicionar player usando posiÃ§Ã£o do servidor
    var player_info = multiplayer_manager.local_player_info
    if player_info and "position" in player_info:
        var pos = player_info.position
        if pos and "x" in pos and "y" in pos:
            local_player.global_position = Vector2(pos.x, pos.y)
            _log("ðŸ™ï¸ Player local posicionado do servidor: (" + str(pos.x) + ", " + str(pos.y) + ")")
        else:
            # Fallback para posiÃ§Ã£o padrÃ£o
            local_player.global_position = Vector2(100, 300)
            _log("ðŸ™ï¸ Player local posicionado padrÃ£o: (100, 300)")
    else:
        # PosiÃ§Ã£o padrÃ£o alinhada com servidor
        local_player.global_position = Vector2(100, 300)
        _log("ðŸ™ï¸ Player local posicionado sem server info: (100, 300)")
    
    _log("ðŸ‘¤ Jogador local criado: " + multiplayer_manager.get_local_player_name())

func _on_player_connected(player_info: Dictionary):
    """Callback quando novo jogador conecta"""
    _log("ðŸš¨ DEBUG: _on_player_connected INICIADO!")
    var player_id = player_info.get("id", "")
    var player_name = player_info.get("name", "")
    
    _log("ðŸ“¨ _on_player_connected chamado para: " + player_name + " (ID: " + player_id + ")")
    _log("ðŸ“¨ Jogador atual: " + multiplayer_manager.get_local_player_name())
    _log("ðŸ“¨ player_info completo: " + str(player_info))
    
    if player_id.is_empty():
        _log("âŒ Player ID vazio, ignorando")
        return
    
    # Verificar se jÃ¡ existe
    if player_id in remote_players:
        _log("âš ï¸ Player " + player_name + " jÃ¡ existe, removendo primeiro")
        var old_player = remote_players[player_id]
        players_container.remove_child(old_player)
        old_player.queue_free()
        remote_players.erase(player_id)
    
    # Criar jogador remoto
    var remote_player = PLAYER_SCENE.instantiate()
    remote_player.name = "Player_" + player_id
    
    # Configurar como jogador remoto
    remote_player.setup_player(player_id, player_name, false)
    
    # Definir referÃªncia ao multiplayer_manager
    remote_player.multiplayer_manager = multiplayer_manager
    
    players_container.add_child(remote_player)
    remote_players[player_id] = remote_player
    
    _log("ðŸ” ADICIONADO ao remote_players: " + player_id + " | DicionÃ¡rio agora tem: " + str(remote_players.keys()))
    _log("ðŸ” Tamanho do remote_players: " + str(remote_players.size()))
    
    # Posicionar player remoto exatamente como o servidor define
    if "position" in player_info:
        var pos = player_info.position
        if pos and "x" in pos and "y" in pos:
            remote_player.global_position = Vector2(pos.x, pos.y)
            _log("ðŸ“ Player " + player_name + " posicionado do servidor: " + str(Vector2(pos.x, pos.y)))
        else:
            # Usar mesma posiÃ§Ã£o padrÃ£o que servidor (100, 300)
            remote_player.global_position = Vector2(100, 300)
            _log("ðŸ“ Player " + player_name + " posicionado padrÃ£o servidor: (100, 300)")
    else:
        # PosiÃ§Ã£o padrÃ£o alinhada com servidor
        remote_player.global_position = Vector2(100, 300)
        _log("ðŸ“ Player " + player_name + " posicionado sem posiÃ§Ã£o servidor: (100, 300)")
    
    # IMPORTANTE: Verificar posiÃ§Ã£o final apÃ³s posicionamento
    _log("ðŸ” PosiÃ§Ã£o final de " + player_name + ": " + str(remote_player.global_position))
    
    # Definir mapa padrÃ£o para novo player remoto (assumir que estÃ¡ na cidade)
    remote_player.set_meta("current_map", "Cidade")
    
    # Verificar visibilidade inicial baseada no mapa atual
    if current_map == "Cidade":
        # Ambos na cidade, ativar completamente
        remote_player.visible = true
        remote_player.set_physics_process(true)
        remote_player.set_process(true)
        remote_player.collision_layer = 1
        remote_player.collision_mask = 7
        _log("ðŸ‘ï¸ Player remoto " + player_name + " ATIVADO (ambos na Cidade)")
    else:
        # Eu nÃ£o estou na cidade, desativar player remoto
        remote_player.visible = false
        remote_player.set_physics_process(false)
        remote_player.set_process(false)
        remote_player.collision_layer = 0
        remote_player.collision_mask = 0
        remote_player.global_position = Vector2(99999, 99999)
        _log("ðŸš« Player remoto " + player_name + " DESATIVADO (eu estou em " + current_map + ", ele na Cidade)")
    
    _log("ðŸ‘¥ Jogador remoto criado: " + player_name + " | Total players: " + str(remote_players.size() + 1))

func _on_player_disconnected(player_id: String):
    """Callback quando jogador desconecta"""
    _log("ðŸ“¨ _on_player_disconnected chamado para ID: " + player_id)
    if player_id in remote_players:
        var player_node = remote_players[player_id]
        var player_name = player_node.player_name if player_node else "Unknown"
        players_container.remove_child(player_node)
        player_node.queue_free()
        remote_players.erase(player_id)
        
        _log("ðŸ‘‹ Jogador remoto removido: " + player_name + " (ID: " + player_id + ") | Restantes: " + str(remote_players.size()))

func _on_player_sync_received(player_id: String, player_data: Dictionary):
    """Callback quando recebe sincronizaÃ§Ã£o de jogador"""
    if player_id not in remote_players:
        return
    
    var remote_player = remote_players[player_id]
    
    # SÃ³ aplicar sincronizaÃ§Ã£o se o player estiver no mesmo mapa (ativo)
    var player_map = remote_player.get_meta("current_map", "Cidade")
    if player_map == current_map:
        remote_player.apply_sync_data(player_data)
        # _log("ðŸ”„ SincronizaÃ§Ã£o aplicada para player " + player_id + " (mesmo mapa)")
    else:
        # _log("ðŸš« SincronizaÃ§Ã£o ignorada para player " + player_id + " (mapas diferentes)")
        pass

func _on_player_map_changed(player_id: String, player_map: String):
    """Callback quando um player remoto muda de mapa"""
    _log("ðŸ—ºï¸ RECEBIDO mudanÃ§a de mapa: Player " + player_id + " mudou para: " + player_map)
    _log("ðŸ—ºï¸ DEBUG: Meu current_map Ã©: " + current_map)
    
    if player_id in remote_players:
        var remote_player = remote_players[player_id]
        var old_map = remote_player.get_meta("current_map", "Cidade")
        
        # Armazenar o mapa atual do player remoto
        remote_player.set_meta("current_map", player_map)
        _log("ðŸ—ºï¸ DEBUG: Player " + player_id + " mudou de '" + old_map + "' para '" + player_map + "'")
        
        # Mostrar/esconder player baseado no mapa
        if player_map == current_map:
            # Player estÃ¡ no mesmo mapa, ativar completamente
            remote_player.visible = true
            remote_player.set_physics_process(true)
            remote_player.set_process(true)
            remote_player.collision_layer = 1  # Reativar colisÃ£o
            remote_player.collision_mask = 7   # Reativar detecÃ§Ã£o
            
            # Atualizar posiÃ§Ã£o do player remoto com spawn do novo mapa
            var player_data = multiplayer_manager.get_players_data().get(player_id, {})
            if "position" in player_data:
                var pos = player_data.position
                if "x" in pos and "y" in pos:
                    remote_player.global_position = Vector2(pos.x, pos.y)
                    _log("ðŸ“ Player " + player_id + " reposicionado para spawn: " + str(remote_player.global_position))
            
            _log("ðŸ‘ï¸ ATIVANDO Player " + player_id + " (mesmo mapa: " + player_map + ")")
        else:
            # Player estÃ¡ em mapa diferente, desativar completamente
            remote_player.visible = false
            remote_player.set_physics_process(false)
            remote_player.set_process(false)
            remote_player.collision_layer = 0  # Desativar colisÃ£o
            remote_player.collision_mask = 0   # Desativar detecÃ§Ã£o
            # Mover para posiÃ§Ã£o muito distante para evitar interferÃªncias
            remote_player.global_position = Vector2(99999, 99999)
            _log("ðŸš« DESATIVANDO Player " + player_id + " (mapas diferentes: " + player_map + " vs " + current_map + ")")
    else:
        _log("âŒ Player " + player_id + " nÃ£o encontrado em remote_players para atualizar mapa!")

func _update_remote_players_visibility():
    """Atualiza visibilidade de todos os players remotos baseado no mapa atual"""
    _log("ðŸ”„ ATUALIZANDO visibilidade de " + str(remote_players.size()) + " players remotos para mapa " + current_map)
    
    for player_id in remote_players.keys():
        var remote_player = remote_players[player_id]
        var player_map = remote_player.get_meta("current_map", "Cidade")  # PadrÃ£o cidade
        
        _log("ðŸ”„ Player " + player_id + " estÃ¡ em: " + player_map + " | Eu estou em: " + current_map)
        
        if player_map == current_map:
            # Player estÃ¡ no mesmo mapa, ativar completamente
            remote_player.visible = true
            remote_player.set_physics_process(true)
            remote_player.set_process(true)
            remote_player.collision_layer = 1  # Reativar colisÃ£o
            remote_player.collision_mask = 7   # Reativar detecÃ§Ã£o
            
            # Reposicionar player remoto para spawn correto do mapa atual
            var player_data = multiplayer_manager.get_players_data().get(player_id, {})
            if "position" in player_data:
                var pos = player_data.position
                if "x" in pos and "y" in pos:
                    remote_player.global_position = Vector2(pos.x, pos.y)
                    _log("ðŸ“ Player " + player_id + " reposicionado: " + str(remote_player.global_position))
            
            _log("ðŸ‘ï¸ ATIVANDO Player " + player_id + " no mapa " + current_map)
        else:
            # Player estÃ¡ em mapa diferente, desativar completamente
            remote_player.visible = false
            remote_player.set_physics_process(false)
            remote_player.set_process(false)
            remote_player.collision_layer = 0  # Desativar colisÃ£o
            remote_player.collision_mask = 0   # Desativar detecÃ§Ã£o
            # Mover para posiÃ§Ã£o muito distante para evitar interferÃªncias
            remote_player.global_position = Vector2(99999, 99999)
            _log("ðŸš« DESATIVANDO Player " + player_id + " (estÃ¡ em " + player_map + ", eu estou em " + current_map + ")")

func _on_local_player_update(pos: Vector2, velocity: Vector2, animation: String, facing: int, hp: int):
    """Callback quando jogador local se move"""
    if multiplayer_manager:
        multiplayer_manager.send_player_update(pos, velocity, animation, facing, hp)

func _on_local_player_update_with_sequence(pos: Vector2, velocity: Vector2, animation: String, facing: int, hp: int, sequence: int):
    """Callback quando jogador local se move com sequence"""
    if multiplayer_manager:
        multiplayer_manager.send_player_update_with_sequence(pos, velocity, animation, facing, hp, sequence)

func _on_local_player_action(action: String, action_data: Dictionary):
    """Callback quando jogador local faz uma aÃ§Ã£o"""
    if multiplayer_manager:
        multiplayer_manager.send_player_action(action, action_data)

func _on_connection_lost():
    """Callback quando perde conexÃ£o"""
    _log("ðŸ”Œ _on_connection_lost() chamado - mostrando tela de erro")
    # Mostrar tela de erro e voltar ao login
    _show_connection_error()

func _on_server_reconciliation(reconciliation_data: Dictionary):
    """Callback para reconciliaÃ§Ã£o do servidor"""
    # Applying server reconciliation
    if local_player:
        _log("ðŸ”„ Chamando apply_sync_data() no local_player")
        local_player.apply_sync_data(reconciliation_data)
    else:
        _log("âŒ local_player Ã© null!")

func _show_connection_error():
    """Mostra erro de conexÃ£o e volta ao login"""
    # Evitar mÃºltiplas janelas de erro
    if connection_error_shown:
        return
    
    connection_error_shown = true
    _log("âŒ ConexÃ£o perdida! Voltando ao login...")
    
    # Verificar se jÃ¡ existe uma janela de erro
    var existing_dialog = ui_container.get_node_or_null("ConnectionErrorDialog")
    if existing_dialog:
        existing_dialog.queue_free()
    
    # Criar tela de erro
    var error_dialog = AcceptDialog.new()
    error_dialog.name = "ConnectionErrorDialog"
    error_dialog.dialog_text = "ConexÃ£o com o servidor perdida!\nVoltando Ã  tela de login..."
    error_dialog.title = "Erro de ConexÃ£o"
    
    ui_container.add_child(error_dialog)
    error_dialog.popup_centered()
    
    # Aguardar OK e voltar ao login
    await error_dialog.confirmed
    error_dialog.queue_free()
    _return_to_login()

func _return_to_login():
    """Volta Ã  tela de login"""
    var tree = get_tree()
    if tree == null:
        _log("âš ï¸ get_tree() null em _return_to_login(), nÃ£o conseguindo voltar ao login")
        return
    
    # Usar mÃ©todo mais confiÃ¡vel para voltar ao login
    _log("ðŸ”„ Voltando Ã  tela de login...")
    var scene_result = tree.change_scene_to_file("res://login_multiplayer.tscn")
    if scene_result != OK:
        _log("âŒ Falha ao mudar para cena de login: " + str(scene_result))
        # Ãšltima tentativa: recarregar a cena atual
        tree.reload_current_scene()

func _setup_ui():
    """Configura UI bÃ¡sica do jogo"""
    var ui_label = Label.new()
    ui_label.text = "ðŸŽ® PROJETO ALLY - MULTIPLAYER ONLINE"
    ui_label.position = Vector2(10, 10)
    ui_label.add_theme_color_override("font_color", Color.WHITE)
    ui_container.add_child(ui_label)
    
    # Status de conexÃ£o
    var status_label = Label.new()
    status_label.name = "StatusLabel"
    status_label.text = "ðŸŸ¢ Conectado"
    status_label.position = Vector2(10, 40)
    status_label.add_theme_color_override("font_color", Color.GREEN)
    ui_container.add_child(status_label)
    
    # Contador de jogadores
    var players_label = Label.new()
    players_label.name = "PlayersLabel"
    players_label.text = "Jogadores: 1"
    players_label.position = Vector2(10, 70)
    players_label.add_theme_color_override("font_color", Color.WHITE)
    ui_container.add_child(players_label)

func _process(_delta):
    # Atualizar UI
    # Ataque local (delegado ao servidor)
    if Input.is_action_just_pressed("attack"):
        if local_player and current_map_node and current_map_node.has_method("handle_player_attack"):
            var dir := -1.0 if (local_player.sprite and local_player.sprite.flip_h) else 1.0
            var atk_pos := local_player.global_position + Vector2(14.0 * dir, 0.0)
            var dmg := int(get_player_damage())
            current_map_node.handle_player_attack(atk_pos, dmg)
    if ui_container:
        var players_label = ui_container.get_node_or_null("PlayersLabel")
        if players_label:
            var total_players = 1 + remote_players.size()  # Local + remotes
            players_label.text = "Jogadores: %d" % total_players
            
            # Debug da contagem (log apenas quando muda)
            if players_label.has_meta("last_count"):
                var last_count = players_label.get_meta("last_count")
                if last_count != total_players:
                    _log("ðŸŽ® UI ATUALIZADA: Total players mudou de " + str(last_count) + " para " + str(total_players))
                    _log("ðŸŽ® UI DEBUG: remote_players.size() = " + str(remote_players.size()) + ", keys = " + str(remote_players.keys()))
                    players_label.set_meta("last_count", total_players)
            else:
                _log("ðŸŽ® UI INICIAL: Total players = " + str(total_players))
                players_label.set_meta("last_count", total_players)

# === FUNÃ‡Ã•ES DO SISTEMA V2.2 INTEGRADAS ===

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

# ---- LÃ³gica de jogo / HUD ----
func reset_player() -> void:
    player_hp = player_hp_max
    if hud:
        hud.update_health(player_hp, player_hp_max)
    else:
        _log("âš ï¸ HUD null em reset_player()")

func damage_player(amount: int, hit_world_pos: Vector2 = Vector2.ZERO) -> void:
    # Calcula dano final com defesa
    var final_damage = max(1, amount - get_damage_reduction())  # MÃ­nimo 1 de dano
    
    player_hp = max(0, player_hp - final_damage)
    if hud:
        hud.update_health(player_hp, player_hp_max)
    play_sfx_id("hurt")
    show_damage_popup_at_world(hit_world_pos, "-" + str(final_damage), Color(1, 0.3, 0.3, 1.0))

    if player_hp <= 0:
        var tree = get_tree()
        if tree:
            await tree.process_frame
        load_city()
        if hud:
            hud.set_subtitle("")
            hud.show_popup("VocÃª morreu e voltou para a cidade.")
        # Removido play_sfx_id - nÃ£o implementado no multiplayer

func load_city() -> void:
    _clear_map()
    current_map = "Cidade"  # Atualizar mapa atual
    var City = load("res://scripts/city_map_multiplayer.gd")
    var city = City.new()
    map_container.add_child(city)
    city.setup(self)
    # Verificar se HUD estÃ¡ disponÃ­vel antes de usar
    if hud:
        hud.set_map_title("Cidade - Multiplayer")
        hud.set_subtitle("")
    else:
        _log("âš ï¸ HUD null em load_city()")
    
    # Notificar servidor sobre mudanÃ§a de mapa (com delay para estabilizar conexÃ£o)
    if multiplayer_manager:
        _log("ðŸ“¡ Aguardando 1 segundo antes de enviar map_change...")
        await get_tree().create_timer(1.0).timeout
        _log("ðŸ“¡ Verificando se ainda conectado antes de enviar...")
        if multiplayer_manager.socket_connected and multiplayer_manager.is_logged_in:
            multiplayer_manager.send_map_change("Cidade")
            _log("ðŸ“¡ ENVIADO para servidor: mudanÃ§a para Cidade")
            _log("ðŸ“¡ DEBUG: Meu current_map agora Ã©: " + current_map)
        else:
            _log("âŒ CANCELADO envio de map_change - nÃ£o conectado")
    
    # Atualizar visibilidade dos players remotos
    _update_remote_players_visibility()

func load_forest() -> void:
    _clear_map()
    current_map = "Floresta"  # Atualizar mapa atual
    var Forest = load("res://scripts/forest_map_multiplayer.gd")
    var forest = Forest.new()
    map_container.add_child(forest)
    forest.setup(self)
    _position_players_in_forest()
    current_map_node = forest  # ReferÃªncia para o mapa atual
    _log("ðŸŒ² Floresta carregada! Sistema server-side ativo.")
    
    # Verificar se HUD estÃ¡ disponÃ­vel antes de usar
    if hud:
        hud.set_map_title("Floresta - Multiplayer")
    else:
        _log("âš ï¸ HUD null em load_forest()")
    
    # Notificar servidor sobre mudanÃ§a de mapa (com delay para estabilizar conexÃ£o)
    if multiplayer_manager:
        _log("ðŸ“¡ Aguardando 1 segundo antes de enviar map_change...")
        await get_tree().create_timer(1.0).timeout
        _log("ðŸ“¡ Verificando se ainda conectado antes de enviar...")
        if multiplayer_manager.socket_connected and multiplayer_manager.is_logged_in:
            multiplayer_manager.send_map_change("Floresta")
            _log("ðŸ“¡ ENVIADO para servidor: mudanÃ§a para Floresta")
            _log("ðŸ“¡ DEBUG: Meu current_map agora Ã©: " + current_map)
        else:
            _log("âŒ CANCELADO envio de map_change - nÃ£o conectado")
    
    # Atualizar visibilidade dos players remotos
    _update_remote_players_visibility()
    
    # Aguardar um frame para garantir que o mapa foi construÃ­do (se possÃ­vel)
    var tree = get_tree()
    if tree:
        await tree.process_frame
    else:
        _log("âš ï¸ get_tree() null em load_forest(), nÃ£o aguardando frame")
    
    # Posicionar players multiplayer na floresta
    _position_players_in_forest()
    _log("ðŸŽ¯ Players posicionados na floresta. Podem atacar inimigos!")

func _position_players_in_city() -> void:
    """Posiciona APENAS o player local na cidade (preserva posiÃ§Ã£o do servidor se vÃ¡lida)"""
    # Verificar se o player jÃ¡ tem uma posiÃ§Ã£o vÃ¡lida do servidor
    if local_player:
        var current_pos = local_player.global_position
        
        # Se o player jÃ¡ estÃ¡ numa posiÃ§Ã£o vÃ¡lida (nÃ£o em (0,0) e nÃ£o muito distante), preservar
        if current_pos != Vector2.ZERO and current_pos.length() > 10.0:
            _log("ðŸ™ï¸ Player local jÃ¡ posicionado em: " + str(current_pos) + " (preservando posiÃ§Ã£o do servidor)")
            return
    
    # Caso contrÃ¡rio, usar posiÃ§Ã£o padrÃ£o da cidade
    var viewport = get_viewport()
    var vp: Vector2
    if viewport == null:
        vp = Vector2(1024, 768)  # Tamanho padrÃ£o se nÃ£o tiver viewport
        _log("âš ï¸ Viewport null em _position_players_in_city(), usando tamanho padrÃ£o")
    else:
        vp = viewport.get_visible_rect().size
    
    var stand_y: float = (vp.y * 0.5 - 150.0) - 20.0  # BOTTOM_MARGIN da cidade
    
    # Posicionar APENAS jogador local com posiÃ§Ã£o padrÃ£o
    if local_player:
        local_player.global_position = Vector2(0.0, stand_y)
        local_player.velocity = Vector2.ZERO
        _log("ðŸ™ï¸ Player local posicionado na cidade (posiÃ§Ã£o padrÃ£o): " + str(local_player.global_position))
    
    # NÃƒO mover players remotos - eles estÃ£o em suas prÃ³prias instÃ¢ncias!

func _position_players_in_forest() -> void:
    """Posiciona APENAS o player local na floresta"""
    var viewport = get_viewport()
    var vp: Vector2
    if viewport == null:
        vp = Vector2(1024, 768)  # Tamanho padrÃ£o se nÃ£o tiver viewport
        _log("âš ï¸ Viewport null em _position_players_in_forest(), usando tamanho padrÃ£o")
    else:
        vp = viewport.get_visible_rect().size
    
    var stand_y: float = (vp.y * 0.5 - 120.0) - 20.0  # BOTTOM_MARGIN da floresta
    var left_x: float = -vp.x * 0.5 + 64.0
    
    # Posicionar APENAS jogador local na floresta
    if local_player:
        local_player.global_position = Vector2(left_x, stand_y)
        local_player.velocity = Vector2.ZERO
        _log("ðŸŒ² Player local posicionado na floresta: " + str(local_player.global_position))
    
    # NÃƒO mover players remotos - eles estÃ£o em suas prÃ³prias instÃ¢ncias!

func _clear_map() -> void:
    if map_container != null:
        for c in map_container.get_children():
            c.queue_free()
        current_map_node = null  # Limpar referÃªncia
    else:
        _log("âš ï¸ map_container Ã© null em _clear_map()")

func _on_select_map(map_name: String) -> void:
    _log("ðŸ—ºï¸ MudanÃ§a de mapa solicitada: " + map_name)
    match map_name:
        "Floresta":
            _log("ðŸŒ² Carregando floresta...")
            load_forest()
        _:
            _log("âš ï¸ Mapa nÃ£o reconhecido: " + map_name)
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
        var tree = get_tree()
        if tree:
            await tree.process_frame
        load_city()
        if hud:
            hud.show_popup("Mapa completo! VocÃª voltou para a cidade.")
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
    player_xp_max = int(player_xp_max * 1.2)  # Aumenta 20% XP necessÃ¡rio
    
    # Ganha 5 pontos de atributo
    available_points += 5
    
    hud.update_xp(player_xp, player_xp_max)
    
    # Mostra mensagem flutuante acima do player
    _show_level_up_message()

# ---- Handlers de eventos do servidor (XP/Level/Stats) ----
func _on_xp_gain_received(player_id: String, amount: int, xp: int, xp_max_s: int) -> void:
    if not multiplayer_manager:
        return
    var my_id = multiplayer_manager.get_local_player_id()
    if player_id != my_id:
        return
    player_xp = xp
    player_xp_max = xp_max_s
    if hud:
        hud.update_xp(player_xp, player_xp_max)
    if local_player:
        show_damage_popup_at_world(local_player.global_position + Vector2(0, -60), "+" + str(amount) + " XP", Color(0.2, 0.8, 1.0, 1))

func _on_level_up_received(player_id: String, new_level: int, available_pts: int, xp_max_s: int) -> void:
    if not multiplayer_manager:
        return
    var my_id = multiplayer_manager.get_local_player_id()
    if player_id != my_id:
        return
    player_level = new_level
    available_points = available_pts
    player_xp_max = xp_max_s
    if hud:
        hud.update_xp(player_xp, player_xp_max)
    _show_level_up_message()

func _on_player_stats_update_received(player_id: String, stats: Dictionary) -> void:
    if not multiplayer_manager:
        return
    var my_id = multiplayer_manager.get_local_player_id()
    if player_id != my_id:
        return
    player_level = int(stats.get("level", player_level))
    player_xp = int(stats.get("xp", player_xp))
    player_xp_max = int(stats.get("xp_max", player_xp_max))
    available_points = int(stats.get("attr_points", available_points))
    player_hp = int(stats.get("hp", player_hp))
    player_hp_max = int(stats.get("hp_max", player_hp_max))
    var attrs = stats.get("attributes", {})
    if typeof(attrs) == TYPE_DICTIONARY:
        player_strength = int(attrs.get("strength", player_strength))
        player_defense = int(attrs.get("defense", player_defense))
        player_intelligence = int(attrs.get("intelligence", player_intelligence))
        player_vitality = int(attrs.get("vitality", player_vitality))
    if hud:
        hud.update_xp(player_xp, player_xp_max)
        hud.update_health(player_hp, player_hp_max)

func get_player_level() -> int:
    return player_level

# ---- Sistema de Atributos ----
func _calculate_max_hp() -> void:
    var base_hp = 100
    player_hp_max = base_hp + (player_vitality * 20)
    player_hp = min(player_hp, player_hp_max)  # NÃ£o deixa HP atual maior que mÃ¡ximo

func get_player_damage() -> int:
    var base_damage = 34
    var weapon_damage = 0
    
    # Adiciona dano da arma equipada
    if not equipped_weapon.is_empty():
        weapon_damage = equipped_weapon.get("damage", 0)
    
    return base_damage + player_strength + weapon_damage

func get_damage_reduction() -> int:
    return player_defense

func get_player_stats() -> Dictionary:
    return {
        "level": player_level,
        "hp": player_hp,
        "hp_max": player_hp_max,
        "xp": player_xp,
        "xp_max": player_xp_max,
        "strength": player_strength,
        "defense": player_defense,
        "intelligence": player_intelligence,
        "vitality": player_vitality,
        "available_points": available_points
    }

func _on_player_damage_received(player_id: String, damage: int, hp: int, hp_max: int, _enemy_id: String) -> void:
    if not multiplayer_manager:
        return
    var my_id = multiplayer_manager.get_local_player_id()
    if player_id != my_id:
        return
    player_hp = hp
    player_hp_max = hp_max
    if hud:
        hud.update_health(player_hp, player_hp_max)
    if local_player:
        show_damage_popup_at_world(local_player.global_position, "-" + str(damage), Color(1, 0.3, 0.3, 1))

func add_attribute_point(attribute: String) -> void:
    if multiplayer_manager and multiplayer_manager.is_logged_in:
        var msg := {"type": "spend_attribute_point", "attr": attribute}
        multiplayer_manager._send_message(msg)
    # HUD/valores virão do servidor via player_stats_update_received

# ---- Sistema de InventÃ¡rio ----
func _initialize_inventory() -> void:
    inventory_slots.clear()
    for i in range(MAX_INVENTORY_SLOTS):
        inventory_slots.append({})  # Slot vazio

func add_item_to_inventory(item: Dictionary) -> bool:
    # Procura slot vazio
    for i in range(inventory_slots.size()):
        if inventory_slots[i].is_empty():
            inventory_slots[i] = item
            return true
    return false  # InventÃ¡rio cheio

func remove_item_from_inventory(slot_index: int) -> Dictionary:
    if slot_index >= 0 and slot_index < inventory_slots.size():
        var item = inventory_slots[slot_index]
        inventory_slots[slot_index] = {}
        return item
    return {}

func equip_weapon(slot_index: int) -> void:
    var item = inventory_slots[slot_index]
    if item.get("type", "") == "weapon":
        # Remove arma atual se houver
        if not equipped_weapon.is_empty():
            add_item_to_inventory(equipped_weapon)
        
        # Equipa nova arma
        equipped_weapon = item
        inventory_slots[slot_index] = {}

func unequip_weapon() -> void:
    if not equipped_weapon.is_empty():
        if add_item_to_inventory(equipped_weapon):
            equipped_weapon = {}

func get_inventory_data() -> Dictionary:
    return {
        "slots": inventory_slots,
        "equipped_weapon": equipped_weapon
    }

# ---- Sistema de Auto Attack ----
func set_auto_attack(enabled: bool) -> void:
    auto_attack_enabled = enabled
    
    # Propagar para o player local
    if local_player and local_player.has_method("set_auto_attack"):
        local_player.set_auto_attack(enabled)

func get_auto_attack_enabled() -> bool:
    return auto_attack_enabled

func _show_level_up_message() -> void:
    # Encontra o player local
    if local_player:
        var player_pos = local_player.global_position + Vector2(0, -40)  # 40 pixels acima do player
        show_damage_popup_at_world(player_pos, "LEVEL UP! NÃ­vel %d" % player_level, Color(1, 1, 0, 1))  # Amarelo dourado

# ---- Dano flutuante (coordenadas de tela) ----
func show_damage_popup_at_world(world_pos: Vector2, txt: String, color: Color) -> void:
    if hud == null:
        _log("âš ï¸ HUD null em show_damage_popup_at_world(), nÃ£o mostrando popup: " + txt)
        return
    hud.show_damage_popup_at_world(world_pos, txt, color)

func _finish_setup_multiplayer() -> void:
    """Finaliza setup do multiplayer apÃ³s estar na Ã¡rvore de cenas"""
    var tree = get_tree()
    if tree == null:
        _log("âš ï¸ get_tree() ainda null em _finish_setup_multiplayer(), tentando novamente")
        call_deferred("_finish_setup_multiplayer")
        return
    
    # Aguardar um frame para que o _ready() do HUD seja executado
    await tree.process_frame
    
    # Agora configurar o HUD
    if hud:
        hud.on_select_map.connect(_on_select_map)
        hud.update_health(player_hp, player_hp_max)
    
    # Carregar mapa inicial
    load_city()

# ============================================================================
# MAP PRESENCE SIGNAL HANDLERS
# ============================================================================

func _on_players_list_received(players: Dictionary) -> void:
    # Lista do servidor contém apenas players do meu mapa atual
    for pid in players.keys():
        if multiplayer_manager and pid == multiplayer_manager.get_local_player_id():
            continue
        if pid in remote_players:
            remote_players[pid].set_meta("current_map", current_map)
        else:
            _on_player_connected(players[pid])
    _update_remote_players_visibility()

func _on_player_left_map_received(player_id: String) -> void:
    if player_id in remote_players:
        remote_players[player_id].set_meta("current_map", "OUTRO")
        _update_remote_players_visibility()
