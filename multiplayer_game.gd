extends Node2D

var multiplayer_manager: MultiplayerManager
var local_player: CharacterBody2D
var remote_players = {}
var current_map: String = "Cidade"  # Rastrear mapa atual
var current_map_node: Node = null  # Referência ao nó do mapa atual

# Referências de cena
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
var player_strength: int = 5    # Força - aumenta dano
var player_defense: int = 5     # Defesa - reduz dano recebido
var player_intelligence: int = 5 # Inteligência (futuro uso)
var player_vitality: int = 5    # Vitalidade - aumenta HP
var available_points: int = 0   # Pontos disponíveis para distribuir

# Sistema de Inventário
var inventory_slots: Array[Dictionary] = []  # 5 slots do inventário
var equipped_weapon: Dictionary = {}         # Slot de equipamento da espada
const MAX_INVENTORY_SLOTS: int = 5

# Sistema de Auto Attack
var auto_attack_enabled: bool = false

# --- Áudio ---
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
    
    # Criar containers se não existirem
    if not players_container:
        players_container = Node2D.new()
        players_container.name = "PlayersContainer"
        add_child(players_container)
    
    if not map_container:
        map_container = Node.new()
        map_container.name = "MapContainer"
        add_child(map_container)
    
    # HUD será criado no setup_multiplayer() para evitar duplicação
    # Inicialização do HUD movida para setup_multiplayer()
    
    # sfx
    _setup_sfx_players()
    
    # UI básica multiplayer (mantém contador de jogadores)
    if not ui_container:
        ui_container = CanvasLayer.new()
        ui_container.name = "UIContainer"
        add_child(ui_container)
        
        # Adicionar UI básica
        _setup_ui()
    
    # NOTA: O mapa inicial da cidade será carregado após setup_multiplayer()

func _log(message: String):
    """Log local e para o servidor"""
    print(message)
    if multiplayer_manager:
        multiplayer_manager.send_log_to_server(message)

func setup_multiplayer(manager: MultiplayerManager):
    """Configura o multiplayer com o manager recebido"""
    multiplayer_manager = manager
    
    # Mover manager para esta cena (só se não estiver já aqui)
    if multiplayer_manager.get_parent() != self:
        if multiplayer_manager.get_parent():
            multiplayer_manager.get_parent().remove_child(multiplayer_manager)
        add_child(multiplayer_manager)
    
    # Conectar sinais
    _log("🔗 Conectando sinais do MultiplayerManager...")
    _log("🔗 DEBUG: Manager existe? " + str(multiplayer_manager != null))
    
    var connect_result = multiplayer_manager.player_connected.connect(_on_player_connected)
    _log("🔗 DEBUG: connect() retornou: " + str(connect_result) + " (0=sucesso)")
    if connect_result == OK:
        _log("✅ Sinal player_connected conectado!")
    else:
        _log("❌ ERRO ao conectar sinal player_connected! Código: " + str(connect_result))
    
    # Verificar se o sinal está mesmo conectado
    var signal_connected = multiplayer_manager.player_connected.is_connected(_on_player_connected)
    _log("🔗 DEBUG: Sinal conectado? " + str(signal_connected))
    
    multiplayer_manager.player_disconnected.connect(_on_player_disconnected)
    multiplayer_manager.player_sync_received.connect(_on_player_sync_received) 
    multiplayer_manager.map_change_received.connect(_on_player_map_changed)
    multiplayer_manager.connection_lost.connect(_on_connection_lost)
    multiplayer_manager.server_reconciliation.connect(_on_server_reconciliation)
    _log("✅ Todos os sinais conectados!")
    
    # Criar jogador local
    _create_local_player()
    
    # IMPORTANTE: Verificar se já existem jogadores conectados e criar eles
    _check_existing_players()
    
    # GARANTIR que map_container existe antes de carregar a cidade
    if not map_container:
        map_container = Node.new()
        map_container.name = "MapContainer"
        add_child(map_container)
        _log("🗂️ map_container criado no setup_multiplayer()")
    
    # GARANTIR que HUD existe antes de carregar a cidade
    if not hud:
        _log("🏗️ Criando HUD no setup_multiplayer() pois não existe")
        var HUD = load("res://scripts/hud.gd")
        hud = HUD.new()
        add_child(hud)
        
        # Aguardar até estar na árvore de cenas
        call_deferred("_finish_setup_multiplayer")
        hud.update_xp(player_xp, player_xp_max)
        hud.set_map_title("Cidade - Multiplayer")
    
    _log("🎮 Setup inicial completo, aguardando finalização...")

