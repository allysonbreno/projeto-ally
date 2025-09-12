extends Node2D

var multiplayer_manager: MultiplayerManager
var local_player: CharacterBody2D
var remote_players = {}
var current_map: String = "Cidade"  # Rastrear mapa atual
var current_map_node: Node = null  # Refer├â┬¬ncia ao n├â┬│ do mapa atual

# Refer├â┬¬ncias de cena
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
var player_strength: int = 5    # For├â┬ºa - aumenta dano
var player_defense: int = 5     # Defesa - reduz dano recebido
var player_intelligence: int = 5 # Intelig├â┬¬ncia (futuro uso)
var player_vitality: int = 5    # Vitalidade - aumenta HP
var available_points: int = 0   # Pontos dispon├â┬¡veis para distribuir

# Sistema de Invent├â┬írio
var inventory_slots: Array[Dictionary] = []  # 5 slots do invent├â┬írio
var equipped_weapon: Dictionary = {}         # Slot de equipamento da espada
const MAX_INVENTORY_SLOTS: int = 5

# Sistema de Auto Attack
var auto_attack_enabled: bool = false

# Controle de erro de conex├â┬úo
var connection_error_shown: bool = false

# --- ├â┬üudio ---
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
    
    # Criar containers se n├â┬úo existirem
    if not players_container:
        players_container = Node2D.new()
        players_container.name = "PlayersContainer"
        add_child(players_container)
    
    if not map_container:
        map_container = Node.new()
        map_container.name = "MapContainer"
        add_child(map_container)
    
    # HUD ser├â┬í criado no setup_multiplayer() para evitar duplica├â┬º├â┬úo
    # Inicializa├â┬º├â┬úo do HUD movida para setup_multiplayer()
    
    # sfx
    _setup_sfx_players()
    
    # UI b├â┬ísica multiplayer (mant├â┬®m contador de jogadores)
    if not ui_container:
        ui_container = CanvasLayer.new()
        ui_container.name = "UIContainer"
        add_child(ui_container)
        
        # Adicionar UI b├â┬ísica
        _setup_ui()
    
    # NOTA: O mapa inicial da cidade ser├â┬í carregado ap├â┬│s setup_multiplayer()

func _log(message: String):
    """Log local apenas (servidor-side n├â┬úo precisa de logs do cliente)"""
    print(message)

func setup_multiplayer(manager: MultiplayerManager):
    """Configura o multiplayer com o manager recebido"""
    multiplayer_manager = manager
    
    # Mover manager para esta cena (s├â┬│ se n├â┬úo estiver j├â┬í aqui)
    if multiplayer_manager.get_parent() != self:
        if multiplayer_manager.get_parent():
            multiplayer_manager.get_parent().remove_child(multiplayer_manager)
        add_child(multiplayer_manager)
    
    # Conectar sinais
    _log("├░┼©ÔÇØÔÇö Conectando sinais do MultiplayerManager...")
    _log("├░┼©ÔÇØÔÇö DEBUG: Manager existe? " + str(multiplayer_manager != null))
    
    var connect_result = multiplayer_manager.player_connected.connect(_on_player_connected)
    _log("├░┼©ÔÇØÔÇö DEBUG: connect() retornou: " + str(connect_result) + " (0=sucesso)")
    if connect_result == OK:
        _log("├ó┼ôÔÇª Sinal player_connected conectado!")
    else:
        _log("├ó┬Ø┼Æ ERRO ao conectar sinal player_connected! C├â┬│digo: " + str(connect_result))
    
    # Verificar se o sinal est├â┬í mesmo conectado
    var signal_connected = multiplayer_manager.player_connected.is_connected(_on_player_connected)
    _log("├░┼©ÔÇØÔÇö DEBUG: Sinal conectado? " + str(signal_connected))
    
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
    _log("├ó┼ôÔÇª Todos os sinais conectados!")
    
    # Criar jogador local
    _create_local_player()
    
    # IMPORTANTE: Verificar se j├â┬í existem jogadores conectados e criar eles
    _check_existing_players()
    
    # GARANTIR que map_container existe antes de carregar a cidade
    if not map_container:
        map_container = Node.new()
        map_container.name = "MapContainer"
        add_child(map_container)
        _log("├░┼©ÔÇöÔÇÜ├»┬©┬Å map_container criado no setup_multiplayer()")
    
    # GARANTIR que HUD existe antes de carregar a cidade
    if not hud:
        _log("├░┼©┬ÅÔÇö├»┬©┬Å Criando HUD no setup_multiplayer() pois n├â┬úo existe")
        var HUD = load("res://scripts/hud.gd")
        hud = HUD.new()
        add_child(hud)
        
        # Aguardar at├â┬® estar na ├â┬írvore de cenas
        call_deferred("_finish_setup_multiplayer")
        hud.update_xp(player_xp, player_xp_max)
        hud.set_map_title("Cidade - Multiplayer")
    
    _log("├░┼©┼¢┬« Setup inicial completo, aguardando finaliza├â┬º├â┬úo...")

