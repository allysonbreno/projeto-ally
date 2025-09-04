import asyncio
import websockets
import json
import threading
from datetime import datetime
import uuid
from enemy_server import EnemyManager

class GameServer:
    def __init__(self):
        self.clients = {}  # {websocket: player_data}
        self.players = {}  # {player_id: player_info}
        self.server = None
        self.running = False
        self.host = "localhost"
        self.port = 8765
        self.log_callback = None
        import os
        self.log_file_path = os.path.join(os.path.dirname(__file__), "../../logs_servidor.txt")
        self._init_log_file()
        
        # Sistema de inimigos server-side
        self.enemy_manager = EnemyManager()
        self.enemy_manager.initialize_forest_enemies()
        self.enemy_update_task = None
        
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
    
    def set_log_callback(self, callback):
        """Define callback para enviar logs para a interface"""
        self.log_callback = callback
        
    def log(self, message):
        """Envia log para interface, console e arquivo"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        log_message = f"[{timestamp}] {message}"
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
            async for message in websocket:
                await self.handle_message(websocket, message)
        except websockets.exceptions.ConnectionClosed:
            self.log(f"Conexão fechada: {websocket.remote_address}")
        except Exception as e:
            self.log(f"Erro na conexão {websocket.remote_address}: {e}")
        finally:
            await self.unregister_client(websocket)
    
    async def unregister_client(self, websocket):
        """Remove cliente desconectado"""
        if websocket in self.clients:
            client_data = self.clients[websocket]
            if client_data["player_id"]:
                # Remover player da lista
                if client_data["player_id"] in self.players:
                    player_name = self.players[client_data["player_id"]]["name"]
                    del self.players[client_data["player_id"]]
                    
                    # Notificar outros jogadores
                    await self.broadcast({
                        "type": "player_disconnected",
                        "player_id": client_data["player_id"],
                        "player_name": player_name
                    }, exclude=websocket)
                    
                    self.log(f"Jogador desconectado: {player_name} (ID: {client_data['player_id']})")
            
            del self.clients[websocket]
            self.log(f"Conexão removida: {websocket.remote_address}")
    
    async def handle_message(self, websocket, message):
        """Processa mensagens dos clientes"""
        try:
            data = json.loads(message)
            message_type = data.get("type")
            
            if message_type == "login":
                await self.handle_login(websocket, data)
            elif message_type == "player_update":
                await self.handle_player_update(websocket, data)
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
            elif message_type == "request_enemies_state":
                await self.handle_request_enemies_state(websocket, data)
            else:
                self.log(f"Tipo de mensagem desconhecido: {message_type}")
                
        except json.JSONDecodeError:
            self.log(f"Mensagem JSON inválida de {websocket.remote_address}")
        except Exception as e:
            self.log(f"Erro ao processar mensagem: {e}")
    
    async def handle_login(self, websocket, data):
        """Processa login do jogador"""
        player_name = data.get("player_name", "").strip()
        
        if not player_name:
            await self.send_to_client(websocket, {
                "type": "login_response",
                "success": False,
                "message": "Nome do jogador é obrigatório"
            })
            return
        
        # Verificar se nome já existe
        for pid, pinfo in self.players.items():
            if pinfo["name"].lower() == player_name.lower():
                await self.send_to_client(websocket, {
                    "type": "login_response",
                    "success": False,
                    "message": "Nome já está em uso"
                })
                return
        
        # Criar novo jogador
        player_id = str(uuid.uuid4())[:8]
        
        # Posições de spawn por mapa
        spawn_positions = {
            "Cidade": {"x": 100, "y": 159},  # Acima do chão da cidade (Y=189)
            "Floresta": {"x": -512, "y": 184}  # Acima do chão da floresta (Y=204)
        }
        initial_map = "Cidade"
        spawn_pos = spawn_positions.get(initial_map, spawn_positions["Cidade"])
        
        player_info = {
            "id": player_id,
            "name": player_name,
            "position": spawn_pos,
            "velocity": {"x": 0, "y": 0},
            "animation": "idle",
            "facing": 1,
            "hp": 100,
            "current_map": initial_map,
            "connected_at": datetime.now().isoformat()
        }
        
        # 1. Adicionar jogador à lista PRIMEIRO
        self.players[player_id] = player_info
        self.clients[websocket]["player_id"] = player_id
        self.clients[websocket]["player_name"] = player_name
        
        self.log(f"ADICIONADO jogador {player_name} (ID: {player_id})")
        self.log(f"Lista atual COMPLETA: {list(self.players.keys())}")
        
        # 2. Responder ao login
        await self.send_to_client(websocket, {
            "type": "login_response",
            "success": True,
            "player_id": player_id,
            "player_info": player_info
        })
        
        # 3. Enviar lista COMPLETA de jogadores (incluindo todos)
        self.log(f"ENVIANDO players_list para {player_name} com {len(self.players)} jogadores")
        await self.send_to_client(websocket, {
            "type": "players_list", 
            "players": dict(self.players)  # Enviar cópia completa
        })
        
        self.log(f"ENVIADO players_list para {player_name}: {list(self.players.keys())}")
        
        # Notificar outros jogadores sobre novo jogador
        await self.broadcast({
            "type": "player_connected",
            "player_info": player_info
        }, exclude=websocket)
        
        # IMPORTANTE: Enviar lista atualizada para TODOS os clientes conectados
        self.log(f"Enviando players_list atualizada para todos os {len(self.clients)} clientes")
        await self.broadcast({
            "type": "players_list",
            "players": dict(self.players)
        })
        
        self.log(f"Login realizado: {player_name} (ID: {player_id})")
    
    async def handle_player_update(self, websocket, data):
        """Processa atualizações de posição/estado do jogador com validação server-side"""
        client_data = self.clients.get(websocket)
        if not client_data or not client_data["player_id"]:
            return
        
        player_id = client_data["player_id"]
        if player_id not in self.players:
            return
        
        # Atualizar dados do jogador
        player_info = self.players[player_id]
        
        # Validação de movimento server-side (anti-cheat ajustado)
        if "position" in data:
            old_pos = player_info.get("position", {"x": 0, "y": 0})
            new_pos = data["position"]
            
            # Calcular distância horizontal (excluir gravidade do anti-cheat)
            horizontal_distance = abs(new_pos["x"] - old_pos["x"])
            vertical_distance = abs(new_pos["y"] - old_pos["y"])
            
            # Limites mais realistas
            max_horizontal_speed = 500.0  # pixels por segundo
            max_vertical_speed = 1000.0   # permitir queda rápida (gravidade)
            time_delta = 0.25   # intervalo máximo entre updates
            max_horizontal_distance = max_horizontal_speed * time_delta
            max_vertical_distance = max_vertical_speed * time_delta
            
            # Validar apenas movimento horizontal suspeito
            if horizontal_distance <= max_horizontal_distance:
                player_info["position"] = data["position"]
            else:
                # Apenas movimento horizontal suspeito - manter Y
                player_info["position"] = {
                    "x": old_pos["x"] + (max_horizontal_distance if new_pos["x"] > old_pos["x"] else -max_horizontal_distance),
                    "y": new_pos["y"]  # Permitir movimento vertical livre (gravidade)
                }
                self.log(f"⚠️ Movimento horizontal suspeito de {client_data['player_name']}: {horizontal_distance:.1f}px em {time_delta}s")
        
        if "velocity" in data:
            player_info["velocity"] = data["velocity"]
        if "animation" in data:
            player_info["animation"] = data["animation"]
        if "facing" in data:
            player_info["facing"] = data["facing"]
        if "hp" in data:
            player_info["hp"] = data["hp"]
        
        # Adicionar timestamp e sequence para reconciliação
        import time
        player_info["server_timestamp"] = time.time()
        player_info["sequence"] = data.get("sequence", 0)
        
        # Broadcast para outros jogadores (incluindo dados para reconciliação)
        await self.broadcast({
            "type": "player_sync",
            "player_id": player_id,
            "player_info": player_info
        }, exclude=websocket)
        
        # Resposta de confirmação para o cliente (para reconciliação)
        await self.send_to_client(websocket, {
            "type": "player_sync_ack",
            "sequence": data.get("sequence", 0),
            "position": player_info["position"],
            "velocity": player_info["velocity"],
            "server_timestamp": player_info["server_timestamp"]
        })
    
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
        client_data = self.clients.get(websocket)
        if not client_data or not client_data["player_id"]:
            return
        
        player_id = client_data["player_id"]
        current_map = data.get("current_map", "Cidade")
        
        # Posições de spawn por mapa
        spawn_positions = {
            "Cidade": {"x": 100, "y": 159},  # Acima do chão da cidade (Y=189)
            "Floresta": {"x": -512, "y": 184}  # Acima do chão da floresta (Y=204)
        }
        
        # Atualizar dados do jogador
        if player_id in self.players:
            self.players[player_id]["current_map"] = current_map
            # Atualizar posição para o spawn do novo mapa
            new_position = spawn_positions.get(current_map, spawn_positions["Cidade"])
            self.players[player_id]["position"] = new_position
            self.log(f"Player {client_data['player_name']} spawn em {current_map}: {new_position}")
        
        # Broadcast para outros jogadores
        await self.broadcast({
            "type": "map_change",
            "player_id": player_id,
            "current_map": current_map,
            "spawn_position": new_position
        }, exclude=websocket)
        
        self.log(f"Player {client_data['player_name']} mudou para mapa: {current_map}")
    
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
        
        # Processar dano no servidor
        result = self.enemy_manager.damage_enemy(enemy_id, damage, attacker_id)
        
        if result:
            # Broadcast resultado para todos os jogadores
            await self.broadcast(result)
        
        self.log(f"Player {client_data['player_name']} atacou inimigo {enemy_id} por {damage} dano")
    
    async def handle_request_enemies_state(self, websocket, data):
        """Envia estado atual dos inimigos para um cliente"""
        client_data = self.clients.get(websocket)
        if not client_data or not client_data["player_id"]:
            return
        
        map_name = data.get("map_name", "Cidade")
        enemies_state = self.enemy_manager.get_enemies_in_map(map_name)
        
        await self.send_to_client(websocket, {
            "type": "enemies_state",
            "map_name": map_name,
            "enemies": enemies_state
        })
        
        self.log(f"Enviado estado de {len(enemies_state)} inimigos para {client_data['player_name']}")
    
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
            
            # Iniciar loop de atualização de inimigos
            self.enemy_update_task = asyncio.create_task(self._enemy_update_loop())
            
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
        self.players.clear()
        
        self.log("Servidor parado")
        
        # Parar loop de inimigos
        if self.enemy_update_task:
            self.enemy_update_task.cancel()
    
    async def _enemy_update_loop(self):
        """Loop principal de atualização dos inimigos"""
        while self.running:
            try:
                # Atualizar inimigos
                updated_enemies = self.enemy_manager.update_enemies(self.players)
                
                # Broadcast atualizações se houver mudanças
                if updated_enemies:
                    await self.broadcast({
                        "type": "enemies_update",
                        "enemies": updated_enemies
                    })
                
                # Aguardar próximo frame (60 FPS)
                await asyncio.sleep(1/60)
                
            except asyncio.CancelledError:
                break
            except Exception as e:
                self.log(f"Erro no loop de inimigos: {e}")
    
    def get_status(self):
        """Retorna status do servidor"""
        return {
            "running": self.running,
            "clients_connected": len(self.clients),
            "players_online": len(self.players),
            "host": self.host,
            "port": self.port,
            "enemies_count": len(self.enemy_manager.enemies)
        }