func _check_existing_players():
    """Verifica se já existem jogadores conectados e os cria"""
    _log("🔍 VERIFICANDO jogadores já existentes...")
    
    if not multiplayer_manager:
        _log("❌ Manager não existe para verificação")
        return
    
    var players_data = multiplayer_manager.get_players_data()
    var my_id = multiplayer_manager.get_local_player_id()
    
    _log("🔍 Players data disponível: " + str(players_data.keys()))
    _log("🔍 Meu ID local: " + my_id)
    
    for player_id in players_data.keys():
        if player_id != my_id:
            var player_info = players_data[player_id]
            _log("🔍 ENCONTRADO jogador existente: " + player_info.get("name", "") + " (ID: " + player_id + ")")
            _log("🔍 FORÇANDO criação via _on_player_connected...")
            
            # Forçar criação do jogador remoto
            _on_player_connected(player_info)

func _create_local_player():
    """Cria o jogador local"""
    local_player = PLAYER_SCENE.instantiate()
    local_player.name = "LocalPlayer"
    
    # Configurar como jogador local
    local_player.setup_multiplayer_player(
        multiplayer_manager.get_local_player_id(),
        multiplayer_manager.get_local_player_name(),
        true  # is_local
    )
    
    # Conectar sinais do player
    local_player.player_update.connect(_on_local_player_update)
    local_player.player_update_with_sequence.connect(_on_local_player_update_with_sequence)
    local_player.player_action.connect(_on_local_player_action)
    
    # Atualizar HP máximo baseado nos atributos (deferred para garantir que está na árvore)
    if local_player.has_method("update_max_hp"):
        local_player.call_deferred("update_max_hp")
    
    # Garantir que players_container existe
    if not players_container:
        players_container = Node2D.new()
        players_container.name = "PlayersContainer"
        add_child(players_container)
    
    players_container.add_child(local_player)
    
    # Posicionar player usando posição do servidor
    var player_info = multiplayer_manager.local_player_info
    if player_info and "position" in player_info:
        var pos = player_info.position
        if pos and "x" in pos and "y" in pos:
            local_player.global_position = Vector2(pos.x, pos.y)
            _log("🏙️ Player local posicionado do servidor: (" + str(pos.x) + ", " + str(pos.y) + ")")
        else:
            # Fallback para posição padrão
            local_player.global_position = Vector2(100, 300)
            _log("🏙️ Player local posicionado padrão: (100, 300)")
    else:
        # Posição padrão alinhada com servidor
        local_player.global_position = Vector2(100, 300)
        _log("🏙️ Player local posicionado sem server info: (100, 300)")
    
    _log("👤 Jogador local criado: " + multiplayer_manager.get_local_player_name())

func _on_player_connected(player_info: Dictionary):
    """Callback quando novo jogador conecta"""
    _log("🚨 DEBUG: _on_player_connected INICIADO!")
    var player_id = player_info.get("id", "")
    var player_name = player_info.get("name", "")
    
    _log("📨 _on_player_connected chamado para: " + player_name + " (ID: " + player_id + ")")
    _log("📨 Jogador atual: " + multiplayer_manager.get_local_player_name())
    _log("📨 player_info completo: " + str(player_info))
    
    if player_id.is_empty():
        _log("❌ Player ID vazio, ignorando")
        return
    
    # Verificar se já existe
    if player_id in remote_players:
        _log("⚠️ Player " + player_name + " já existe, removendo primeiro")
        var old_player = remote_players[player_id]
        players_container.remove_child(old_player)
        old_player.queue_free()
        remote_players.erase(player_id)
    
    # Criar jogador remoto
    var remote_player = PLAYER_SCENE.instantiate()
    remote_player.name = "Player_" + player_id
    
    # Configurar como jogador remoto
    remote_player.setup_multiplayer_player(player_id, player_name, false)
    
    players_container.add_child(remote_player)
    remote_players[player_id] = remote_player
    
    _log("🔍 ADICIONADO ao remote_players: " + player_id + " | Dicionário agora tem: " + str(remote_players.keys()))
    _log("🔍 Tamanho do remote_players: " + str(remote_players.size()))
    
    # Posicionar player remoto exatamente como o servidor define
    if "position" in player_info:
        var pos = player_info.position
        if pos and "x" in pos and "y" in pos:
            remote_player.global_position = Vector2(pos.x, pos.y)
            _log("📍 Player " + player_name + " posicionado do servidor: " + str(Vector2(pos.x, pos.y)))
        else:
            # Usar mesma posição padrão que servidor (100, 300)
            remote_player.global_position = Vector2(100, 300)
            _log("📍 Player " + player_name + " posicionado padrão servidor: (100, 300)")
    else:
        # Posição padrão alinhada com servidor
        remote_player.global_position = Vector2(100, 300)
        _log("📍 Player " + player_name + " posicionado sem posição servidor: (100, 300)")
    
    # IMPORTANTE: Verificar posição final após posicionamento
    _log("🔍 Posição final de " + player_name + ": " + str(remote_player.global_position))
    
    # Definir mapa padrão para novo player remoto (assumir que está na cidade)
    remote_player.set_meta("current_map", "Cidade")
    
    # Verificar visibilidade inicial baseada no mapa atual
    if current_map == "Cidade":
        # Ambos na cidade, ativar completamente
        remote_player.visible = true
        remote_player.set_physics_process(true)
        remote_player.set_process(true)
        remote_player.collision_layer = 1
        remote_player.collision_mask = 7
        _log("👁️ Player remoto " + player_name + " ATIVADO (ambos na Cidade)")
    else:
        # Eu não estou na cidade, desativar player remoto
        remote_player.visible = false
        remote_player.set_physics_process(false)
        remote_player.set_process(false)
        remote_player.collision_layer = 0
        remote_player.collision_mask = 0
        remote_player.global_position = Vector2(99999, 99999)
        _log("🚫 Player remoto " + player_name + " DESATIVADO (eu estou em " + current_map + ", ele na Cidade)")
    
    _log("👥 Jogador remoto criado: " + player_name + " | Total players: " + str(remote_players.size() + 1))

