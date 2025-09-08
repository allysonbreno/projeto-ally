import time
import math
import asyncio
from typing import Dict, List, Tuple, Optional

class ServerEnemy:
    def __init__(self, enemy_id: str, position: Tuple[float, float], map_name: str):
        self.enemy_id = enemy_id
        self.position = list(position)  # [x, y]
        self.velocity = [0.0, 0.0]
        self.hp = 100
        self.max_hp = 100
        self.speed = 112.0
        self.map_name = map_name
        
        # Estado
        self.is_alive = True
        self.target_player_id: Optional[str] = None
        self.animation = "idle"
        self.facing_left = False
        self.is_attacking = False
        self.attack_cooldown = 0.0
        self.attack_interval = 0.7
        self.attack_range = 32.0
        
        # Timers
        self.last_update = time.time()
        self.attack_timer = 0.0
    
    def update(self, delta_time: float, players: Dict[str, dict], other_enemies: List = None) -> bool:
        """Atualiza inimigo. Retorna True se houve mudanças significativas"""
        if not self.is_alive:
            return False
            
        # Encontrar jogador mais próximo no mesmo mapa
        closest_player = self._find_closest_player(players)
        
        # IA com separação de inimigos
        if closest_player:
            self._process_ai(closest_player, delta_time, other_enemies or [])
        else:
            self._process_idle(delta_time)
        
        # Atualizar timers
        self.attack_cooldown = max(0, self.attack_cooldown - delta_time)
        
        return True  # Sempre retorna True por enquanto (otimizar depois)
    
    def _find_closest_player(self, players: Dict[str, dict]) -> Optional[dict]:
        """Encontra o jogador mais próximo no mesmo mapa"""
        closest_player = None
        closest_distance = float('inf')
        
        for player_id, player_info in players.items():
            if player_info.get("current_map") != self.map_name:
                continue
                
            player_pos = player_info.get("position", {"x": 0, "y": 0})
            distance = self._distance_to([player_pos["x"], player_pos["y"]])
            
            if distance < closest_distance:
                closest_distance = distance
                closest_player = player_info
                self.target_player_id = player_id
        
        return closest_player
    
    def _process_ai(self, target_player: dict, delta_time: float, other_enemies: List):
        """Processa IA quando tem um jogador como alvo"""
        target_pos = target_player.get("position", {"x": 0, "y": 0})
        target_position = [target_pos["x"], target_pos["y"]]
        
        # Calcular direção para o jogador
        direction = [
            target_position[0] - self.position[0],
            target_position[1] - self.position[1]
        ]
        distance = math.sqrt(direction[0]**2 + direction[1]**2)
        
        # Verificar se está em alcance de ataque
        if distance <= self.attack_range and not self.is_attacking and self.attack_cooldown <= 0:
            self._start_attack()
            return
        
        # Movimento em direção ao jogador COM SEPARAÇÃO
        if distance > self.attack_range and not self.is_attacking:
            if distance > 0:
                # Normalizar direção inicial
                direction[0] /= distance
                direction[1] /= distance
                
                # 🆕 APLICAR SEPARAÇÃO DE INIMIGOS
                separation_force = self._calculate_separation(other_enemies)
                direction[0] += separation_force[0] * 4.0  # Força da separação (aumentado)
                direction[1] += separation_force[1] * 4.0
                
                # Re-normalizar se necessário
                force_magnitude = math.sqrt(direction[0]**2 + direction[1]**2)
                if force_magnitude > 0:
                    direction[0] /= force_magnitude
                    direction[1] /= force_magnitude
                
                # Aplicar velocidade
                self.velocity[0] = direction[0] * self.speed
                self.facing_left = direction[0] < 0
                
                # Atualizar posição
                self.position[0] += self.velocity[0] * delta_time
                
                self.animation = "walk"
            else:
                self.velocity[0] = 0
                self.animation = "idle"
        else:
            self.velocity[0] = 0
            if not self.is_attacking:
                self.animation = "idle"
    
    def _process_idle(self, delta_time: float):
        """Processa quando não há jogadores próximos"""
        self.velocity[0] = 0
        self.animation = "idle"
        self.target_player_id = None
    
    def _start_attack(self):
        """Inicia ataque"""
        if self.is_attacking or self.attack_cooldown > 0:
            return
            
        self.is_attacking = True
        self.animation = "attack"
        self.attack_cooldown = self.attack_interval
        
        # Agendar fim do ataque
        asyncio.create_task(self._finish_attack())
    
    async def _finish_attack(self):
        """Finaliza o ataque após animação"""
        await asyncio.sleep(0.5)  # Duração da animação de ataque
        self.is_attacking = False
        if self.animation == "attack":
            self.animation = "idle"
    
    def take_damage(self, damage: int, attacker_id: str) -> bool:
        """Aplica dano. Retorna True se morreu"""
        if not self.is_alive:
            return False
            
        self.hp = max(0, self.hp - damage)
        
        if self.hp <= 0:
            self.is_alive = False
            return True
        
        return False
    
    def _calculate_separation(self, other_enemies: List) -> List[float]:
        """Calcula força de separação de outros inimigos"""
        separation_force = [0.0, 0.0]
        separation_radius = 60.0  # Distância mínima entre inimigos (aumentado)
        
        for other_enemy in other_enemies:
            if other_enemy.enemy_id == self.enemy_id or not other_enemy.is_alive:
                continue
                
            # Calcular distância
            dx = self.position[0] - other_enemy.position[0]
            dy = self.position[1] - other_enemy.position[1]
            distance = math.sqrt(dx*dx + dy*dy)
            
            # Se muito próximo, aplicar força de separação
            if distance < separation_radius and distance > 0:
                # Força inversamente proporcional à distância
                force_magnitude = (separation_radius - distance) / separation_radius
                
                # Direção de afastamento (normalizada)
                separation_force[0] += (dx / distance) * force_magnitude
                separation_force[1] += (dy / distance) * force_magnitude
        
        return separation_force
    
    def _distance_to(self, other_pos: List[float]) -> float:
        """Calcula distância para uma posição"""
        dx = self.position[0] - other_pos[0]
        dy = self.position[1] - other_pos[1]
        return math.sqrt(dx*dx + dy*dy)
    
    def get_state(self) -> dict:
        """Retorna estado atual do inimigo para sincronização"""
        return {
            "enemy_id": self.enemy_id,
            "position": {"x": self.position[0], "y": self.position[1]},
            "velocity": {"x": self.velocity[0], "y": self.velocity[1]},
            "hp": self.hp,
            "max_hp": self.max_hp,
            "animation": self.animation,
            "facing_left": self.facing_left,
            "is_alive": self.is_alive,
            "target_player_id": self.target_player_id
        }