func _check_existing_players():
    """Verifica se j├â┬í existem jogadores conectados e os cria"""
    _log("├░┼©ÔÇØ┬ì VERIFICANDO jogadores j├â┬í existentes...")
    
    if not multiplayer_manager:
        _log("├ó┬Ø┼Æ Manager n├â┬úo existe para verifica├â┬º├â┬úo")
        return
    
    var players_data = multiplayer_manager.get_players_data()
    var my_id = multiplayer_manager.get_local_player_id()
    
    _log("├░┼©ÔÇØ┬ì Players data dispon├â┬¡vel: " + str(players_data.keys()))
    _log("├░┼©ÔÇØ┬ì Meu ID local: " + my_id)
    
    for player_id in players_data.keys():
        if player_id != my_id:
            var player_info = players_data[player_id]
            _log("├░┼©ÔÇØ┬ì ENCONTRADO jogador existente: " + player_info.get("name", "") + " (ID: " + player_id + ")")
            _log("├░┼©ÔÇØ┬ì FOR├âÔÇíANDO cria├â┬º├â┬úo via _on_player_connected...")
            
            # For├â┬ºar cria├â┬º├â┬úo do jogador remoto
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
    
    # Definir refer├â┬¬ncia ao multiplayer_manager
    local_player.multiplayer_manager = multiplayer_manager
    
    # Conectar sinais do player
    local_player.player_update.connect(_on_local_player_update)
    local_player.player_update_with_sequence.connect(_on_local_player_update_with_sequence)
    local_player.player_action.connect(_on_local_player_action)
    
    # Atualizar HP m├â┬íximo baseado nos atributos (deferred para garantir que est├â┬í na ├â┬írvore)
    if local_player.has_method("update_max_hp"):
        local_player.call_deferred("update_max_hp")
    
    # Garantir que players_container existe
    if not players_container:
        players_container = Node2D.new()
        players_container.name = "PlayersContainer"
        add_child(players_container)
    
    players_container.add_child(local_player)
    
    # Posicionar player usando posi├â┬º├â┬úo do servidor
    var player_info = multiplayer_manager.local_player_info
    if player_info and "position" in player_info:
        var pos = player_info.position
        if pos and "x" in pos and "y" in pos:
            local_player.global_position = Vector2(pos.x, pos.y)
            _log("├░┼©┬ÅÔäó├»┬©┬Å Player local posicionado do servidor: (" + str(pos.x) + ", " + str(pos.y) + ")")
        else:
            # Fallback para posi├â┬º├â┬úo padr├â┬úo
            local_player.global_position = Vector2(100, 300)
            _log("├░┼©┬ÅÔäó├»┬©┬Å Player local posicionado padr├â┬úo: (100, 300)")
    else:
        # Posi├â┬º├â┬úo padr├â┬úo alinhada com servidor
        local_player.global_position = Vector2(100, 300)
        _log("├░┼©┬ÅÔäó├»┬©┬Å Player local posicionado sem server info: (100, 300)")
    
    _log("├░┼©ÔÇÿ┬ñ Jogador local criado: " + multiplayer_manager.get_local_player_name())