func _on_player_disconnected(player_id: String):
    """Callback quando jogador desconecta"""
    _log("📨 _on_player_disconnected chamado para ID: " + player_id)
    if player_id in remote_players:
        var player_node = remote_players[player_id]
        var player_name = player_node.player_name if player_node else "Unknown"
        players_container.remove_child(player_node)
        player_node.queue_free()
        remote_players.erase(player_id)
        
        _log("👋 Jogador remoto removido: " + player_name + " (ID: " + player_id + ") | Restantes: " + str(remote_players.size()))

func _on_player_sync_received(player_id: String, player_data: Dictionary):
    """Callback quando recebe sincronização de jogador"""
    if player_id not in remote_players:
        return
    
    var remote_player = remote_players[player_id]
    
    # Só aplicar sincronização se o player estiver no mesmo mapa (ativo)
    var player_map = remote_player.get_meta("current_map", "Cidade")
    if player_map == current_map:
        remote_player.apply_sync_data(player_data)
        # _log("🔄 Sincronização aplicada para player " + player_id + " (mesmo mapa)")
    else:
        # _log("🚫 Sincronização ignorada para player " + player_id + " (mapas diferentes)")
        pass

func _on_player_map_changed(player_id: String, player_map: String):
    """Callback quando um player remoto muda de mapa"""
    _log("🗺️ RECEBIDO mudança de mapa: Player " + player_id + " mudou para: " + player_map)
    _log("🗺️ DEBUG: Meu current_map é: " + current_map)
    
    if player_id in remote_players:
        var remote_player = remote_players[player_id]
        var old_map = remote_player.get_meta("current_map", "Cidade")
        
        # Armazenar o mapa atual do player remoto
        remote_player.set_meta("current_map", player_map)
        _log("🗺️ DEBUG: Player " + player_id + " mudou de '" + old_map + "' para '" + player_map + "'")
        
        # Mostrar/esconder player baseado no mapa
        if player_map == current_map:
            # Player está no mesmo mapa, ativar completamente
            remote_player.visible = true
            remote_player.set_physics_process(true)
            remote_player.set_process(true)
            remote_player.collision_layer = 1  # Reativar colisão
            remote_player.collision_mask = 7   # Reativar detecção
            
            # Atualizar posição do player remoto com spawn do novo mapa
            var player_data = multiplayer_manager.get_players_data().get(player_id, {})
            if "position" in player_data:
                var pos = player_data.position
                if "x" in pos and "y" in pos:
                    remote_player.global_position = Vector2(pos.x, pos.y)
                    _log("📍 Player " + player_id + " reposicionado para spawn: " + str(remote_player.global_position))
            
            _log("👁️ ATIVANDO Player " + player_id + " (mesmo mapa: " + player_map + ")")
        else:
            # Player está em mapa diferente, desativar completamente
            remote_player.visible = false
            remote_player.set_physics_process(false)
            remote_player.set_process(false)
            remote_player.collision_layer = 0  # Desativar colisão
            remote_player.collision_mask = 0   # Desativar detecção
            # Mover para posição muito distante para evitar interferências
            remote_player.global_position = Vector2(99999, 99999)
            _log("🚫 DESATIVANDO Player " + player_id + " (mapas diferentes: " + player_map + " vs " + current_map + ")")
    else:
        _log("❌ Player " + player_id + " não encontrado em remote_players para atualizar mapa!")