class EnemyManager:
    def __init__(self):
        self.enemies: Dict[str, ServerEnemy] = {}
        self.last_update = time.time()
        self.update_rate = 1/60  # 60 FPS no servidor
        
    def create_enemy(self, enemy_id: str, position: Tuple[float, float], map_name: str):
        """Cria um novo inimigo no servidor"""
        if enemy_id not in self.enemies:
            self.enemies[enemy_id] = ServerEnemy(enemy_id, position, map_name)
            print(f"🐺 [SERVER] Inimigo criado: {enemy_id} em {map_name}")
    
    def update_enemies(self, players: Dict[str, dict]) -> List[dict]:
        """Atualiza todos os inimigos e retorna estados modificados"""
        current_time = time.time()
        delta_time = current_time - self.last_update
        self.last_update = current_time
        
        updated_enemies = []
        dead_enemies = []
        
        # 🆕 Passar lista de outros inimigos para separação
        enemy_list = list(self.enemies.values())
        
        for enemy_id, enemy in self.enemies.items():
            if enemy.update(delta_time, players, enemy_list):
                updated_enemies.append(enemy.get_state())
                
        # Remover inimigos mortos
        for enemy_id in dead_enemies:
            del self.enemies[enemy_id]
            
        return updated_enemies
    
    def damage_enemy(self, enemy_id: str, damage: int, attacker_id: str) -> Optional[dict]:
        """Aplica dano a um inimigo. Retorna estado atualizado ou None se morreu"""
        if enemy_id in self.enemies:
            enemy = self.enemies[enemy_id]
            died = enemy.take_damage(damage, attacker_id)
            
            if died:
                state = enemy.get_state()
                del self.enemies[enemy_id]
                print(f"💀 [SERVER] Inimigo morto: {enemy_id} por {attacker_id}")
                return {"type": "enemy_death", **state, "killer_id": attacker_id}
            else:
                print(f"⚔️ [SERVER] Inimigo {enemy_id} recebeu {damage} dano (HP: {enemy.hp})")
                return {"type": "enemy_update", **enemy.get_state(), "attacker_id": attacker_id}
        
        return None
    
    def get_enemies_in_map(self, map_name: str) -> List[dict]:
        """Retorna todos os inimigos de um mapa específico"""
        return [
            enemy.get_state() 
            for enemy in self.enemies.values() 
            if enemy.map_name == map_name and enemy.is_alive
        ]
    
    def initialize_forest_enemies(self):
        """Inicializa inimigos da floresta"""
        # Posições corretas da floresta: Y=184 (acima do chão em Y=204)
        spawn_positions = [(-200, 184), (-100, 184), (0, 184), (100, 184), (200, 184)]
        
        for i, (x, y) in enumerate(spawn_positions):
            enemy_id = f"enemy_forest_{int(x)}_{int(y)}"
            self.create_enemy(enemy_id, (x, y), "Floresta")