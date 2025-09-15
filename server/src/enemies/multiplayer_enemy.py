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
        # Controle de impacto do ataque
        self.attack_hit_timer = 0.0
        self.has_dealt_damage = False
        self._pending_hit_player_id: Optional[str] = None
        
        # Configurações específicas por tipo (sobrescrever nas classes filhas)
        self.enemy_type = "unknown"
    
    def update(self, delta_time: float, players: Dict[str, dict], other_enemies: List = None) -> bool:
        """Atualiza inimigo. Retorna True se houve mudanças significativas"""
        if not self.is_alive:
            return False
        
        # Selecionar alvo antes do processamento de ataque
        closest_player = self._find_closest_player(players)
        
        prev_animation = self.animation
        prev_velocity_x = self.velocity[0]
        prev_is_attacking = self.is_attacking
        
        # IA de movimento e possível início de ataque
        if closest_player:
            self._process_ai(closest_player, delta_time, other_enemies or [])
        else:
            self._process_idle(delta_time)
        
        # Atualizar ataque (inclui janela de impacto)
        self.update_attack(delta_time)
        # Timer de cooldown
        self.attack_cooldown = max(0, self.attack_cooldown - delta_time)
        
        # Mudanças relevantes?
        has_changes = (
            self.animation != prev_animation or
            abs(self.velocity[0] - prev_velocity_x) > 1.0 or
            self.is_attacking != prev_is_attacking or
            closest_player is not None
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
                dx = player['x'] - self.position[0]
                dy = player['y'] - self.position[1]
                distance = math.sqrt(dx*dx + dy*dy)
                if distance < closest_distance:
                    closest_distance = distance
                    closest_player = player
                    self.target_player_id = player_id
        if players_in_map == 0 and closest_player is None:
            print(f"[DEBUG] {self.enemy_type} {self.enemy_id}: Nenhum jogador encontrado no mapa {self.map_name}")
        return closest_player

    def _process_ai(self, target_player: dict, delta_time: float, other_enemies: List) -> None:
        """Processa IA do inimigo"""
        if not target_player:
            self.animation = "idle"
            self.velocity[0] = 0
            self.velocity[1] = 0
            self.is_attacking = False
            return

        # Direção até o jogador
        direction = [target_player['x'] - self.position[0], target_player['y'] - self.position[1]]
        distance = math.sqrt(direction[0]**2 + direction[1]**2)

        activation_distance = 200.0
        if distance > activation_distance:
            self.animation = "idle"
            self.velocity[0] = 0
            self.velocity[1] = 0
            self.is_attacking = False
            return

        if distance > 0:
            direction[0] /= distance
            direction[1] /= distance

        # Separação entre inimigos
        separation_radius = 60.0
        separation_force = [0.0, 0.0]
        for other in other_enemies or []:
            if other.enemy_id == self.enemy_id:
                continue
            odx = other.position[0] - self.position[0]
            ody = other.position[1] - self.position[1]
            other_distance = math.sqrt(odx*odx + ody*ody)
            if other_distance < separation_radius and other_distance > 0:
                sep_direction = [self.position[0] - other.position[0], self.position[1] - other.position[1]]
                sep_strength = (separation_radius - other_distance) / separation_radius
                separation_force[0] += (sep_direction[0] / other_distance) * sep_strength
                separation_force[1] += (sep_direction[1] / other_distance) * sep_strength

        direction[0] += separation_force[0] * 4.0
        direction[1] += separation_force[1] * 4.0
        new_distance = math.sqrt(direction[0]**2 + direction[1]**2)
        if new_distance > 0:
            direction[0] /= new_distance
            direction[1] /= new_distance

        if distance <= self.attack_range and self.attack_cooldown <= 0:
            self._start_attack()
        else:
            if not self.is_attacking:
                self.velocity[0] = direction[0] * self.speed
                self.velocity[1] = 0
                self.facing_left = direction[0] < 0
                self.animation = "walk" if abs(self.velocity[0]) > 1 else "idle"
            self.position[0] += self.velocity[0] * delta_time

    def _process_idle(self, delta_time: float) -> None:
        self.velocity[0] = 0
        self.animation = "idle"

    def _start_attack(self) -> None:
        if self.is_attacking:
            return
        self.is_attacking = True
        self.animation = "attack"
        self.velocity[0] = 0
        self.attack_cooldown = self.attack_interval
        # Duração e momento do impacto
        self.attack_timer = 0.5
        self.attack_hit_timer = 0.25
        self.has_dealt_damage = False
        self._pending_hit_player_id = None

    def update_attack(self, delta_time: float) -> None:
        if not self.is_attacking:
            return
        self.attack_timer -= delta_time
        if not self.has_dealt_damage:
            self.attack_hit_timer -= delta_time
            if self.attack_hit_timer <= 0:
                self._pending_hit_player_id = self.target_player_id
                self.has_dealt_damage = True
        if self.attack_timer <= 0:
            self.is_attacking = False
            self.animation = "idle"

    def take_damage(self, amount: int) -> bool:
        old_hp = self.hp
        self.hp = max(0, self.hp - amount)
        print(f"[DAMAGE_DEBUG] {self.enemy_type} {self.enemy_id}: HP {old_hp} -> {self.hp} (dano: {amount})")
        if self.hp <= 0:
            self.is_alive = False
            print(f"[DAMAGE_DEBUG] {self.enemy_type} {self.enemy_id}: MORREU! Chamando _on_death()")
            self._on_death()
            return True
        return False

    def _on_death(self) -> None:
        print(f"[ENEMY] {self.enemy_type} {self.enemy_id} morreu!")
    
    def revive(self) -> None:
        """Revive o inimigo sem recriar o objeto - otimizado para performance"""
        self.is_alive = True
        self.hp = self.max_hp
        self.animation = "idle"
        self.is_attacking = False
        self.attack_cooldown = 0.0
        self.attack_timer = 0.0
        self.attack_hit_timer = 0.0
        self.has_dealt_damage = False
        self._pending_hit_player_id = None
        self.target_player_id = None
        self.velocity[0] = 0.0  # Mais eficiente que criar nova lista
        self.velocity[1] = 0.0
        self.facing_left = False

    def consume_pending_hit(self) -> Optional[str]:
        pid = self._pending_hit_player_id
        self._pending_hit_player_id = None
        return pid

    def get_sync_data(self) -> dict:
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
            'is_alive': self.is_alive,
        }

    def get_state(self) -> dict:
        sync = self.get_sync_data()
        return {
            "enemy_id": sync['enemy_id'],
            "position": {"x": sync['x'], "y": sync['y']},
            "velocity": {"x": sync['velocity_x'], "y": sync['velocity_y']},
            "hp": sync['hp'],
            "max_hp": sync['max_hp'],
            "animation": sync['animation'],
            "facing_left": sync['facing_left'],
            "is_alive": sync['is_alive'],
            "target_player_id": self.target_player_id,
        }