func _update_remote_players_visibility():
    """Atualiza visibilidade de todos os players remotos baseado no mapa atual"""
    _log("🔄 ATUALIZANDO visibilidade de " + str(remote_players.size()) + " players remotos para mapa " + current_map)
    
    for player_id in remote_players.keys():
        var remote_player = remote_players[player_id]
        var player_map = remote_player.get_meta("current_map", "Cidade")  # Padrão cidade
        
        _log("🔄 Player " + player_id + " está em: " + player_map + " | Eu estou em: " + current_map)
        
        if player_map == current_map:
            # Player está no mesmo mapa, ativar completamente
            remote_player.visible = true
            remote_player.set_physics_process(true)
            remote_player.set_process(true)
            remote_player.collision_layer = 1  # Reativar colisão
            remote_player.collision_mask = 7   # Reativar detecção
            
            # Reposicionar player remoto para spawn correto do mapa atual
            var player_data = multiplayer_manager.get_players_data().get(player_id, {})
            if "position" in player_data:
                var pos = player_data.position
                if "x" in pos and "y" in pos:
                    remote_player.global_position = Vector2(pos.x, pos.y)
                    _log("📍 Player " + player_id + " reposicionado: " + str(remote_player.global_position))
            
            _log("👁️ ATIVANDO Player " + player_id + " no mapa " + current_map)
        else:
            # Player está em mapa diferente, desativar completamente
            remote_player.visible = false
            remote_player.set_physics_process(false)
            remote_player.set_process(false)
            remote_player.collision_layer = 0  # Desativar colisão
            remote_player.collision_mask = 0   # Desativar detecção
            # Mover para posição muito distante para evitar interferências
            remote_player.global_position = Vector2(99999, 99999)
            _log("🚫 DESATIVANDO Player " + player_id + " (está em " + player_map + ", eu estou em " + current_map + ")")

func _on_local_player_update(pos: Vector2, velocity: Vector2, animation: String, facing: int, hp: int):
    """Callback quando jogador local se move"""
    if multiplayer_manager:
        multiplayer_manager.send_player_update(pos, velocity, animation, facing, hp)

func _on_local_player_update_with_sequence(pos: Vector2, velocity: Vector2, animation: String, facing: int, hp: int, sequence: int):
    """Callback quando jogador local se move com sequence"""
    if multiplayer_manager:
        multiplayer_manager.send_player_update_with_sequence(pos, velocity, animation, facing, hp, sequence)

func _on_local_player_action(action: String, action_data: Dictionary):
    """Callback quando jogador local faz uma ação"""
    if multiplayer_manager:
        multiplayer_manager.send_player_action(action, action_data)

func _on_connection_lost():
    """Callback quando perde conexão"""
    # Mostrar tela de erro e voltar ao login
    _show_connection_error()

func _on_server_reconciliation(reconciliation_data: Dictionary):
    """Callback para reconciliação do servidor"""
    # Applying server reconciliation
    if local_player:
        _log("🔄 Chamando apply_sync_data() no local_player")
        local_player.apply_sync_data(reconciliation_data)
    else:
        _log("❌ local_player é null!")

func _show_connection_error():
    """Mostra erro de conexão e volta ao login"""
    _log("❌ Conexão perdida! Voltando ao login...")
    
    # Criar tela de erro
    var error_dialog = AcceptDialog.new()
    error_dialog.dialog_text = "Conexão com o servidor perdida!\nVoltando à tela de login..."
    error_dialog.title = "Erro de Conexão"
    
    ui_container.add_child(error_dialog)
    error_dialog.popup_centered()
    
    # Aguardar OK e voltar ao login
    await error_dialog.confirmed
    _return_to_login()

func _return_to_login():
    """Volta à tela de login"""
    var login_scene = preload("res://login_multiplayer.tscn")
    var tree = get_tree()
    if tree == null:
        _log("⚠️ get_tree() null em _return_to_login(), não conseguindo voltar ao login")
        return
    tree.change_scene_to_packed(login_scene)