func _on_player_connected(player_info: Dictionary):
    """Callback quando novo jogador conecta"""
    _log("├░┼©┼í┬¿ DEBUG: _on_player_connected INICIADO!")
    var player_id = player_info.get("id", "")
    var player_name = player_info.get("name", "")
    
    _log("├░┼©ÔÇ£┬¿ _on_player_connected chamado para: " + player_name + " (ID: " + player_id + ")")
    _log("├░┼©ÔÇ£┬¿ Jogador atual: " + multiplayer_manager.get_local_player_name())
    _log("├░┼©ÔÇ£┬¿ player_info completo: " + str(player_info))
    
    if player_id.is_empty():
        _log("├ó┬Ø┼Æ Player ID vazio, ignorando")
        return
    
    # Verificar se j├â┬í existe
    if player_id in remote_players:
        _log("├ó┼í┬á├»┬©┬Å Player " + player_name + " j├â┬í existe, removendo primeiro")
        var old_player = remote_players[player_id]
        players_container.remove_child(old_player)
        old_player.queue_free()
        remote_players.erase(player_id)
    
    # Criar jogador remoto
    var remote_player = PLAYER_SCENE.instantiate()
    remote_player.name = "Player_" + player_id
    
    # Configurar como jogador remoto
    remote_player.setup_player(player_id, player_name, false)
    
    # Definir refer├â┬¬ncia ao multiplayer_manager
    remote_player.multiplayer_manager = multiplayer_manager
    
    players_container.add_child(remote_player)
    remote_players[player_id] = remote_player
    
    _log("├░┼©ÔÇØ┬ì ADICIONADO ao remote_players: " + player_id + " | Dicion├â┬írio agora tem: " + str(remote_players.keys()))
    _log("├░┼©ÔÇØ┬ì Tamanho do remote_players: " + str(remote_players.size()))
    
    # Posicionar player remoto exatamente como o servidor define
    if "position" in player_info:
        var pos = player_info.position
        if pos and "x" in pos and "y" in pos:
            remote_player.global_position = Vector2(pos.x, pos.y)
            _log("├░┼©ÔÇ£┬ì Player " + player_name + " posicionado do servidor: " + str(Vector2(pos.x, pos.y)))
        else:
            # Usar mesma posi├â┬º├â┬úo padr├â┬úo que servidor (100, 300)
            remote_player.global_position = Vector2(100, 300)
            _log("├░┼©ÔÇ£┬ì Player " + player_name + " posicionado padr├â┬úo servidor: (100, 300)")
    else:
        # Posi├â┬º├â┬úo padr├â┬úo alinhada com servidor
        remote_player.global_position = Vector2(100, 300)
        _log("├░┼©ÔÇ£┬ì Player " + player_name + " posicionado sem posi├â┬º├â┬úo servidor: (100, 300)")
    
    # IMPORTANTE: Verificar posi├â┬º├â┬úo final ap├â┬│s posicionamento
    _log("├░┼©ÔÇØ┬ì Posi├â┬º├â┬úo final de " + player_name + ": " + str(remote_player.global_position))
    
    # Definir mapa padr├â┬úo para novo player remoto (assumir que est├â┬í na cidade)
    remote_player.set_meta("current_map", "Cidade")
    
    # Verificar visibilidade inicial baseada no mapa atual
    if current_map == "Cidade":
        # Ambos na cidade, ativar completamente
        remote_player.visible = true
        remote_player.set_physics_process(true)
        remote_player.set_process(true)
        remote_player.collision_layer = 1
        remote_player.collision_mask = 7
        _log("├░┼©ÔÇÿ┬ü├»┬©┬Å Player remoto " + player_name + " ATIVADO (ambos na Cidade)")
    else:
        # Eu n├â┬úo estou na cidade, desativar player remoto
        remote_player.visible = false
        remote_player.set_physics_process(false)
        remote_player.set_process(false)
        remote_player.collision_layer = 0
        remote_player.collision_mask = 0
        remote_player.global_position = Vector2(99999, 99999)
        _log("├░┼©┼í┬½ Player remoto " + player_name + " DESATIVADO (eu estou em " + current_map + ", ele na Cidade)")
    
    _log("├░┼©ÔÇÿ┬Ñ Jogador remoto criado: " + player_name + " | Total players: " + str(remote_players.size() + 1))

func _on_player_disconnected(player_id: String):
    """Callback quando jogador desconecta"""
    _log("├░┼©ÔÇ£┬¿ _on_player_disconnected chamado para ID: " + player_id)
    if player_id in remote_players:
        var player_node = remote_players[player_id]
        var player_name = player_node.player_name if player_node else "Unknown"
        players_container.remove_child(player_node)
        player_node.queue_free()
        remote_players.erase(player_id)
        
        _log("├░┼©ÔÇÿÔÇ╣ Jogador remoto removido: " + player_name + " (ID: " + player_id + ") | Restantes: " + str(remote_players.size()))

