import time
from typing import Dict, List, Optional, Tuple
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from enemies.multiplayer_enemy import MultiplayerEnemy
from enemies.orc_enemy import OrcEnemy
from players.server_player import ServerPlayer


class MapInstance:
    """
    Representa uma instância de mapa no servidor.
    Gerencia players, inimigos e estado específicos de cada mapa.
    """
    
    def __init__(self, map_name: str):
        self.map_name = map_name
        self.players: Dict[str, ServerPlayer] = {}  # player_id -> ServerPlayer instance
        self.enemies: Dict[str, MultiplayerEnemy] = {}  # enemy_id -> enemy_instance
        self.active = True
        self.created_at = time.time()
        self.last_activity = time.time()
        
        # Sistema de respawn infinito - otimizado
        self.respawn_queue: List[dict] = []  # Lista de inimigos aguardando respawn
        self.respawn_delay = 3.0  # 3 segundos de delay para respawn
        self.infinite_respawn = True  # Respawn infinito habilitado
        self.last_revival_check = 0.0  # Cooldown para processamento de revival
        
        # Configurações específicas por mapa
        self.spawn_positions = self._get_spawn_positions()
        
        # Inicializar inimigos do mapa
        print(f"[MAP:{self.map_name}] CONSTRUTOR: Chamando _initialize_enemies()...")
        self._initialize_enemies()
        print(f"[MAP:{self.map_name}] CONSTRUTOR: _initialize_enemies() finalizado. Total: {len(self.enemies)}")
    
    def _get_spawn_positions(self) -> dict:
        """Retorna posições de spawn por mapa"""
        spawn_configs = {
            "Cidade": {"x": 100, "y": 159},
            "Floresta": {"x": -512, "y": 184}
        }
        return spawn_configs.get(self.map_name, {"x": 0, "y": 0})
    
    def _initialize_enemies(self):
        """Inicializa inimigos específicos do mapa"""
        print(f"[MAP:{self.map_name}] Inicializando inimigos...")
        
        if self.map_name == "Floresta":
            # Criar orcs na floresta
            spawn_positions = [(-200, 184), (-100, 184), (0, 184), (100, 184), (200, 184)]
            print(f"[MAP:{self.map_name}] Criando {len(spawn_positions)} orcs...")
            
            for i, (x, y) in enumerate(spawn_positions):
                enemy_id = f"orc_{int(x)}_{int(y)}"
                print(f"[MAP:{self.map_name}] Tentando criar orc {enemy_id} na posição ({x}, {y})...")
                try:
                    orc = OrcEnemy(enemy_id, (x, y), self.map_name)
                    self.enemies[enemy_id] = orc
                    print(f"[MAP:{self.map_name}] Orc {enemy_id} criado com sucesso!")
                    print(f"[MAP:{self.map_name}] Dados do orc: {orc.get_sync_data()}")
                except Exception as e:
                    print(f"[ERROR][MAP:{self.map_name}] Erro ao criar orc {enemy_id}: {e}")
                    import traceback
                    traceback.print_exc()
                    
            print(f" [MAP:{self.map_name}] Total de inimigos criados: {len(self.enemies)}")
        else:
            print(f" [MAP:{self.map_name}] Mapa sem inimigos configurados")

    def _get_map_bounds(self) -> dict:
        """Retorna limites físicos do mapa para o servidor-authoritative.
        Valores em coordenadas do mundo (compatíveis com ServerPlayer).
        """
        if self.map_name == "Cidade":
            return {
                "min_x": -512.0,
                "max_x": 512.0,
                "min_y": -200.0,   # teto
                "ground_y": 184.0  # chão
            }
        elif self.map_name == "Floresta":
            return {
                "min_x": -768.0,
                "max_x": 768.0,
                "min_y": -220.0,
                "ground_y": 184.0
            }
        # Defaults seguros
        return {"min_x": -1000.0, "max_x": 1000.0, "min_y": -300.0, "ground_y": 184.0}
    
    def add_player(self, player_id: str, player_name: str, store=None, character_id=None) -> dict:
        """
        Adiciona um player server-side ao mapa e retorna posição de spawn
        """
        print(f"[DEBUG_ADD_PLAYER] {player_name}: store={store is not None}, character_id={character_id}")
        server_player = ServerPlayer(player_id, player_name, self.spawn_positions, store, character_id)
        self.players[player_id] = server_player
        self.last_activity = time.time()
        
        print(f" [MAP:{self.map_name}] Player {player_name} ({player_id}) entrou")
        print(f" [MAP:{self.map_name}] Players ativos: {len(self.players)} | Inimigos: {len(self.enemies)}")
        
        return self.spawn_positions
    
    def remove_player(self, player_id: str) -> bool:
        """
        Remove um player do mapa. Retorna True se removeu com sucesso
        """
        if player_id in self.players:
            player_name = self.players[player_id].name
            del self.players[player_id]
            self.last_activity = time.time()
            
            print(f" [MAP:{self.map_name}] Player {player_name} ({player_id}) saiu")
            print(f" [MAP:{self.map_name}] Players restantes: {len(self.players)}")
            return True
        return False
    
    def process_player_input(self, player_id: str, input_data: dict):
        """Processa input de um player"""
        if player_id in self.players:
            self.players[player_id].process_input(input_data)
            self.last_activity = time.time()
    
    def get_players_data(self) -> List[dict]:
        """Retorna dados de todos os players do mapa para sincronização"""
        return [player.get_sync_data() for player in self.players.values()]
    
    def get_players_data_dict(self) -> Dict[str, dict]:
        """Retorna dados de todos os players em formato Dictionary para compatibilidade com cliente"""
        return {player_id: player.get_sync_data() for player_id, player in self.players.items()}
    
    def get_player_data(self, player_id: str) -> Optional[dict]:
        """Retorna dados de um player específico"""
        if player_id in self.players:
            return self.players[player_id].get_sync_data()
        return None
    
    def has_player(self, player_id: str) -> bool:
        """Verifica se o player está neste mapa"""
        return player_id in self.players
    
    def get_enemies_data(self) -> List[dict]:
        """Retorna dados de todos os inimigos vivos do mapa - otimizado"""
        alive_enemies = []
        for enemy in self.enemies.values():
            if enemy.is_alive:
                alive_enemies.append(enemy.get_sync_data())
        return alive_enemies
    
    def update_enemies(self, delta_time: float) -> List[dict]:
        """
        Atualiza todos os inimigos do mapa.
        Retorna lista de inimigos que foram modificados.
        OBS: Eventos adicionais (ex: dano em player) sero retornados via atributo
        temporrio self._last_enemy_events, consumidos pelo MapManager/GameServer.
        """
        if not self.enemies:
            return []
        
        # Converter dados dos ServerPlayers para formato esperado pelos inimigos
        enemies_players_data = {}
        for player_id, player in self.players.items():
            enemies_players_data[player_id] = {
                "x": player.position[0],
                "y": player.position[1], 
                "map": self.map_name,  # Garantir que está no mesmo mapa
                "is_alive": player.is_alive,
                "hp": player.hp
            }
        
        updated_enemies = []
        extra_events = []
        dead_enemies = []
        enemy_list = list(self.enemies.values())

        for enemy_id, enemy in self.enemies.items():
            if enemy.update(delta_time, enemies_players_data, enemy_list):
                updated_enemies.append(enemy.get_sync_data())
                
            # Verificar se morreu
            if not enemy.is_alive:
                dead_enemies.append(enemy_id)
            # Verificar impacto de ataque contra player
            pid = None
            try:
                pid = enemy.consume_pending_hit()
            except Exception:
                pid = None
            if pid and pid in self.players:
                sp = self.players.get(pid)
                # Validar alcance
                try:
                    dx = sp.position[0] - enemy.position[0]
                    dy = sp.position[1] - enemy.position[1]
                    dist = (dx*dx + dy*dy) ** 0.5
                except Exception:
                    dist = 9999.0
                if dist <= getattr(enemy, 'attack_range', 24.0):
                    # Dano bruto do inimigo (será reduzido no take_damage)
                    base = int(getattr(enemy, 'attack_damage', 10))
                    died = sp.take_damage(base)
                    # Para exibição no cliente: dano final após defesa
                    try:
                        final_damage = int(getattr(sp, 'last_damage_taken', max(0, base - sp.get_damage_reduction())))
                    except Exception:
                        final_damage = max(0, base)
                    extra_events.append({
                        "type": "player_damage",
                        "player_id": sp.player_id,
                        "enemy_id": enemy.enemy_id,
                        "damage": final_damage,
                        "hp": sp.hp,
                        "hp_max": sp.max_hp,
                    })

        # Agendar revival para inimigos mortos (não remover do dicionário)
        for enemy_id in dead_enemies:
            enemy = self.enemies[enemy_id]
            
            # Agendar revival em vez de remoção
            if self.infinite_respawn and enemy.enemy_type == "orc":
                respawn_info = {
                    "enemy_id": enemy_id,
                    "enemy_ref": enemy,  # Referência direta ao objeto
                    "respawn_time": time.time() + self.respawn_delay,
                }
                self.respawn_queue.append(respawn_info)
            else:
                # Se não for para fazer respawn infinito, remover normalmente
                del self.enemies[enemy_id]
                print(f"[DEATH] [MAP:{self.map_name}] Inimigo {enemy_id} removido permanentemente")

        # Processar fila de respawn
        self._process_respawn_queue(updated_enemies)
        # Guardar eventos para consumo pelo MapManager/GameServer
        self._last_enemy_events = extra_events
        return updated_enemies
    
    def _process_respawn_queue(self, updated_enemies: List[dict]):
        """Processa a fila de revival dos inimigos - otimizado para performance"""
        if not self.respawn_queue:
            return
            
        current_time = time.time()
        
        # Cooldown para evitar processamento excessivo (0.1s)
        if current_time - self.last_revival_check < 0.1:
            return
        self.last_revival_check = current_time
        
        # Processar em lote - mais eficiente
        ready_for_revival = [
            revival_info for revival_info in self.respawn_queue 
            if current_time >= revival_info["respawn_time"]
        ]
        
        if not ready_for_revival:
            return
        
        # Reviver todos em lote
        revived_count = 0
        for revival_info in ready_for_revival:
            try:
                enemy = revival_info["enemy_ref"]
                enemy.revive()
                updated_enemies.append(enemy.get_sync_data())
                revived_count += 1
            except Exception as e:
                print(f"[ERROR] Erro ao reviver {revival_info['enemy_id']}: {e}")
        
        # Remover da fila em lote - mais eficiente
        for revival_info in ready_for_revival:
            self.respawn_queue.remove(revival_info)
        
        # Log apenas quando necessário
        if revived_count > 0:
            print(f"[REVIVAL] {revived_count} orcs reviveram")
    
    def update_players(self, delta_time: float) -> List[dict]:
        """
        Atualiza todos os players do mapa.
        Retorna lista de players que foram modificados.
        """
        if not self.players:
            return []
        
        updated_players = []
        
        # Definir limites do mapa (server-side authoritative)
        map_bounds = self._get_map_bounds()
        ground_y = map_bounds.get("ground_y", 184.0)
        min_y = map_bounds.get("min_y", -1000.0)
        
        for player_id, player in self.players.items():
            changed = player.update(delta_time, map_bounds)

            # Garantir limites verticais mesmo se a f��sica do player n��o aplicar
            clamp_applied = False
            if player.position[1] < min_y:
                player.position[1] = min_y
                if player.velocity[1] < 0:
                    player.velocity[1] = 0.0
                player.is_on_floor = False
                clamp_applied = True
            if player.position[1] > ground_y:
                player.position[1] = ground_y
                player.velocity[1] = 0.0
                player.is_on_floor = True
                clamp_applied = True

            if changed or clamp_applied:
                updated_players.append(player.get_sync_data())
        
        return updated_players
    
    def damage_enemy(self, enemy_id: str, damage: int, attacker_id: str) -> Optional[list]:
        """Aplica dano a um inimigo. Retorna lista de eventos ou None"""
        if enemy_id not in self.enemies:
            print(f"[DAMAGE_DEBUG] [MAP:{self.map_name}] Inimigo {enemy_id} não encontrado!")
            return None

        enemy = self.enemies[enemy_id]
        print(f"[DAMAGE_DEBUG] [MAP:{self.map_name}] Aplicando {damage} dano no {enemy.enemy_type} {enemy_id}")
        died = enemy.take_damage(damage)
        print(f"[DAMAGE_DEBUG] [MAP:{self.map_name}] Resultado: died={died}")

        # Eventos a serem emitidos para os clientes
        events = []

        if died:
            state = enemy.get_sync_data()

            # Inimigo morreu mas não é removido (será revivido pelo sistema de revival)
            print(f"[DEATH] [MAP:{self.map_name}] Inimigo {enemy_id} morreu por {attacker_id} (será revivido em {self.respawn_delay}s)")

            # Evento de morte do inimigo
            events.append({"type": "enemy_death", **state, "killer_id": attacker_id})

            # Recompensa de XP ao atacante (server-authoritative)
            xp_reward = 50
            try:
                if enemy.enemy_type == "orc":
                    xp_reward = 50
            except Exception:
                xp_reward = 50

            attacker = self.players.get(attacker_id)
            if attacker:
                leveled = attacker.gain_xp(xp_reward)

                # Evento de ganho de XP
                events.append({
                    "type": "xp_gain",
                    "player_id": attacker.player_id,
                    "amount": xp_reward,
                    "xp": attacker.xp,
                    "xp_max": attacker.xp_max,
                })

                if leveled:
                    events.append({
                        "type": "level_up",
                        "player_id": attacker.player_id,
                        "new_level": attacker.level,
                        "available_points": attacker.attribute_points,
                        "xp_max": attacker.xp_max,
                    })

                # Evento de atualiza��o completa de stats do jogador
                events.append({
                    "type": "player_stats_update",
                    "player_id": attacker.player_id,
                    "player_name": attacker.name,
                    "stats": attacker.to_stats_dict(),
                })

            return events
        else:
            print(f"[DAMAGE] [MAP:{self.map_name}] Inimigo {enemy_id} recebeu {damage} dano (HP: {enemy.hp})")
            return [{"type": "enemy_update", **enemy.get_sync_data(), "attacker_id": attacker_id}]
    
    def get_enemy(self, enemy_id: str) -> Optional[MultiplayerEnemy]:
        """Retorna uma instância de inimigo"""
        return self.enemies.get(enemy_id)
    
    def is_empty(self) -> bool:
        """Verifica se o mapa está vazio (sem players)"""
        return len(self.players) == 0
    
    def should_hibernate(self, hibernate_timeout: float = 300.0) -> bool:
        """
        Verifica se o mapa deve hibernar (sem atividade por muito tempo)
        hibernate_timeout: tempo em segundos (padrão 5 minutos)
        """
        return self.is_empty() and (time.time() - self.last_activity > hibernate_timeout)
    
    def get_status(self) -> dict:
        """Retorna status do mapa para debugging"""
        return {
            "map_name": self.map_name,
            "players_count": len(self.players),
            "enemies_count": len(self.enemies),
            "active": self.active,
            "created_at": self.created_at,
            "last_activity": self.last_activity,
            "age_seconds": time.time() - self.created_at
        }