func _setup_ui():
    """Configura UI básica do jogo"""
    var ui_label = Label.new()
    ui_label.text = "🎮 PROJETO ALLY - MULTIPLAYER ONLINE"
    ui_label.position = Vector2(10, 10)
    ui_label.add_theme_color_override("font_color", Color.WHITE)
    ui_container.add_child(ui_label)
    
    # Status de conexão
    var status_label = Label.new()
    status_label.name = "StatusLabel"
    status_label.text = "🟢 Conectado"
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
    if ui_container:
        var players_label = ui_container.get_node_or_null("PlayersLabel")
        if players_label:
            var total_players = 1 + remote_players.size()  # Local + remotes
            players_label.text = "Jogadores: %d" % total_players
            
            # Debug da contagem (log apenas quando muda)
            if players_label.has_meta("last_count"):
                var last_count = players_label.get_meta("last_count")
                if last_count != total_players:
                    _log("🎮 UI ATUALIZADA: Total players mudou de " + str(last_count) + " para " + str(total_players))
                    _log("🎮 UI DEBUG: remote_players.size() = " + str(remote_players.size()) + ", keys = " + str(remote_players.keys()))
                    players_label.set_meta("last_count", total_players)
            else:
                _log("🎮 UI INICIAL: Total players = " + str(total_players))
                players_label.set_meta("last_count", total_players)

# === FUNÇÕES DO SISTEMA V2.2 INTEGRADAS ===

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
    if hud:
        hud.update_health(player_hp, player_hp_max)
    else:
        _log("⚠️ HUD null em reset_player()")

func damage_player(amount: int, hit_world_pos: Vector2 = Vector2.ZERO) -> void:
    # Calcula dano final com defesa
    var final_damage = max(1, amount - get_damage_reduction())  # Mínimo 1 de dano
    
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
            hud.show_popup("Você morreu e voltou para a cidade.")
        # Removido play_sfx_id - não implementado no multiplayer

func load_city() -> void:
    _clear_map()
    current_map = "Cidade"  # Atualizar mapa atual
    var City = load("res://scripts/city_map_multiplayer.gd")
    var city = City.new()
    map_container.add_child(city)
    city.setup(self)
    # Verificar se HUD está disponível antes de usar
    if hud:
        hud.set_map_title("Cidade - Multiplayer")
        hud.set_subtitle("")
    else:
        _log("⚠️ HUD null em load_city()")
    
    # Notificar servidor sobre mudança de mapa
    if multiplayer_manager:
        multiplayer_manager.send_map_change("Cidade")
        _log("📡 ENVIANDO para servidor: mudança para Cidade")
        _log("📡 DEBUG: Meu current_map agora é: " + current_map)
    
    # Atualizar visibilidade dos players remotos
    _update_remote_players_visibility()

func load_forest() -> void:
    _clear_map()
    current_map = "Floresta"  # Atualizar mapa atual
    var Forest = load("res://scripts/forest_map_multiplayer.gd")
    var forest = Forest.new()
    map_container.add_child(forest)
    forest.setup(self)
    current_map_node = forest  # Referência para o mapa atual
    _log("🌲 Floresta carregada! Sistema server-side ativo.")
    
    # Verificar se HUD está disponível antes de usar
    if hud:
        hud.set_map_title("Floresta - Multiplayer")
    else:
        _log("⚠️ HUD null em load_forest()")
    
    # Notificar servidor sobre mudança de mapa
    if multiplayer_manager:
        multiplayer_manager.send_map_change("Floresta")
        _log("📡 ENVIANDO para servidor: mudança para Floresta")
        _log("📡 DEBUG: Meu current_map agora é: " + current_map)
    
    # Atualizar visibilidade dos players remotos
    _update_remote_players_visibility()
    
    # Aguardar um frame para garantir que o mapa foi construído (se possível)
    var tree = get_tree()
    if tree:
        await tree.process_frame
    else:
        _log("⚠️ get_tree() null em load_forest(), não aguardando frame")
    
    # Posicionar players multiplayer na floresta
    _position_players_in_forest()
    _log("🎯 Players posicionados na floresta. Podem atacar inimigos!")