func _on_player_sync_received(player_id: String, player_data: Dictionary):
    """Callback quando recebe sincroniza├â┬º├â┬úo de jogador"""
    if player_id not in remote_players:
        return
    
    var remote_player = remote_players[player_id]
    
    # S├â┬│ aplicar sincroniza├â┬º├â┬úo se o player estiver no mesmo mapa (ativo)
    var player_map = remote_player.get_meta("current_map", "Cidade")
    if player_map == current_map:
        remote_player.apply_sync_data(player_data)
        # _log("├░┼©ÔÇØÔÇ× Sincroniza├â┬º├â┬úo aplicada para player " + player_id + " (mesmo mapa)")
    else:
        # _log("├░┼©┼í┬½ Sincroniza├â┬º├â┬úo ignorada para player " + player_id + " (mapas diferentes)")
        pass

func _on_player_map_changed(player_id: String, player_map: String):
    """Callback quando um player remoto muda de mapa"""
    _log("├░┼©ÔÇö┬║├»┬©┬Å RECEBIDO mudan├â┬ºa de mapa: Player " + player_id + " mudou para: " + player_map)
    _log("├░┼©ÔÇö┬║├»┬©┬Å DEBUG: Meu current_map ├â┬®: " + current_map)
    
    if player_id in remote_players:
        var remote_player = remote_players[player_id]
        var old_map = remote_player.get_meta("current_map", "Cidade")
        
        # Armazenar o mapa atual do player remoto
        remote_player.set_meta("current_map", player_map)
        _log("├░┼©ÔÇö┬║├»┬©┬Å DEBUG: Player " + player_id + " mudou de '" + old_map + "' para '" + player_map + "'")
        
        # Mostrar/esconder player baseado no mapa
        if player_map == current_map:
            # Player est├â┬í no mesmo mapa, ativar completamente
            remote_player.visible = true
            remote_player.set_physics_process(true)
            remote_player.set_process(true)
            remote_player.collision_layer = 1  # Reativar colis├â┬úo
            remote_player.collision_mask = 7   # Reativar detec├â┬º├â┬úo
            
            # Atualizar posi├â┬º├â┬úo do player remoto com spawn do novo mapa
            var player_data = multiplayer_manager.get_players_data().get(player_id, {})
            if "position" in player_data:
                var pos = player_data.position
                if "x" in pos and "y" in pos:
                    remote_player.global_position = Vector2(pos.x, pos.y)
                    _log("├░┼©ÔÇ£┬ì Player " + player_id + " reposicionado para spawn: " + str(remote_player.global_position))
            
            _log("├░┼©ÔÇÿ┬ü├»┬©┬Å ATIVANDO Player " + player_id + " (mesmo mapa: " + player_map + ")")
        else:
            # Player est├â┬í em mapa diferente, desativar completamente
            remote_player.visible = false
            remote_player.set_physics_process(false)
            remote_player.set_process(false)
            remote_player.collision_layer = 0  # Desativar colis├â┬úo
            remote_player.collision_mask = 0   # Desativar detec├â┬º├â┬úo
            # Mover para posi├â┬º├â┬úo muito distante para evitar interfer├â┬¬ncias
            remote_player.global_position = Vector2(99999, 99999)
            _log("├░┼©┼í┬½ DESATIVANDO Player " + player_id + " (mapas diferentes: " + player_map + " vs " + current_map + ")")
    else:
        _log("├ó┬Ø┼Æ Player " + player_id + " n├â┬úo encontrado em remote_players para atualizar mapa!")

