import time
import math
from typing import Dict, List, Tuple, Optional

class MultiplayerEnemy:
    def __init__(self, enemy_id: str, position: Tuple[float, float], map_name: str):
        self.enemy_id = enemy_id
        self.position = list(position)  # [x, y]
        self.velocity = [0.0, 0.0]
        self.map_name = map_name
        
        # Propriedades base - serão sobrescritas pelas classes filhas
        self.hp = 100
        self.max_hp = 100
        self.speed = 100.0
        self.attack_damage = 10
        self.attack_range = 32.0
        self.attack_interval = 0.7
        
        # Estado
        self.is_alive = True
        self.target_player_id: Optional[str] = None
        self.animation = "idle"
        self.facing_left = False
        self.is_attacking = False
        self.attack_cooldown = 0.0
        
        # Timers
        self.last_update = time.time()
        self.attack_timer = 0.0
        
        # Configurações específicas por tipo (sobrescrever nas classes filhas)
        self.enemy_type = "unknown"
    
    def update(self, delta_time: float, players: Dict[str, dict], other_enemies: List = None) -> bool:
        """Atualiza inimigo. Retorna True se houve mudanças significativas"""
        if not self.is_alive:
            return False
            
        # Atualizar estado de ataque primeiro
        was_attacking = self.is_attacking
        self.update_attack(delta_time)
            
        # Encontrar jogador mais próximo no mesmo mapa
        closest_player = self._find_closest_player(players)
        
        # Salvar estado anterior para detecção de mudanças
        prev_animation = self.animation
        prev_velocity_x = self.velocity[0]
        prev_is_attacking = was_attacking
        
        # IA com separação de inimigos
        if closest_player:
            self._process_ai(closest_player, delta_time, other_enemies or [])
        else:
            self._process_idle(delta_time)
        
        # Atualizar timers
        self.attack_cooldown = max(0, self.attack_cooldown - delta_time)
        
        # Retornar True apenas se houve mudanças significativas
        has_changes = (
            self.animation != prev_animation or
            abs(self.velocity[0] - prev_velocity_x) > 1.0 or
            self.is_attacking != prev_is_attacking or
            closest_player is not None  # Sempre sincronizar quando há jogador próximo
        )
        
        return has_changes
    
    def _find_closest_player(self, players: Dict[str, dict]) -> Optional[dict]:
        """Encontra o jogador mais próximo no mesmo mapa"""
        closest_player = None
        closest_distance = float('inf')
        
        if not players:
            return None
        
        players_in_map = 0
        for player_id, player in players.items():
            if player.get('map') == self.map_name and player.get('is_alive', True):
                players_in_map += 1
                distance = math.sqrt(
                    (player['x'] - self.position[0])**2 + 
                    (player['y'] - self.position[1])**2
                )
                if distance < closest_distance:
                    closest_distance = distance
                    closest_player = player
                    self.target_player_id = player_id
        
        # Debug log apenas quando não há jogadores no mapa
        if players_in_map == 0 and closest_player is None:
            print(f"[DEBUG] {self.enemy_type} {self.enemy_id}: Nenhum jogador encontrado no mapa {self.map_name}")
        
        return closest_player
    
    def _process_ai(self, target_player: dict, delta_time: float, other_enemies: List) -> None:
        """Processa IA do inimigo"""
        if not target_player:
            # Sem jogadores no mapa - ficar completamente parado
            self.animation = "idle"
            self.velocity[0] = 0
            self.velocity[1] = 0
            self.is_attacking = False
            return
        
        # Calcular direção para o jogador
        direction = [
            target_player['x'] - self.position[0],
            target_player['y'] - self.position[1]
        ]
        distance = math.sqrt(direction[0]**2 + direction[1]**2)
        
        # Se jogador está muito longe (fora da zona de ativação), ficar idle
        activation_distance = 200.0  # Distância máxima para ativar IA
        if distance > activation_distance:
            self.animation = "idle"
            self.velocity[0] = 0
            self.velocity[1] = 0
            self.is_attacking = False
            return
        
        # Normalizar direção
        if distance > 0:
            direction[0] /= distance
            direction[1] /= distance
        
        # Sistema de separação entre inimigos (melhorado)
        separation_radius = 60.0  # Aumentado de 40.0
        separation_force = [0.0, 0.0]
        
        for other in other_enemies:
            if other.enemy_id == self.enemy_id:
                continue
                
            other_distance = math.sqrt(
                (other.position[0] - self.position[0])**2 + 
                (other.position[1] - self.position[1])**2
            )
            
            if other_distance < separation_radius and other_distance > 0:
                # Força de separação
                sep_direction = [
                    self.position[0] - other.position[0],
                    self.position[1] - other.position[1]
                ]
                sep_strength = (separation_radius - other_distance) / separation_radius
                separation_force[0] += (sep_direction[0] / other_distance) * sep_strength
                separation_force[1] += (sep_direction[1] / other_distance) * sep_strength
        
        # Aplicar separação mais forte
        direction[0] += separation_force[0] * 4.0  # Aumentado de 2.0
        direction[1] += separation_force[1] * 4.0
        
        # Renormalizar após separação
        new_distance = math.sqrt(direction[0]**2 + direction[1]**2)
        if new_distance > 0:
            direction[0] /= new_distance
            direction[1] /= new_distance
        
        # Verificar se pode atacar
        if distance <= self.attack_range and self.attack_cooldown <= 0:
            self._start_attack()
        else:
            # Mover em direção ao jogador (se não está atacando)
            if not self.is_attacking:
                self.velocity[0] = direction[0] * self.speed
                self.velocity[1] = 0  # Apenas movimento horizontal
                
                # Atualizar direção
                self.facing_left = direction[0] < 0
                self.animation = "walk" if abs(self.velocity[0]) > 1 else "idle"
            
            # Atualizar posição
            self.position[0] += self.velocity[0] * delta_time
            # position[1] é controlada pela gravidade no cliente
    
    def _process_idle(self, delta_time: float) -> None:
        """Processa estado idle"""
        self.velocity[0] = 0
        self.animation = "idle"
    
    def _start_attack(self) -> None:
        """Inicia ataque"""
        if self.is_attacking:
            return
            
        self.is_attacking = True
        self.animation = "attack"
        self.velocity[0] = 0  # Parar movimento durante ataque
        self.attack_cooldown = self.attack_interval
        
        # Timer para terminar o ataque (aproximadamente a duração da animação)
        self.attack_timer = 0.5  # 500ms de ataque
    
    def update_attack(self, delta_time: float) -> None:
        """Atualiza estado de ataque"""
        if not self.is_attacking:
            return
            
        self.attack_timer -= delta_time
        if self.attack_timer <= 0:
            self.is_attacking = False
            self.animation = "idle"
    
    def take_damage(self, amount: int) -> bool:
        """Aplica dano. Retorna True se morreu"""
        self.hp = max(0, self.hp - amount)
        
        if self.hp <= 0:
            self.is_alive = False
            self._on_death()
            return True
        return False
    
    def _on_death(self) -> None:
        """Chamado quando o inimigo morre - pode ser sobrescrito"""
        print(f"[ENEMY] {self.enemy_type} {self.enemy_id} morreu!")
    
    def get_sync_data(self) -> dict:
        """Retorna dados para sincronização com clientes"""
        return {
            'enemy_id': self.enemy_id,
            'enemy_type': self.enemy_type,
            'x': self.position[0],
            'y': self.position[1],
            'velocity_x': self.velocity[0],
            'velocity_y': self.velocity[1],
            'animation': self.animation,
            'facing_left': self.facing_left,
            'hp': self.hp,
            'max_hp': self.max_hp,
            'is_attacking': self.is_attacking,
            'is_alive': self.is_alive
        }
    
    def get_state(self) -> dict:
        """Compatibilidade com sistema antigo - usa get_sync_data()"""
        sync_data = self.get_sync_data()
        # Converter para formato antigo
        return {
            "enemy_id": sync_data['enemy_id'],
            "position": {"x": sync_data['x'], "y": sync_data['y']},
            "velocity": {"x": sync_data['velocity_x'], "y": sync_data['velocity_y']},
            "hp": sync_data['hp'],
            "max_hp": sync_data['max_hp'],
            "animation": sync_data['animation'],
            "facing_left": sync_data['facing_left'],
            "is_alive": sync_data['is_alive'],
            "target_player_id": self.target_player_id
        }