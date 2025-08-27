import asyncio
import websockets
import json
import threading
from datetime import datetime
import uuid

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
        
        player_info = {
            "id": player_id,
            "name": player_name,
            "position": {"x": 100, "y": 350},  # Posição inicial
            "velocity": {"x": 0, "y": 0},
            "animation": "idle",
            "facing": 1,
            "hp": 100,
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
        """Processa atualizações de posição/estado do jogador"""
        client_data = self.clients.get(websocket)
        if not client_data or not client_data["player_id"]:
            return
        
        player_id = client_data["player_id"]
        if player_id not in self.players:
            return
        
        # Atualizar dados do jogador
        player_info = self.players[player_id]
        
        if "position" in data:
            player_info["position"] = data["position"]
        if "velocity" in data:
            player_info["velocity"] = data["velocity"]
        if "animation" in data:
            player_info["animation"] = data["animation"]
        if "facing" in data:
            player_info["facing"] = data["facing"]
        if "hp" in data:
            player_info["hp"] = data["hp"]
        
        # Broadcast para outros jogadores
        await self.broadcast({
            "type": "player_sync",
            "player_id": player_id,
            "player_info": player_info
        }, exclude=websocket)
    
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
    
    def get_status(self):
        """Retorna status do servidor"""
        return {
            "running": self.running,
            "clients_connected": len(self.clients),
            "players_online": len(self.players),
            "host": self.host,
            "port": self.port
        }