func _update_remote_players_visibility():
    """Atualiza visibilidade de todos os players remotos baseado no mapa atual"""
    _log("├░┼©ÔÇØÔÇ× ATUALIZANDO visibilidade de " + str(remote_players.size()) + " players remotos para mapa " + current_map)
    
    for player_id in remote_players.keys():
        var remote_player = remote_players[player_id]
        var player_map = remote_player.get_meta("current_map", "Cidade")  # Padr├â┬úo cidade
        
        _log("├░┼©ÔÇØÔÇ× Player " + player_id + " est├â┬í em: " + player_map + " | Eu estou em: " + current_map)
        
        if player_map == current_map:
            # Player est├â┬í no mesmo mapa, ativar completamente
            remote_player.visible = true
            remote_player.set_physics_process(true)
            remote_player.set_process(true)
            remote_player.collision_layer = 1  # Reativar colis├â┬úo
            remote_player.collision_mask = 7   # Reativar detec├â┬º├â┬úo
            
            # Reposicionar player remoto para spawn correto do mapa atual
            var player_data = multiplayer_manager.get_players_data().get(player_id, {})
            if "position" in player_data:
                var pos = player_data.position
                if "x" in pos and "y" in pos:
                    remote_player.global_position = Vector2(pos.x, pos.y)
                    _log("├░┼©ÔÇ£┬ì Player " + player_id + " reposicionado: " + str(remote_player.global_position))
            
            _log("├░┼©ÔÇÿ┬ü├»┬©┬Å ATIVANDO Player " + player_id + " no mapa " + current_map)
        else:
            # Player est├â┬í em mapa diferente, desativar completamente
            remote_player.visible = false
            remote_player.set_physics_process(false)
            remote_player.set_process(false)
            remote_player.collision_layer = 0  # Desativar colis├â┬úo
            remote_player.collision_mask = 0   # Desativar detec├â┬º├â┬úo
            # Mover para posi├â┬º├â┬úo muito distante para evitar interfer├â┬¬ncias
            remote_player.global_position = Vector2(99999, 99999)
            _log("├░┼©┼í┬½ DESATIVANDO Player " + player_id + " (est├â┬í em " + player_map + ", eu estou em " + current_map + ")")

func _on_local_player_update(pos: Vector2, velocity: Vector2, animation: String, facing: int, hp: int):
    """Callback quando jogador local se move"""
    if multiplayer_manager:
        multiplayer_manager.send_player_update(pos, velocity, animation, facing, hp)

func _on_local_player_update_with_sequence(pos: Vector2, velocity: Vector2, animation: String, facing: int, hp: int, sequence: int):
    """Callback quando jogador local se move com sequence"""
    if multiplayer_manager:
        multiplayer_manager.send_player_update_with_sequence(pos, velocity, animation, facing, hp, sequence)

func _on_local_player_action(action: String, action_data: Dictionary):
    """Callback quando jogador local faz uma a├â┬º├â┬úo"""
    if multiplayer_manager:
        multiplayer_manager.send_player_action(action, action_data)

func _on_connection_lost():
    """Callback quando perde conex├â┬úo"""
    _log("├░┼©ÔÇØ┼Æ _on_connection_lost() chamado - mostrando tela de erro")
    # Mostrar tela de erro e voltar ao login
    _show_connection_error()

func _on_server_reconciliation(reconciliation_data: Dictionary):
    """Callback para reconcilia├â┬º├â┬úo do servidor"""
    # Applying server reconciliation
    if local_player:
        _log("├░┼©ÔÇØÔÇ× Chamando apply_sync_data() no local_player")
        local_player.apply_sync_data(reconciliation_data)
    else:
        _log("├ó┬Ø┼Æ local_player ├â┬® null!")

func _show_connection_error():
    """Mostra erro de conex├â┬úo e volta ao login"""
    # Evitar m├â┬║ltiplas janelas de erro
    if connection_error_shown:
        return
    
    connection_error_shown = true
    _log("├ó┬Ø┼Æ Conex├â┬úo perdida! Voltando ao login...")
    
    # Verificar se j├â┬í existe uma janela de erro
    var existing_dialog = ui_container.get_node_or_null("ConnectionErrorDialog")
    if existing_dialog:
        existing_dialog.queue_free()
    
    # Criar tela de erro
    var error_dialog = AcceptDialog.new()
    error_dialog.name = "ConnectionErrorDialog"
    error_dialog.dialog_text = "Conex├â┬úo com o servidor perdida!\nVoltando ├â┬á tela de login..."
    error_dialog.title = "Erro de Conex├â┬úo"
    
    ui_container.add_child(error_dialog)
    error_dialog.popup_centered()
    
    # Aguardar OK e voltar ao login
    await error_dialog.confirmed
    error_dialog.queue_free()
    _return_to_login()

