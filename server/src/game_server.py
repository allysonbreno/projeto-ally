import asyncio
import websockets
import json
import threading
import time
from datetime import datetime
import uuid
import hashlib
import secrets
# Sistema legado removido - usando apenas MapManager
from maps.map_instance import MapManager
from db.sqlite_store import SqliteStore

def hash_password(password: str, salt: bytes = None) -> tuple:
    """Gera hash da senha com salt. Retorna (hash, salt)."""
    if salt is None:
        salt = secrets.token_bytes(32)
    pwd_hash = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt, 100000)
    return pwd_hash, salt

def verify_password(password: str, pwd_hash: bytes, salt: bytes) -> bool:
    """Verifica se senha confere com hash."""
    computed_hash, _ = hash_password(password, salt)
    return computed_hash == pwd_hash

class GameServer:
    def __init__(self):
        self.clients = {}  # {websocket: player_data}
        # Sistema legado removido - players agora são gerenciados pelo MapManager server-side
        self.server = None
        self.running = False
        self.host = "localhost"
        self.port = 8765
        self.log_callback = None
        import os
        self.log_file_path = os.path.join(os.path.dirname(__file__), "../../logs_servidor.txt")
        self._init_log_file()
        
        # Banco de dados (SQLite)
        try:
            db_path = os.path.join(os.path.dirname(__file__), "../../server_data/game.db")
            self.store = SqliteStore(db_path)
            self.store.create_tables()
            self.log("[DB] SQLite inicializado")
        except Exception as e:
            print(f"[ERROR][DB] Falha ao iniciar SQLite: {e}")
        
        # Novo sistema de mapas server-side
        print("DEBUG: Tentando criar MapManager...")
        try:
            self.map_manager = MapManager()
            print("DEBUG: MapManager criado com sucesso!")
        except Exception as e:
            print(f"[ERROR] DEBUG: Erro ao criar MapManager: {e}")
            import traceback
            traceback.print_exc()
        self.log("[MAP_MANAGER] Sistema de mapas server-side inicializado")
        
        # Pré-criar mapas com inimigos no startup
        self._initialize_all_maps()
        
        # Sistema legado removido - usando apenas MapManager
        # self.enemy_manager = EnemyManager()  # REMOVIDO
        # self.enemy_update_task = None  # REMOVIDO
        
    def _init_log_file(self):
        """Inicializa o arquivo de log"""
        try:
            print(f"Inicializando log em: {self.log_file_path}")
            with open(self.log_file_path, "w", encoding="utf-8") as f:
                f.write("SISTEMA DE LOGS MULTIPLAYER - PROJETO ALLY\n\n")
                f.write("Este arquivo é automaticamente atualizado com os logs do SERVIDOR Python.\n\n")
                f.write("==== LOGS SERVIDOR (PYTHON) ====\n")
            print("Log do servidor inicializado com sucesso")
        except Exception as e:
            print(f"Erro ao inicializar log: {e}")
            print(f"Caminho tentado: {self.log_file_path}")
    
    def _initialize_all_maps(self):
        """Pré-cria todos os mapas com seus inimigos no startup do servidor"""
        available_maps = ["Cidade", "Floresta"]
        
        self.log(f"[STARTUP] Iniciando criação de {len(available_maps)} mapas...")
        
        for map_name in available_maps:
            self.log(f"[STARTUP] Criando mapa '{map_name}'...")
            map_instance = self.map_manager.get_or_create_map(map_name)
            self.log(f"[STARTUP] MapInstance criado: {type(map_instance).__name__}")
            self.log(f"[STARTUP] Enemies dict: {len(map_instance.enemies)} items")
            self.log(f"[STARTUP] Mapa '{map_name}' inicializado com {len(map_instance.enemies)} inimigos")
            
        self.log(f"[STARTUP] Todos os {len(available_maps)} mapas foram pré-criados com sucesso")
    
    def set_log_callback(self, callback):
        """Define callback para enviar logs para a interface"""
        self.log_callback = callback
        
    def log(self, message):
        """Envia log para interface, console e arquivo"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        
        # Remover emojis problemáticos e usar ASCII seguro
        safe_message = str(message).replace('✅', '[OK]').replace('❌', '[ERRO]').replace('🔗', '[NET]').replace('📊', '[INFO]').replace('🎮', '[GAME]').replace('👋', '[PLAYER]').replace('🗺️', '[MAP]').replace('📡', '[SYNC]').replace('⚡', '[FAST]').replace('🔌', '[CONN]').replace('🔄', '[PROC]')
        # Filtrar outros caracteres não-ASCII
        safe_message = safe_message.encode('ascii', errors='replace').decode('ascii')
        log_message = f"[{timestamp}] {safe_message}"
        print(log_message)
        
        # Enviar para interface
        if self.log_callback:
            self.log_callback(log_message)
        
        # Salvar no arquivo de log
        try:
            with open(self.log_file_path, "a", encoding="utf-8") as f:
                f.write(log_message + "\n")
        except Exception as e:
            print(f"Erro ao escrever log: {e}")
    
    async def register_client(self, websocket, path):
        """Registra novo cliente"""
        self.clients[websocket] = {
            "connected_at": datetime.now(),
            "player_id": None,
            "player_name": None
        }
        self.log(f"Nova conexão: {websocket.remote_address}")
        
        try:
            self.log(f"[WEBSOCKET] Iniciando loop de mensagens para {websocket.remote_address}")
            async for message in websocket:
                self.log(f"[WEBSOCKET] Loop recebeu mensagem de {websocket.remote_address}")
                await self.handle_message(websocket, message)
                self.log(f"[WEBSOCKET] Mensagem processada, continuando loop...")
            
            # Se chegou aqui, o loop terminou sem exception
            self.log(f"[WEBSOCKET] LOOP TERMINOU NORMALMENTE para {websocket.remote_address}")
            
        except websockets.exceptions.ConnectionClosed as e:
            self.log(f"[WEBSOCKET] ConnectionClosed para {websocket.remote_address}: {e}")
        except Exception as e:
            self.log(f"[WEBSOCKET] Exception na conexão {websocket.remote_address}: {e}")
            import traceback
            self.log(f"[WEBSOCKET] Traceback: {traceback.format_exc()}")
        finally:
            self.log(f"[WEBSOCKET] Chamando unregister_client para {websocket.remote_address}")
            await self.unregister_client(websocket)
    
    async def unregister_client(self, websocket):
        """Remove cliente desconectado"""
        if websocket in self.clients:
            client_data = self.clients[websocket]
            if client_data["player_id"]:
                player_id = client_data["player_id"]
                
                # Buscar dados do player server-side antes de remover
                player_name = "Unknown"
                current_map = "Cidade"
                for map_name, map_instance in self.map_manager.maps.items():
                    if map_instance.has_player(player_id):
                        server_player = map_instance.players[player_id]
                        player_name = server_player.name
                        current_map = map_name
                        # Persistir estado
                        try:
                            user = self.store.get_user_by_username(player_name)
                            if user:
                                char = self.store.get_character_by_user_id(user["id"])
                                if char:
                                    self.store.save_character_state(char["id"], {
                                        "map": map_name,
                                        "pos_x": server_player.position[0],
                                        "pos_y": server_player.position[1],
                                        "hp": server_player.hp,
                                    })
                        except Exception:
                            pass
                        # Remover player do mapa server-side
                        map_instance.remove_player(player_id)
                        break
                        
                # Notificar outros jogadores DO MESMO MAPA
                await self.broadcast_to_map(current_map, {
                    "type": "player_disconnected",
                    "player_id": player_id,
                    "player_name": player_name
                })
                
                # Atualizar lista de players para todos os mapas
                await self.broadcast_all_maps_players_update()
                
                self.log(f"Jogador desconectado: {player_name} (ID: {player_id})")
            
            del self.clients[websocket]
            self.log(f"Conexão removida: {websocket.remote_address}")
    
    async def handle_message(self, websocket, message):
        """Processa mensagens dos clientes"""
        try:
            self.log(f"[MESSAGE] Recebida mensagem de {websocket.remote_address}: {message[:100]}...")
            data = json.loads(message)
            message_type = data.get("type")
            self.log(f"[MESSAGE] Processando tipo: {message_type}")
            
            if message_type == "login":
                await self.handle_login(websocket, data)
            elif message_type == "register":
                await self.handle_register(websocket, data)
            elif message_type == "check_character_name":
                await self.handle_check_character_name(websocket, data)
            elif message_type == "create_character":
                await self.handle_create_character(websocket, data)
            elif message_type == "player_input":
                await self.handle_player_input(websocket, data)
            elif message_type == "player_update":
                # Ignorado no modo server-authoritative (cliente não altera estado)
                pass
            elif message_type == "player_action":
                await self.handle_player_action(websocket, data)
            elif message_type == "client_log":
                await self.handle_client_log(websocket, data)
            elif message_type == "map_change":
                await self.handle_map_change(websocket, data)
            elif message_type == "enemy_death":
                await self.handle_enemy_death(websocket, data)
            elif message_type == "enemy_damage":
                await self.handle_enemy_damage(websocket, data)
            elif message_type == "enemy_position_sync":
                await self.handle_enemy_position_sync(websocket, data)
            elif message_type == "player_attack_enemy":
                await self.handle_player_attack_enemy(websocket, data)
            elif message_type == "spend_attribute_point":
                await self.handle_spend_attribute_point(websocket, data)
            elif message_type == "request_enemies_state":
                await self.handle_request_enemies_state(websocket, data)
            else:
                self.log(f"Tipo de mensagem desconhecido: {message_type}")
            
            self.log(f"[MESSAGE] Processamento de {message_type} concluído com sucesso")
                
        except json.JSONDecodeError:
            self.log(f"[ERROR] Mensagem JSON inválida de {websocket.remote_address}")
        except Exception as e:
            self.log(f"[ERROR] Exception em handle_message: {str(e)}")
            import traceback
            self.log(f"[ERROR] Traceback: {traceback.format_exc()}")
            raise e  # Re-raise para fechar conexão
    
    async def handle_login(self, websocket, data):
        """Processa login com usuário e senha"""
        username = data.get("username", "").strip()
        password = data.get("password", "").strip()
        
        if not username or not password:
            await self.send_to_client(websocket, {
                "type": "login_response",
                "success": False,
                "message": "Usuário e senha são obrigatórios"
            })
            return
        
        # Verificar se usuário existe
        user = self.store.get_user_by_username(username)
        if not user:
            await self.send_to_client(websocket, {
                "type": "login_response", 
                "success": False,
                "message": "Usuário não encontrado"
            })
            return
        
        # Verificar senha
        if not user.get("pwd_hash") or not user.get("salt"):
            await self.send_to_client(websocket, {
                "type": "login_response",
                "success": False, 
                "message": "Conta sem senha configurada"
            })
            return
            
        if not verify_password(password, user["pwd_hash"], user["salt"]):
            await self.send_to_client(websocket, {
                "type": "login_response",
                "success": False,
                "message": "Senha incorreta"
            })
            return
        
        # Login válido - verificar se já tem personagem
        char_data = self.store.load_character_full(user["id"])
        
        if char_data:
            char, attrs = char_data
            # Já tem personagem - fazer login direto no jogo
            await self._login_with_character(websocket, user, char, attrs)
        else:
            # Não tem personagem - vai para seleção
            self.clients[websocket]["user_id"] = user["id"]
            self.clients[websocket]["username"] = username
            await self.send_to_client(websocket, {
                "type": "login_response",
                "success": True,
                "needs_character": True,
                "message": "Login realizado. Selecione um personagem."
            })
        
        self.log(f"Login realizado para usuário: {username}")
    
    async def handle_register(self, websocket, data):
        """Processa registro de novo usuário"""
        username = data.get("username", "").strip()
        password = data.get("password", "").strip()
        
        if not username or not password:
            await self.send_to_client(websocket, {
                "type": "register_response",
                "success": False,
                "message": "Usuário e senha são obrigatórios"
            })
            return
            
        if len(username) < 3 or len(password) < 6:
            await self.send_to_client(websocket, {
                "type": "register_response",
                "success": False,
                "message": "Usuário min 3 caracteres, senha min 6"
            })
            return
        
        # Verificar se usuário já existe
        user = self.store.get_user_by_username(username)
        if user:
            await self.send_to_client(websocket, {
                "type": "register_response",
                "success": False,
                "message": "Usuário já existe"
            })
            return
        
        # Criar novo usuário com senha
        pwd_hash, salt = hash_password(password)
        user_id = self.store.create_user(username, pwd_hash, salt)
        
        await self.send_to_client(websocket, {
            "type": "register_response", 
            "success": True,
            "message": "Usuário criado com sucesso! Faça login."
        })
        
        self.log(f"Novo usuário registrado: {username}")
    
    async def handle_check_character_name(self, websocket, data):
        """Verifica se nome do personagem está disponível"""
        character_name = data.get("character_name", "").strip()
        
        if not character_name:
            await self.send_to_client(websocket, {
                "type": "check_character_name_response",
                "success": False,
                "message": "Nome é obrigatório"
            })
            return
            
        if len(character_name) < 3:
            await self.send_to_client(websocket, {
                "type": "check_character_name_response", 
                "success": False,
                "message": "Nome deve ter pelo menos 3 caracteres"
            })
            return
        
        # Verificar se nome já existe
        char = self.store.get_character_by_name(character_name)
        if char:
            await self.send_to_client(websocket, {
                "type": "check_character_name_response",
                "success": False, 
                "message": "Nome já está em uso"
            })
            return
        
        await self.send_to_client(websocket, {
            "type": "check_character_name_response",
            "success": True,
            "message": "Nome disponível"
        })
    
    async def handle_create_character(self, websocket, data):
        """Cria novo personagem para o usuário"""
        client_data = self.clients.get(websocket)
        if not client_data or not client_data.get("user_id"):
            await self.send_to_client(websocket, {
                "type": "create_character_response",
                "success": False,
                "message": "Sessão inválida"
            })
            return
        
        character_name = data.get("character_name", "").strip()
        character_type = data.get("character_type", "").strip().lower()
        
        if not character_name or character_type not in ["warrior", "mage", "archer"]:
            await self.send_to_client(websocket, {
                "type": "create_character_response",
                "success": False,
                "message": "Dados inválidos"
            })
            return
        
        # Verificar novamente se nome está disponível
        char = self.store.get_character_by_name(character_name) 
        if char:
            await self.send_to_client(websocket, {
                "type": "create_character_response",
                "success": False,
                "message": "Nome já está em uso"
            })
            return
        
        # Definir atributos base por classe
        base_stats = {
            "warrior": {"strength": 8, "defense": 7, "intelligence": 3, "vitality": 7},
            "mage": {"strength": 3, "defense": 4, "intelligence": 8, "vitality": 5},  
            "archer": {"strength": 6, "defense": 5, "intelligence": 6, "vitality": 6}
        }
        
        defaults = {
            "level": 1, "xp": 0, "xp_max": 100, "attr_points": 0,
            "map": "Cidade", "pos_x": 0.0, "pos_y": 159.0,
            "hp": 100, "hp_max": 100,
            **base_stats[character_type]
        }
        
        # Criar personagem
        char_id = self.store.create_character(client_data["user_id"], character_name, character_type, defaults)
        
        # Fazer login no jogo
        user_id = client_data["user_id"]
        user = self.store.get_user_by_username(client_data["username"])
        char, attrs = self.store.load_character_full(user_id)
        
        await self._login_with_character(websocket, user, char, attrs)
        
        self.log(f"Personagem criado: {character_name} ({character_type}) para usuário {client_data['username']}")
    
    async def _login_with_character(self, websocket, user, char, attrs):
        """Faz login no jogo com personagem existente"""
        character_name = char["name"]
        
        # Verificar se personagem já está online
        for map_instance in self.map_manager.maps.values():
            for player in map_instance.players.values():
                if player.name.lower() == character_name.lower():
                    await self.send_to_client(websocket, {
                        "type": "login_response",
                        "success": False,
                        "message": "Personagem já está online"
                    })
                    return
        
        # Criar ID de sessão
        player_id = str(uuid.uuid4())[:8]
        initial_map = char.get("map", "Cidade")
        
        # Armazenar info do cliente
        self.clients[websocket]["player_id"] = player_id
        self.clients[websocket]["player_name"] = character_name
        self.clients[websocket]["user_id"] = user["id"] 
        self.clients[websocket]["character_type"] = char.get("character_type", "warrior")
        
        # Adicionar jogador ao mapa server-side  
        map_instance = self.map_manager.get_or_create_map(initial_map)
        actual_spawn_pos = map_instance.add_player(player_id, character_name)
        
        # Aplicar estado persistido
        try:
            sp = map_instance.players[player_id]
            sp.position = [float(char.get("pos_x", actual_spawn_pos.get("x", 0.0))), 
                          float(char.get("pos_y", actual_spawn_pos.get("y", 0.0)))]
            sp.hp = int(char.get("hp", 100))
            sp.level = int(char.get("level", 1))
            sp.xp = int(char.get("xp", 0))
            sp.xp_max = int(char.get("xp_max", 100))
            sp.attribute_points = int(char.get("attr_points", 0))
            sp.max_hp = int(char.get("hp_max", 100))
            if attrs:
                sp.strength = int(attrs.get("strength", 5))
                sp.defense_attr = int(attrs.get("defense", 5))
                sp.intelligence = int(attrs.get("intelligence", 5))
                sp.vitality = int(attrs.get("vitality", 5))
        except Exception:
            pass
        
        # Obter dados para resposta
        server_player_data = map_instance.get_player_data(player_id)
        if server_player_data:
            server_player_data["name"] = character_name
            server_player_data["character_type"] = char.get("character_type", "warrior")
        
        # Responder ao login
        await self.send_to_client(websocket, {
            "type": "login_response", 
            "success": True,
            "player_id": player_id,
            "player_info": server_player_data
        })
        
        # Enviar lista de players do mapa
        players_in_same_map = map_instance.get_players_data_dict()
        await self.send_to_client(websocket, {
            "type": "players_list",
            "players": players_in_same_map
        })
        
        # Notificar outros jogadores
        await self.broadcast_to_map(initial_map, {
            "type": "player_connected", 
            "player_info": server_player_data
        }, exclude=websocket)
        
        # Atualizar listas
        await self.broadcast_all_maps_players_update()
        
        self.log(f"Player {character_name} ({player_id}) entrou no mapa '{initial_map}'")
    
    async def handle_player_input(self, websocket, data):
        """Processa input do jogador (server-side authoritative)"""
        client_data = self.clients.get(websocket)
        if not client_data or not client_data["player_id"]:
            return
        
        player_id = client_data["player_id"]
        
        # Processar input no sistema server-side
        if not self.map_manager.process_player_input(player_id, data.get("input", data)):
            self.log(f"[WARNING] Player {player_id} não encontrado para processar input")
            return
        
        # Input processado com sucesso - ServerPlayer já fez toda validação, física e anti-cheat
    
    async def handle_player_update(self, websocket, data):
        """Processa atualização de estado do jogador"""
        client_data = self.clients.get(websocket)
        if not client_data or not client_data["player_id"]:
            return
        
        player_id = client_data["player_id"]
        
        # Encontrar player no MapManager e atualizar dados
        player_found = False
        for map_name, map_instance in self.map_manager.maps.items():
            if map_instance.has_player(player_id):
                server_player = map_instance.players[player_id]
                
                # Atualizar dados do player server-side
                if "position" in data:
                    pos = data["position"]
                    if "x" in pos and "y" in pos:
                        server_player.position = [pos["x"], pos["y"]]
                
                if "velocity" in data:
                    vel = data["velocity"]
                    if "x" in vel and "y" in vel:
                        server_player.velocity = [vel["x"], vel["y"]]
                
                if "animation" in data:
                    server_player.animation = data["animation"]
                
                if "facing" in data:
                    server_player.facing_direction = data["facing"]
                
                if "hp" in data:
                    server_player.hp = data["hp"]
                
                # Broadcast atualização para outros players do mesmo mapa
                await self.broadcast_to_map(map_name, {
                    "type": "player_sync",
                    "player_id": player_id,
                    "player_data": server_player.get_sync_data()
                }, exclude=websocket)
                
                player_found = True
                break
        
        if not player_found:
            self.log(f"[WARNING] Player {player_id} não encontrado em nenhum mapa para atualização")
    
    async def handle_player_action(self, websocket, data):
        """Processa ações dos jogadores (ataques, pulos, etc.)"""
        client_data = self.clients.get(websocket)
        if not client_data or not client_data["player_id"]:
            return
        
        player_id = client_data["player_id"]
        action = data.get("action")
        
        # Broadcast da ação para todos os jogadores
        await self.broadcast({
            "type": "player_action",
            "player_id": player_id,
            "action": action,
            "data": data.get("action_data", {})
        })
        
        self.log(f"Ação do jogador {client_data['player_name']}: {action}")
    
    async def handle_client_log(self, websocket, data):
        """Processa logs enviados pelos clientes"""
        client_data = self.clients.get(websocket)
        if not client_data:
            return
            
        log_message = data.get("message", "")
        instance_type = data.get("instance_type", "UNKNOWN")
        player_name = client_data.get("player_name", "Unknown")
        
        # Formatear o log do cliente no servidor
        formatted_log = f"[{instance_type}:{player_name}] {log_message}"
        self.log(formatted_log)
    
    async def handle_map_change(self, websocket, data):
        """Processa mudança de mapa do jogador"""
        try:
            self.log("[MAP_CHANGE] Iniciando processamento de mudança de mapa...")
            
            client_data = self.clients.get(websocket)
            if not client_data or not client_data["player_id"]:
                self.log("[MAP_CHANGE] ERROR: Client data inválido")
                return
            
            player_id = client_data["player_id"]
            new_map = data.get("current_map", "Cidade")
            self.log(f"[MAP_CHANGE] Player {player_id} quer ir para: {new_map}")
            
            # Obter mapa atual do player
            old_map = None
            for map_name, map_instance in self.map_manager.maps.items():
                if map_instance.has_player(player_id):
                    old_map = map_name
                    break
            
            if not old_map:
                old_map = "Cidade"  # Default se player nao encontrado em nenhum mapa
            
            self.log(f"[MAP_CHANGE] Mapa atual: {old_map} -> Novo mapa: {new_map}")
            
            # Se o mapa for o mesmo, não mover/respawnar
            if old_map == new_map:
                self.log(f"[MAP_CHANGE] Ignorando: player já está em {new_map}")
                await self.broadcast_all_maps_players_update()
                return

            # USAR MapManager para mover player entre mapas (server-side)
            self.log("[MAP_CHANGE] Chamando map_manager.move_player()...")
            spawn_position, success = self.map_manager.move_player(player_id, old_map, new_map, client_data["player_name"])
            
            if success:
                # Player ja foi movido pelo MapManager (sistema server-side)
                self.log(f"[MAP_MANAGER] Player {client_data['player_name']} movido: {old_map} -> {new_map}")
                
                # Notificar players do mapa ANTIGO que este player saiu
                if old_map != new_map:
                    self.log(f"[MAP_CHANGE] Notificando mapa {old_map} que player saiu...")
                    await self.broadcast_to_map(old_map, {
                        "type": "player_left_map",
                        "player_id": player_id
                    })
                
                # Notificar players do mapa NOVO que este player chegou
                self.log(f"[MAP_CHANGE] Notificando mapa {new_map} que player chegou...")
                await self.broadcast_to_map(new_map, {
                    "type": "map_change",
                    "player_id": player_id,
                    "current_map": new_map,
                    "spawn_position": spawn_position
                }, exclude=websocket)
                
                # Atualizar listas de players para todos os mapas
                self.log("[MAP_CHANGE] Atualizando listas de players...")
                await self.broadcast_all_maps_players_update()
                
                self.log(f"[PLAYER] Player {client_data['player_name']} agora no mapa: {new_map}")
                self.log("[MAP_CHANGE] Processamento completo com sucesso!")
            else:
                self.log(f"[ERROR] Falha ao mover player {client_data['player_name']} para {new_map}")
        except Exception as e:
            self.log(f"[MAP_CHANGE] EXCEPTION: {str(e)}")
            import traceback
            self.log(f"[MAP_CHANGE] TRACEBACK: {traceback.format_exc()}")
            raise e  # Re-raise para debug
    
    async def handle_enemy_death(self, websocket, data):
        """Processa morte de inimigo"""
        client_data = self.clients.get(websocket)
        if not client_data or not client_data["player_id"]:
            return
        
        enemy_id = data.get("enemy_id", "")
        enemy_position = data.get("position", {})
        killer_id = data.get("killer_id", "")
        
        # Broadcast para outros jogadores
        await self.broadcast({
            "type": "enemy_death",
            "enemy_id": enemy_id,
            "position": enemy_position,
            "killer_id": killer_id
        }, exclude=websocket)
        
        self.log(f"Inimigo {enemy_id} morto por {client_data['player_name']}")
    
    async def handle_enemy_damage(self, websocket, data):
        """Processa dano ao inimigo"""
        client_data = self.clients.get(websocket)
        if not client_data or not client_data["player_id"]:
            return
        
        enemy_id = data.get("enemy_id", "")
        damage = data.get("damage", 0)
        new_hp = data.get("new_hp", 0)
        attacker_id = data.get("attacker_id", "")
        
        # Broadcast para outros jogadores
        await self.broadcast({
            "type": "enemy_damage",
            "enemy_id": enemy_id,
            "damage": damage,
            "new_hp": new_hp,
            "attacker_id": attacker_id
        }, exclude=websocket)
        
        self.log(f"Inimigo {enemy_id} recebeu {damage} dano de {client_data['player_name']} (HP: {new_hp})")
    
    async def handle_enemy_position_sync(self, websocket, data):
        """Processa sincronização de posição de inimigo"""
        client_data = self.clients.get(websocket)
        if not client_data or not client_data["player_id"]:
            return
        
        enemy_id = data.get("enemy_id", "")
        position = data.get("position", {})
        velocity = data.get("velocity", {})
        flip_h = data.get("flip_h", False)
        animation = data.get("animation", "idle")
        owner_id = data.get("owner_id", "")
        
        # Broadcast para outros jogadores
        await self.broadcast({
            "type": "enemy_position_sync",
            "enemy_id": enemy_id,
            "position": position,
            "velocity": velocity,
            "flip_h": flip_h,
            "animation": animation,
            "owner_id": owner_id
        }, exclude=websocket)
        
        # Log menos frequente para posição (opcional)
        # self.log(f"Posição do inimigo {enemy_id} sincronizada por {client_data['player_name']}")
    
    async def handle_player_attack_enemy(self, websocket, data):
        """Processa ataque de player a inimigo (server-side)"""
        client_data = self.clients.get(websocket)
        if not client_data or not client_data["player_id"]:
            return
        
        enemy_id = data.get("enemy_id", "")
        damage = data.get("damage", 0)
        attacker_id = client_data["player_id"]
        
        # Encontrar em qual mapa o atacante está (sistema server-side)
        attacker_map = None
        for map_name, map_instance in self.map_manager.maps.items():
            if map_instance.has_player(attacker_id):
                attacker_map = map_name
                break
        
        if not attacker_map:
            return
        
        # Processar dano no mapa específico usando MapManager
        result = self.map_manager.damage_enemy(attacker_map, enemy_id, damage, attacker_id)
        
        if result:
            # Broadcast resultado (suporta lista de eventos)
            if isinstance(result, list):
                for ev in result:
                    # Persistir stats em eventos de update
                    if isinstance(ev, dict) and ev.get("type") == "player_stats_update":
                        try:
                            player_id_ev = ev.get("player_id")
                            map_instance = self.map_manager.maps.get(attacker_map)
                            if map_instance and player_id_ev in map_instance.players:
                                sp = map_instance.players[player_id_ev]
                                user = self.store.get_user_by_username(sp.name)
                                if user:
                                    char = self.store.get_character_by_user_id(user["id"])
                                    if char:
                                        self.store.save_character_state(char["id"], {
                                            "level": sp.level,
                                            "xp": sp.xp,
                                            "xp_max": sp.xp_max,
                                            "attr_points": sp.attribute_points,
                                            "map": attacker_map,
                                            "pos_x": sp.position[0],
                                            "pos_y": sp.position[1],
                                            "hp": sp.hp,
                                            "hp_max": sp.max_hp,
                                        })
                                        self.store.save_character_attributes(char["id"], {
                                            "strength": sp.strength,
                                            "defense": sp.defense_attr,
                                            "intelligence": sp.intelligence,
                                            "vitality": sp.vitality,
                                        })
                        except Exception as e:
                            self.log(f"[DB][WARNING] Falha ao persistir stats: {e}")
                    await self.broadcast_to_map(attacker_map, ev)
            else:
                await self.broadcast_to_map(attacker_map, result)
        
        self.log(f"Player {client_data['player_name']} atacou inimigo {enemy_id} por {damage} dano no mapa {attacker_map}")
    
    async def handle_request_enemies_state(self, websocket, data):
        """Envia estado atual dos inimigos para um cliente"""
        client_data = self.clients.get(websocket)
        if not client_data or not client_data["player_id"]:
            return
        
        map_name = data.get("map_name", "Cidade")
        
        # NOVO: Usar MapManager para obter inimigos do mapa (criar se necessário)
        map_instance = self.map_manager.get_or_create_map(map_name)
        enemies_state = map_instance.get_enemies_data()
        
        # DEBUG: Mostrar dados de cada inimigo
        self.log(f"DEBUG - Preparando envio de {len(enemies_state)} inimigos para '{map_name}':")
        for i, enemy_data in enumerate(enemies_state):
            self.log(f"  Inimigo {i+1}: {enemy_data.get('enemy_id')} pos=({enemy_data.get('x')},{enemy_data.get('y')})")
        
        await self.send_to_client(websocket, {
            "type": "enemies_state",
            "map_name": map_name,
            "enemies": enemies_state
        })
        
        self.log(f"Enviado estado de {len(enemies_state)} inimigos do mapa '{map_name}' para {client_data['player_name']}")

    async def handle_spend_attribute_point(self, websocket, data):
        """Gasta 1 ponto de atributo do player (server-authoritative)"""
        client_data = self.clients.get(websocket)
        if not client_data or not client_data.get("player_id"):
            return
        attr = str(data.get("attr", "")).strip().lower()
        if attr not in ("strength", "defense", "intelligence", "vitality"):
            return
        player_id = client_data["player_id"]

        # Encontrar player e mapa
        current_map = None
        map_instance = None
        for map_name, mi in self.map_manager.maps.items():
            if mi.has_player(player_id):
                current_map = map_name
                map_instance = mi
                break
        if not map_instance:
            return

        sp = map_instance.players.get(player_id)
        if not sp:
            return

        # Aplicar ponto de atributo
        if sp.add_attribute_point(attr):
            # Persistir no DB
            try:
                user = self.store.get_user_by_username(sp.name)
                if user:
                    char = self.store.get_character_by_user_id(user["id"])
                    if char:
                        self.store.save_character_state(char["id"], {
                            "level": sp.level,
                            "xp": sp.xp,
                            "xp_max": sp.xp_max,
                            "attr_points": sp.attribute_points,
                            "map": current_map,
                            "pos_x": sp.position[0],
                            "pos_y": sp.position[1],
                            "hp": sp.hp,
                            "hp_max": sp.max_hp,
                        })
                        self.store.save_character_attributes(char["id"], {
                            "strength": sp.strength,
                            "defense": sp.defense_attr,
                            "intelligence": sp.intelligence,
                            "vitality": sp.vitality,
                        })
            except Exception as e:
                self.log(f"[DB][WARNING] Falha ao persistir ponto de atributo: {e}")

            # Notificar cliente (e demais do mapa) com stats atualizados
            stats_ev = {
                "type": "player_stats_update",
                "player_id": sp.player_id,
                "player_name": sp.name,
                "stats": sp.to_stats_dict(),
            }
            await self.broadcast_to_map(current_map, stats_ev)
    
    async def send_to_client(self, websocket, data):
        """Envia mensagem para um cliente específico"""
        try:
            await websocket.send(json.dumps(data))
        except websockets.exceptions.ConnectionClosed:
            pass
        except Exception as e:
            self.log(f"Erro ao enviar mensagem: {e}")
    
    async def broadcast(self, data, exclude=None):
        """Envia mensagem para todos os clientes conectados"""
        if not self.clients:
            return
        
        message = json.dumps(data)
        disconnected = []
        
        for websocket in self.clients:
            if websocket != exclude:
                try:
                    await websocket.send(message)
                except websockets.exceptions.ConnectionClosed:
                    disconnected.append(websocket)
                except Exception as e:
                    self.log(f"Erro no broadcast: {e}")
                    disconnected.append(websocket)
        
        # Remove conexões mortas
        for websocket in disconnected:
            await self.unregister_client(websocket)
    
    def get_players_in_map(self, map_name: str) -> dict:
        """Retorna apenas os players que estão no mapa especificado (server-side)"""
        map_instance = self.map_manager.maps.get(map_name)
        if map_instance:
            return map_instance.get_players_data_dict()
        return {}
    
    async def send_players_list_to_client(self, websocket):
        """Envia lista de players filtrada por mapa para um cliente específico"""
        client_data = self.clients.get(websocket)
        if not client_data or not client_data.get("player_id"):
            return
            
        player_id = client_data["player_id"]
        
        # Buscar player server-side em todos os mapas
        current_map = None
        server_player = None
        for map_name, map_instance in self.map_manager.maps.items():
            if player_id in map_instance.players:
                current_map = map_name
                server_player = map_instance.players[player_id]
                break
        
        if not current_map:
            return
        
        # Filtrar players apenas do mesmo mapa (formato Dictionary para cliente)
        players_in_same_map = self.map_manager.get_players_in_map_dict(current_map)
        
        # Enviar apenas para este cliente
        await self.send_to_client(websocket, {
            "type": "players_list",
            "players": players_in_same_map
        })
        
        self.log(f"Enviada lista de {len(players_in_same_map)} players do mapa '{current_map}' para {client_data.get('player_name', 'Unknown')}")
    
    async def broadcast_players_list_update(self):
        """Envia lista atualizada de players para todos os clientes (filtrada por mapa)"""
        for websocket in list(self.clients.keys()):
            await self.send_players_list_to_client(websocket)
    
    async def broadcast_to_map(self, map_name: str, data: dict, exclude=None):
        """Envia mensagem apenas para players de um mapa específico"""
        if map_name not in self.map_manager.maps:
            return
        
        map_instance = self.map_manager.maps[map_name]
        target_players = set(map_instance.players.keys())
        
        message = json.dumps(data)
        for websocket in list(self.clients.keys()):
            if websocket == exclude:
                continue
                
            client_data = self.clients.get(websocket)
            if not client_data or not client_data.get("player_id"):
                continue
                
            if client_data["player_id"] in target_players:
                try:
                    await websocket.send(message)
                except Exception as e:
                    self.log(f"Erro ao enviar para player no mapa {map_name}: {e}")
    
    async def broadcast_all_maps_players_update(self):
        """Atualiza lista de players para todos os mapas usando MapManager"""
        try:
            self.log("[BROADCAST] Iniciando broadcast_all_maps_players_update...")
            for websocket in list(self.clients.keys()):
                client_data = self.clients.get(websocket)
                if not client_data or not client_data.get("player_id"):
                    continue
                    
                player_id = client_data["player_id"]
                self.log(f"[BROADCAST] Processando player {player_id}...")
                
                # Encontrar em qual mapa o player está
                current_map = None
                for map_name, map_instance in self.map_manager.maps.items():
                    if map_instance.has_player(player_id):
                        current_map = map_name
                        break
                
                if current_map:
                    self.log(f"[BROADCAST] Player {player_id} está no mapa {current_map}")
                    players_in_map = self.map_manager.get_players_in_map_dict(current_map)
                    self.log(f"[BROADCAST] Enviando lista com {len(players_in_map)} players...")
                    await self.send_to_client(websocket, {
                        "type": "players_list",
                        "players": players_in_map
                    })
                    self.log(f"[BROADCAST] Lista enviada com sucesso para {player_id}")
                else:
                    self.log(f"[BROADCAST] WARNING: Player {player_id} não encontrado em nenhum mapa")
            
            self.log("[BROADCAST] broadcast_all_maps_players_update concluído")
        except Exception as e:
            self.log(f"[BROADCAST] EXCEPTION: {str(e)}")
            import traceback
            self.log(f"[BROADCAST] TRACEBACK: {traceback.format_exc()}")
            raise e
    
    async def start_server(self):
        """Inicia o servidor"""
        if self.running:
            return False
        
        try:
            self.server = await websockets.serve(
                self.register_client,
                self.host,
                self.port
            )
            self.running = True
            self.log(f"Servidor iniciado em ws://{self.host}:{self.port}")
            
            # Iniciar loops de atualização
            self.enemy_update_task = asyncio.create_task(self._enemy_update_loop())
            self.player_update_task = asyncio.create_task(self._player_update_loop())
            
            return True
        except Exception as e:
            self.log(f"Erro ao iniciar servidor: {e}")
            return False
    
    async def stop_server(self):
        """Para o servidor"""
        if not self.running or not self.server:
            return
        
        self.running = False
        
        # Notificar todos os clientes
        await self.broadcast({
            "type": "server_shutdown",
            "message": "Servidor será desligado"
        })
        
        # Fechar servidor
        self.server.close()
        await self.server.wait_closed()
        
        # Limpar dados
        self.clients.clear()
        # self.players removido - agora usando sistema server-side
        
        self.log("Servidor parado")
        
        # Parar loops de atualização
        if self.enemy_update_task:
            self.enemy_update_task.cancel()
        if hasattr(self, 'player_update_task') and self.player_update_task:
            self.player_update_task.cancel()
    
    async def _enemy_update_loop(self):
        """Loop principal de atualização dos inimigos usando MapManager"""
        while self.running:
            try:
                # NOVO: Usar MapManager para atualizar inimigos por mapa
                delta_time = 1/60  # 60 FPS
                all_enemy_updates = self.map_manager.update_all_enemies(delta_time)
                
                # Broadcast atualizações para cada mapa específico
                for map_name, updated_enemies in all_enemy_updates.items():
                    if updated_enemies:
                        await self.broadcast_to_map(map_name, {
                            "type": "enemies_update",
                            "enemies": updated_enemies
                        })
                # Sempre verificar eventos extras (ex.: dano em player), mesmo sem updates
                for map_name, map_inst in self.map_manager.maps.items():
                    try:
                        extra_events = getattr(map_inst, "_last_enemy_events", [])
                        if extra_events:
                            for ev in extra_events:
                                await self.broadcast_to_map(map_name, ev)
                            map_inst._last_enemy_events = []
                    except Exception as e:
                        self.log(f"[ENEMY_LOOP] Falha ao enviar eventos extras: {e}")
                    try:
                        map_inst = self.map_manager.maps.get(map_name)
                        extra_events = getattr(map_inst, "_last_enemy_events", []) if map_inst else []
                        if extra_events:
                            for ev in extra_events:
                                await self.broadcast_to_map(map_name, ev)
                            map_inst._last_enemy_events = []
                    except Exception as e:
                        self.log(f"[ENEMY_LOOP] Falha ao enviar eventos extras: {e}")
                
                # Cleanup mapas vazios ocasionalmente
                if len(all_enemy_updates) % 3600 == 0:  # A cada 60 segundos (60fps * 60s)
                    self.map_manager.cleanup_empty_maps()
                
                # Aguardar próximo frame (60 FPS)
                await asyncio.sleep(1/60)
                
            except asyncio.CancelledError:
                break
            except Exception as e:
                self.log(f"Erro no loop de inimigos: {e}")
    
    async def _player_update_loop(self):
        """Loop principal de atualização dos players usando MapManager"""
        while self.running:
            try:
                # Atualizar players em todos os mapas
                delta_time = 1/60  # 60 FPS
                all_player_updates = self.map_manager.update_all_players(delta_time)
                
                # Broadcast atualizações para cada mapa específico
                for map_name, updated_players in all_player_updates.items():
                    if updated_players:
                        # Converter lista [{id:..., ...}] para dicionário {id: {...}}
                        try:
                            players_by_id = {p.get("id"): p for p in updated_players if isinstance(p, dict) and p.get("id")}
                        except Exception:
                            players_by_id = {}
                            for p in updated_players:
                                if isinstance(p, dict) and p.get("id"):
                                    players_by_id[p["id"]] = p

                        await self.broadcast_to_map(map_name, {
                            "type": "players_update",
                            "players": players_by_id
                        })
                
                # Aguardar próximo frame (60 FPS)
                await asyncio.sleep(1/60)
                
            except asyncio.CancelledError:
                break
            except Exception as e:
                self.log(f"Erro no loop de players: {e}")
    
    def get_status(self):
        """Retorna status do servidor"""
        # Contar inimigos em todos os mapas
        enemies_count = 0
        for map_instance in self.map_manager.maps.values():
            enemies_count += len(map_instance.enemies)
            
        return {
            "running": self.running,
            "clients_connected": len(self.clients),
            "players_online": self.map_manager.get_total_players_count(),
            "host": self.host,
            "port": self.port,
            "enemies_count": enemies_count,
            "maps_active": len(self.map_manager.maps)
        }


if __name__ == "__main__":
    """Executa servidor diretamente sem GUI"""
    print("PROJETO ALLY - SERVIDOR MULTIPLAYER")
    print("Iniciando servidor...")
    
    server = GameServer()
    
    try:
        loop = asyncio.get_event_loop()
        success = loop.run_until_complete(server.start_server())
        if success:
            print("Servidor rodando. Pressione Ctrl+C para parar.")
            loop.run_forever()
    except KeyboardInterrupt:
        print("\nServidor interrompido pelo usuário")
        loop.run_until_complete(server.stop_server())
    except Exception as e:
        print(f"Erro crítico: {e}")
    finally:
        print("Servidor encerrado")