func _position_players_in_city() -> void:
    """Posiciona APENAS o player local na cidade (preserva posição do servidor se válida)"""
    # Verificar se o player já tem uma posição válida do servidor
    if local_player:
        var current_pos = local_player.global_position
        
        # Se o player já está numa posição válida (não em (0,0) e não muito distante), preservar
        if current_pos != Vector2.ZERO and current_pos.length() > 10.0:
            _log("🏙️ Player local já posicionado em: " + str(current_pos) + " (preservando posição do servidor)")
            return
    
    # Caso contrário, usar posição padrão da cidade
    var viewport = get_viewport()
    var vp: Vector2
    if viewport == null:
        vp = Vector2(1024, 768)  # Tamanho padrão se não tiver viewport
        _log("⚠️ Viewport null em _position_players_in_city(), usando tamanho padrão")
    else:
        vp = viewport.get_visible_rect().size
    
    var stand_y: float = (vp.y * 0.5 - 150.0) - 20.0  # BOTTOM_MARGIN da cidade
    
    # Posicionar APENAS jogador local com posição padrão
    if local_player:
        local_player.global_position = Vector2(0.0, stand_y)
        local_player.velocity = Vector2.ZERO
        _log("🏙️ Player local posicionado na cidade (posição padrão): " + str(local_player.global_position))
    
    # NÃO mover players remotos - eles estão em suas próprias instâncias!

func _position_players_in_forest() -> void:
    """Posiciona APENAS o player local na floresta"""
    var viewport = get_viewport()
    var vp: Vector2
    if viewport == null:
        vp = Vector2(1024, 768)  # Tamanho padrão se não tiver viewport
        _log("⚠️ Viewport null em _position_players_in_forest(), usando tamanho padrão")
    else:
        vp = viewport.get_visible_rect().size
    
    var stand_y: float = (vp.y * 0.5 - 120.0) - 20.0  # BOTTOM_MARGIN da floresta
    var left_x: float = -vp.x * 0.5 + 64.0
    
    # Posicionar APENAS jogador local na floresta
    if local_player:
        local_player.global_position = Vector2(left_x, stand_y)
        local_player.velocity = Vector2.ZERO
        _log("🌲 Player local posicionado na floresta: " + str(local_player.global_position))
    
    # NÃO mover players remotos - eles estão em suas próprias instâncias!

func _clear_map() -> void:
    if map_container != null:
        for c in map_container.get_children():
            c.queue_free()
        current_map_node = null  # Limpar referência
    else:
        _log("⚠️ map_container é null em _clear_map()")

func _on_select_map(map_name: String) -> void:
    _log("🗺️ Mudança de mapa solicitada: " + map_name)
    match map_name:
        "Floresta":
            _log("🌲 Carregando floresta...")
            load_forest()
        _:
            _log("⚠️ Mapa não reconhecido: " + map_name)
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
    
    # Ganha 5 pontos de atributo
    available_points += 5
    
    hud.update_xp(player_xp, player_xp_max)
    
    # Mostra mensagem flutuante acima do player
    _show_level_up_message()

func get_player_level() -> int:
    return player_level

# ---- Sistema de Atributos ----
func _calculate_max_hp() -> void:
    var base_hp = 100
    player_hp_max = base_hp + (player_vitality * 20)
    player_hp = min(player_hp, player_hp_max)  # Não deixa HP atual maior que máximo

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

func add_attribute_point(attribute: String) -> void:
    if available_points <= 0:
        return
        
    match attribute:
        "strength":
            player_strength += 1
        "defense":
            player_defense += 1
        "intelligence":
            player_intelligence += 1
        "vitality":
            player_vitality += 1
            _calculate_max_hp()  # Recalcula HP máximo
            # Atualizar HP máximo do player local
            if local_player and local_player.has_method("update_max_hp"):
                local_player.update_max_hp()
            hud.update_health(player_hp, player_hp_max)  # Atualiza barra de HP
    
    available_points -= 1

# ---- Sistema de Inventário ----
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
    return false  # Inventário cheio

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
        show_damage_popup_at_world(player_pos, "LEVEL UP! Nível %d" % player_level, Color(1, 1, 0, 1))  # Amarelo dourado

# ---- Dano flutuante (coordenadas de tela) ----
func show_damage_popup_at_world(world_pos: Vector2, txt: String, color: Color) -> void:
    if hud == null:
        _log("⚠️ HUD null em show_damage_popup_at_world(), não mostrando popup: " + txt)
        return
    hud.show_damage_popup_at_world(world_pos, txt, color)

func _finish_setup_multiplayer() -> void:
    """Finaliza setup do multiplayer após estar na árvore de cenas"""
    var tree = get_tree()
    if tree == null:
        _log("⚠️ get_tree() ainda null em _finish_setup_multiplayer(), tentando novamente")
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