func _return_to_login():
    """Volta ├â┬á tela de login"""
    var tree = get_tree()
    if tree == null:
        _log("├ó┼í┬á├»┬©┬Å get_tree() null em _return_to_login(), n├â┬úo conseguindo voltar ao login")
        return
    
    # Usar m├â┬®todo mais confi├â┬ível para voltar ao login
    _log("├░┼©ÔÇØÔÇ× Voltando ├â┬á tela de login...")
    var scene_result = tree.change_scene_to_file("res://login_multiplayer.tscn")
    if scene_result != OK:
        _log("├ó┬Ø┼Æ Falha ao mudar para cena de login: " + str(scene_result))
        # ├â┼íltima tentativa: recarregar a cena atual
        tree.reload_current_scene()

func _setup_ui():
    """Configura UI b├â┬ísica do jogo"""
    var ui_label = Label.new()
    ui_label.text = "├░┼©┼¢┬« PROJETO ALLY - MULTIPLAYER ONLINE"
    ui_label.position = Vector2(10, 10)
    ui_label.add_theme_color_override("font_color", Color.WHITE)
    ui_container.add_child(ui_label)
    
    # Status de conex├â┬úo
    var status_label = Label.new()
    status_label.name = "StatusLabel"
    status_label.text = "├░┼©┼©┬ó Conectado"
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
                    _log("├░┼©┼¢┬« UI ATUALIZADA: Total players mudou de " + str(last_count) + " para " + str(total_players))
                    _log("├░┼©┼¢┬« UI DEBUG: remote_players.size() = " + str(remote_players.size()) + ", keys = " + str(remote_players.keys()))
                    players_label.set_meta("last_count", total_players)
            else:
                _log("├░┼©┼¢┬« UI INICIAL: Total players = " + str(total_players))
                players_label.set_meta("last_count", total_players)

# === FUN├âÔÇí├âÔÇóES DO SISTEMA V2.2 INTEGRADAS ===

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

# ---- L├â┬│gica de jogo / HUD ----
func reset_player() -> void:
    player_hp = player_hp_max
    if hud:
        hud.update_health(player_hp, player_hp_max)
    else:
        _log("├ó┼í┬á├»┬©┬Å HUD null em reset_player()")

func damage_player(amount: int, hit_world_pos: Vector2 = Vector2.ZERO) -> void:
    # Calcula dano final com defesa
    var final_damage = max(1, amount - get_damage_reduction())  # M├â┬¡nimo 1 de dano
    
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
            hud.show_popup("Voc├â┬¬ morreu e voltou para a cidade.")
        # Removido play_sfx_id - n├â┬úo implementado no multiplayer

func load_city(notify_server: bool = true) -> void:
    _clear_map()
    current_map = "Cidade"  # Atualizar mapa atual
    var City = load("res://scripts/city_map_multiplayer.gd")
    var city = City.new()
    map_container.add_child(city)
    city.setup(self)
    current_map_node = city
    # Verificar se HUD est├â┬í dispon├â┬¡vel antes de usar
    if hud:
        hud.set_map_title("Cidade - Multiplayer")
        hud.set_subtitle("")
    else:
        _log("├ó┼í┬á├»┬©┬Å HUD null em load_city()")
    
    # Notificar servidor sobre mudan├â┬ºa de mapa (com delay para estabilizar conex├â┬úo)
    if notify_server and multiplayer_manager:
        if multiplayer_manager.socket_connected and multiplayer_manager.is_logged_in:
            multiplayer_manager.send_map_change("Cidade")
            _log("[MAP] ENVIADO para servidor: mudança para Cidade")
        else:
            _log("[MAP] CANCELADO envio de map_change - não conectado")
    
    # Atualizar visibilidade dos players remotos
    _update_remote_players_visibility()
    # Enviar um snapshot de input para evitar travas pós-respawn
    _send_input_snapshot()