class MapManager:
    """
    Gerenciador central de todas as instâncias de mapa.
    """
    
    def __init__(self):
        print(f"[MAP_MANAGER] [MAP_MANAGER] Inicializando MapManager...")
        self.maps: Dict[str, MapInstance] = {}
        self.available_maps = ["Cidade", "Floresta"]  # Mapas disponíveis
        print(f"[MAP_MANAGER] [MAP_MANAGER] MapManager inicializado. Maps dict: {list(self.maps.keys())}")
    
    def get_or_create_map(self, map_name: str) -> MapInstance:
        """
        Retorna instância do mapa, criando se necessário
        """
        print(f"[MAP_MANAGER] get_or_create_map() chamado para: '{map_name}'")
        
        if map_name not in self.available_maps:
            print(f"[WARNING] [MAP_MANAGER] Mapa '{map_name}' não está disponível. Usando 'Cidade'.")
            map_name = "Cidade"
        
        if map_name not in self.maps:
            print(f"[MAP_MANAGER] [MAP_MANAGER] Criando nova MapInstance para '{map_name}'...")
            self.maps[map_name] = MapInstance(map_name)
            print(f"[SUCCESS] [MAP_MANAGER] MapInstance '{map_name}' criada com sucesso!")
        else:
            print(f"[REUSE] [MAP_MANAGER] MapInstance '{map_name}' já existe, retornando existente")
        
        return self.maps[map_name]
    
    def get_map(self, map_name: str) -> Optional[MapInstance]:
        """Retorna instância do mapa sem criar"""
        return self.maps.get(map_name)
    
    def move_player(self, player_id: str, from_map: str, to_map: str, player_name: str, store=None, character_id=None) -> Tuple[Optional[dict], bool]:
        """
        Move um player entre mapas.
        Retorna (spawn_position, success)
        """
        success = True
        
        # Remover do mapa origem
        if from_map in self.maps:
            self.maps[from_map].remove_player(player_id)
        
        # Adicionar ao mapa destino
        target_map = self.get_or_create_map(to_map)
        spawn_position = target_map.add_player(player_id, player_name, store, character_id)
        
        print(f"[LAUNCH] [MAP_MANAGER] Player {player_name} movido: {from_map} -> {to_map}")
        
        return spawn_position, success
    
    def get_all_maps_status(self) -> dict:
        """Retorna status de todos os mapas"""
        return {map_name: map_instance.get_status() 
                for map_name, map_instance in self.maps.items()}
    
    def cleanup_empty_maps(self):
        """Remove mapas vazios (hibernação)"""
        maps_to_remove = []
        
        for map_name, map_instance in self.maps.items():
            if map_instance.should_hibernate():
                maps_to_remove.append(map_name)
        
        for map_name in maps_to_remove:
            print(f"[HIBERNATE] [MAP_MANAGER] Hibernando mapa vazio: {map_name}")
            del self.maps[map_name]
    
    def update_all_enemies(self, delta_time: float) -> Dict[str, List[dict]]:
        """
        Atualiza inimigos em todos os mapas ativos.
        Retorna {map_name: [enemies_updates]}
        """
        all_updates = {}
        
        for map_name, map_instance in self.maps.items():
            updates = map_instance.update_enemies(delta_time)
            if updates:  # Só incluir se houver updates
                all_updates[map_name] = updates
        
        return all_updates
    
    def update_all_players(self, delta_time: float) -> Dict[str, List[dict]]:
        """
        Atualiza players em todos os mapas ativos.
        Retorna {map_name: [players_updates]}
        """
        all_updates = {}
        
        for map_name, map_instance in self.maps.items():
            updates = map_instance.update_players(delta_time)
            if updates:  # Só incluir se houver updates
                all_updates[map_name] = updates
        
        return all_updates
    
    def process_player_input(self, player_id: str, input_data: dict) -> bool:
        """
        Processa input de um player em seu mapa atual.
        Retorna True se o player foi encontrado.
        """
        for map_instance in self.maps.values():
            if map_instance.has_player(player_id):
                map_instance.process_player_input(player_id, input_data)
                return True
        return False
    
    def get_players_in_map(self, map_name: str) -> List[dict]:
        """Retorna players de um mapa específico"""
        if map_name in self.maps:
            return self.maps[map_name].get_players_data()
        return []
    
    def get_players_in_map_dict(self, map_name: str) -> Dict[str, dict]:
        """Retorna players de um mapa específico em formato Dictionary"""
        if map_name in self.maps:
            return self.maps[map_name].get_players_data_dict()
        return {}
    
    def damage_enemy(self, map_name: str, enemy_id: str, damage: int, attacker_id: str) -> Optional[dict]:
        """Aplica dano a inimigo em mapa específico"""
        if map_name in self.maps:
            return self.maps[map_name].damage_enemy(enemy_id, damage, attacker_id)
        return None
    
    def get_total_players_count(self) -> int:
        """Retorna número total de players online em todos os mapas"""
        total = 0
        for map_instance in self.maps.values():
            total += len(map_instance.players)
        return total
