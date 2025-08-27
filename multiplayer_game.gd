extends Node2D

var multiplayer_manager: MultiplayerManager
var local_player: CharacterBody2D
var remote_players = {}

# Referências de cena
var players_container: Node2D
var ui_container: CanvasLayer

# Cena do player
const PLAYER_SCENE = preload("res://multiplayer_player.tscn")

func _ready():
    # Criar containers se não existirem
    if not players_container:
        players_container = Node2D.new()
        players_container.name = "PlayersContainer"
        add_child(players_container)
    
    if not ui_container:
        ui_container = CanvasLayer.new()
        ui_container.name = "UIContainer"
        add_child(ui_container)
        
        # Adicionar UI básica
        _setup_ui()

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
    var is_connected = multiplayer_manager.player_connected.is_connected(_on_player_connected)
    _log("🔗 DEBUG: Sinal is_connected? " + str(is_connected))
    
    multiplayer_manager.player_disconnected.connect(_on_player_disconnected)
    multiplayer_manager.player_sync_received.connect(_on_player_sync_received) 
    multiplayer_manager.connection_lost.connect(_on_connection_lost)
    _log("✅ Todos os sinais conectados!")
    
    # Criar jogador local
    _create_local_player()
    
    # IMPORTANTE: Verificar se já existem jogadores conectados e criar eles
    _check_existing_players()
    
    _log("🎮 Jogo multiplayer configurado!")

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
    local_player.player_action.connect(_on_local_player_action)
    
    # Garantir que players_container existe
    if not players_container:
        players_container = Node2D.new()
        players_container.name = "PlayersContainer"
        add_child(players_container)
    
    players_container.add_child(local_player)
    
    # Posicionar player
    var player_info = multiplayer_manager.local_player_info
    if player_info and "position" in player_info:
        var pos = player_info.position
        if pos and "x" in pos and "y" in pos:
            local_player.global_position = Vector2(pos.x, pos.y)
    else:
        # Posição padrão do jogador local
        local_player.global_position = Vector2(200, 400)
    
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
    
    # Posicionar player
    if "position" in player_info:
        var pos = player_info.position
        if pos and "x" in pos and "y" in pos:
            remote_player.global_position = Vector2(pos.x, pos.y)
            _log("📍 Player " + player_name + " posicionado em: " + str(Vector2(pos.x, pos.y)))
        else:
            remote_player.global_position = Vector2(600, 400)
            _log("📍 Player " + player_name + " posicionado na posição padrão: " + str(Vector2(600, 400)))
    else:
        # Posição padrão para jogadores remotos (separada do local)
        remote_player.global_position = Vector2(600, 400)
        _log("📍 Player " + player_name + " posicionado na posição padrão: " + str(Vector2(600, 400)))
    
    # IMPORTANTE: Verificar posição final após posicionamento
    _log("🔍 Posição final de " + player_name + ": " + str(remote_player.global_position))
    
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
    remote_player.apply_sync_data(player_data)

func _on_local_player_update(pos: Vector2, velocity: Vector2, animation: String, facing: int, hp: int):
    """Callback quando jogador local se move"""
    if multiplayer_manager:
        multiplayer_manager.send_player_update(pos, velocity, animation, facing, hp)

func _on_local_player_action(action: String, action_data: Dictionary):
    """Callback quando jogador local faz uma ação"""
    if multiplayer_manager:
        multiplayer_manager.send_player_action(action, action_data)

func _on_connection_lost():
    """Callback quando perde conexão"""
    # Mostrar tela de erro e voltar ao login
    _show_connection_error()

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
    get_tree().change_scene_to_packed(login_scene)

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