func load_forest() -> void:
    _clear_map()
    current_map = "Floresta"  # Atualizar mapa atual
    var Forest = load("res://scripts/forest_map_multiplayer.gd")
    var forest = Forest.new()
    map_container.add_child(forest)
    forest.setup(self)
    _position_players_in_forest()
    current_map_node = forest  # Refer├â┬¬ncia para o mapa atual
    _log("├░┼©┼Æ┬▓ Floresta carregada! Sistema server-side ativo.")
    
    # Verificar se HUD est├â┬í dispon├â┬¡vel antes de usar
    if hud:
        hud.set_map_title("Floresta - Multiplayer")
    else:
        _log("├ó┼í┬á├»┬©┬Å HUD null em load_forest()")
    
    # Notificar servidor sobre mudan├â┬ºa de mapa (com delay para estabilizar conex├â┬úo)
    if multiplayer_manager:
        if multiplayer_manager.socket_connected and multiplayer_manager.is_logged_in:
            multiplayer_manager.send_map_change("Floresta")
            _log("[MAP] ENVIADO para servidor: mudança para Floresta")
        else:
            _log("[MAP] CANCELADO envio de map_change - não conectado")
    
    # Aguardar um frame para garantir que o mapa foi constru├â┬¡do (se poss├â┬¡vel)
    var tree = get_tree()
    if tree:
        await tree.process_frame
    else:
        _log("├ó┼í┬á├»┬©┬Å get_tree() null em load_forest(), n├â┬úo aguardando frame")
    
    # Posicionar players multiplayer na floresta
    _position_players_in_forest()
    _log("├░┼©┼¢┬» Players posicionados na floresta. Podem atacar inimigos!")

func _position_players_in_city() -> void:
    """Posiciona APENAS o player local na cidade (preserva posi├â┬º├â┬úo do servidor se v├â┬ílida)"""
    # Verificar se o player j├â┬í tem uma posi├â┬º├â┬úo v├â┬ílida do servidor
    if local_player:
        var current_pos = local_player.global_position
        
        # Se o player j├â┬í est├â┬í numa posi├â┬º├â┬úo v├â┬ílida (n├â┬úo em (0,0) e n├â┬úo muito distante), preservar
        if current_pos != Vector2.ZERO and current_pos.length() > 10.0:
            _log("├░┼©┬ÅÔäó├»┬©┬Å Player local j├â┬í posicionado em: " + str(current_pos) + " (preservando posi├â┬º├â┬úo do servidor)")
            return
    
    # Caso contr├â┬írio, usar posi├â┬º├â┬úo padr├â┬úo da cidade
    var viewport = get_viewport()
    var vp: Vector2
    if viewport == null:
        vp = Vector2(1024, 768)  # Tamanho padr├â┬úo se n├â┬úo tiver viewport
        _log("├ó┼í┬á├»┬©┬Å Viewport null em _position_players_in_city(), usando tamanho padr├â┬úo")
    else:
        vp = viewport.get_visible_rect().size
    
    var stand_y: float = (vp.y * 0.5 - 150.0) - 20.0  # BOTTOM_MARGIN da cidade
    
    # Posicionar APENAS jogador local com posi├â┬º├â┬úo padr├â┬úo
    if local_player:
        local_player.global_position = Vector2(0.0, stand_y)
        local_player.velocity = Vector2.ZERO
        _log("├░┼©┬ÅÔäó├»┬©┬Å Player local posicionado na cidade (posi├â┬º├â┬úo padr├â┬úo): " + str(local_player.global_position))
    
    # N├âãÆO mover players remotos - eles est├â┬úo em suas pr├â┬│prias inst├â┬óncias!

func _position_players_in_forest() -> void:
    """Posiciona APENAS o player local na floresta"""
    var viewport = get_viewport()
    var vp: Vector2
    if viewport == null:
        vp = Vector2(1024, 768)  # Tamanho padr├â┬úo se n├â┬úo tiver viewport
        _log("├ó┼í┬á├»┬©┬Å Viewport null em _position_players_in_forest(), usando tamanho padr├â┬úo")
    else:
        vp = viewport.get_visible_rect().size
    
    var stand_y: float = (vp.y * 0.5 - 120.0) - 20.0  # BOTTOM_MARGIN da floresta
    var left_x: float = -vp.x * 0.5 + 64.0
    
    # Posicionar APENAS jogador local na floresta
    if local_player:
        local_player.global_position = Vector2(left_x, stand_y)
        local_player.velocity = Vector2.ZERO
        _log("├░┼©┼Æ┬▓ Player local posicionado na floresta: " + str(local_player.global_position))
    
    # N├âãÆO mover players remotos - eles est├â┬úo em suas pr├â┬│prias inst├â┬óncias!

func _clear_map() -> void:
    if map_container != null:
        for c in map_container.get_children():
            c.queue_free()
        current_map_node = null  # Limpar refer├â┬¬ncia
    else:
        _log("├ó┼í┬á├»┬©┬Å map_container ├â┬® null em _clear_map()")

func _on_select_map(map_name: String) -> void:
    _log("├░┼©ÔÇö┬║├»┬©┬Å Mudan├â┬ºa de mapa solicitada: " + map_name)
    match map_name:
        "Floresta":
            _log("├░┼©┼Æ┬▓ Carregando floresta...")
            load_forest()
        _:
            _log("├ó┼í┬á├»┬©┬Å Mapa n├â┬úo reconhecido: " + map_name)
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
            hud.show_popup("Mapa completo! Voc├â┬¬ voltou para a cidade.")
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
    player_xp_max = int(player_xp_max * 1.2)  # Aumenta 20% XP necess├â┬írio
    
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
    player_hp = min(player_hp, player_hp_max)  # N├â┬úo deixa HP atual maior que m├â┬íximo

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
    # Se morreu, voltar para a Cidade (sem notificar servidor – já moveu)
    if hp <= 0:
        var tree = get_tree()
        if tree:
            await tree.process_frame
        load_city(false)
        # Corrigir visual imediatamente: restaurar HP para o máximo no cliente
        # (o servidor já reviveu e confirma via player_stats_update)
        player_hp = player_hp_max
        if hud:
            hud.update_health(player_hp, player_hp_max)
        # Notificar o servidor para garantir troca autoritativa de mapa
        if multiplayer_manager and multiplayer_manager.is_logged_in:
            multiplayer_manager.send_map_change("Cidade")

# Envia o estado atual de input para o servidor (evita travamento de movimento
# quando o respawn acontece enquanto a tecla já estava pressionada)
func _send_input_snapshot() -> void:
    if not multiplayer_manager or not multiplayer_manager.is_logged_in:
        return
    var snapshot := {
        "move_left": Input.is_action_pressed("ui_left"),
        "move_right": Input.is_action_pressed("ui_right"),
        "jump": false,
        "attack": false
    }
    multiplayer_manager.send_input(snapshot)

func add_attribute_point(attribute: String) -> void:
    if multiplayer_manager and multiplayer_manager.is_logged_in:
        var msg := {"type": "spend_attribute_point", "attr": attribute}
        multiplayer_manager._send_message(msg)
    # HUD/valores vir├úo do servidor via player_stats_update_received

# ---- Sistema de Invent├â┬írio ----
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
    return false  # Invent├â┬írio cheio

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
        show_damage_popup_at_world(player_pos, "LEVEL UP! N├â┬¡vel %d" % player_level, Color(1, 1, 0, 1))  # Amarelo dourado

# ---- Dano flutuante (coordenadas de tela) ----
func show_damage_popup_at_world(world_pos: Vector2, txt: String, color: Color) -> void:
    if hud == null:
        _log("├ó┼í┬á├»┬©┬Å HUD null em show_damage_popup_at_world(), n├â┬úo mostrando popup: " + txt)
        return
    hud.show_damage_popup_at_world(world_pos, txt, color)

func _finish_setup_multiplayer() -> void:
    """Finaliza setup do multiplayer ap├â┬│s estar na ├â┬írvore de cenas"""
    var tree = get_tree()
    if tree == null:
        _log("├ó┼í┬á├»┬©┬Å get_tree() ainda null em _finish_setup_multiplayer(), tentando novamente")
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
    # Lista do servidor cont├®m apenas players do meu mapa atual
    for pid in players.keys():
        if multiplayer_manager and pid == multiplayer_manager.get_local_player_id():
            continue
        if pid in remote_players:
            remote_players[pid].set_meta("current_map", current_map)
        else:
            _on_player_connected(players[pid])
    _update_remote_players_visibility()
    _send_input_snapshot()

func _on_player_left_map_received(player_id: String) -> void:
    if player_id in remote_players:
        remote_players[player_id].set_meta("current_map", "OUTRO")
        _update_remote_players_visibility()
    _send_input_snapshot()
