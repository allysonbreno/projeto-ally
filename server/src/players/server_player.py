import time
from typing import Dict, List, Optional, Tuple
import math

class ServerPlayer:
    """
    Representa um player completamente server-side.
    Processa input, física e lógica no servidor.
    """
    
    def __init__(self, player_id: str, player_name: str, spawn_position: dict):
        self.player_id = player_id
        self.name = player_name
        self.position = [float(spawn_position.get("x", 0)), float(spawn_position.get("y", 0))]
        self.velocity = [0.0, 0.0]
        
        # Controles de input do cliente
        self.input_buffer = {
            "move_left": False,
            "move_right": False,
            "jump": False,
            "attack": False
        }
        
        # Estados do player
        self.hp = 100
        self.max_hp = 100
        self.is_alive = True
        self.animation = "idle"
        self.facing_left = False
        
        # Física
        self.speed = 200.0
        self.jump_force = -400.0
        self.gravity = 980.0
        self.is_on_floor = False
        
        # Combate
        self.is_attacking = False
        self.attack_cooldown = 0.0
        self.attack_duration = 0.5
        # Buffers (tolerância a latência) para eventos instantâneos
        self.jump_buffer = 0.0
        self.attack_buffer = 0.0
        
        # Metadados
        self.created_at = time.time()
        self.last_input_time = time.time()
        
        print(f"[PLAYER] Player server-side criado: {self.player_id} ({self.name}) na posição {self.position}")
    
    def process_input(self, input_data: dict) -> bool:
        """
        Processa input recebido do cliente.
        Retorna True se houve mudanças.
        """
        if not input_data:
            return False
            
        changed = False
        
        # Atualizar buffer de input
        for key in ["move_left", "move_right", "jump", "attack"]:
            if key in input_data:
                old_value = self.input_buffer[key]
                self.input_buffer[key] = input_data[key]
                if old_value != self.input_buffer[key]:
                    changed = True
        # Alimentar buffers de evento (tolerância a latência)
        if input_data.get("jump", False):
            self.jump_buffer = max(self.jump_buffer, 0.12)
        if input_data.get("attack", False):
            self.attack_buffer = max(self.attack_buffer, 0.15)
        
        self.last_input_time = time.time()
        return changed
    
    def update(self, delta_time: float, map_bounds: Optional[dict] = None) -> bool:
        """
        Atualiza física e estado do player.
        Retorna True se houve mudanças que precisam ser sincronizadas.
        """
        if not self.is_alive:
            return False
            
        old_position = self.position.copy()
        old_velocity = self.velocity.copy()
        old_animation = self.animation
        old_facing = self.facing_left
        
        # Processar movimento horizontal
        horizontal_input = 0.0
        if self.input_buffer["move_left"]:
            horizontal_input -= 1.0
        if self.input_buffer["move_right"]:
            horizontal_input += 1.0
            
        self.velocity[0] = horizontal_input * self.speed
        # Atualizar facing baseado na velocidade real (evita "moonwalk")
        if abs(self.velocity[0]) > 1.0:
            self.facing_left = self.velocity[0] < 0
        
        # Atualizar timers de buffer e processar pulo bufferizado
        if self.jump_buffer > 0.0:
            self.jump_buffer = max(0.0, self.jump_buffer - delta_time)
        if self.attack_buffer > 0.0:
            self.attack_buffer = max(0.0, self.attack_buffer - delta_time)
        if self.jump_buffer > 0.0 and self.is_on_floor:
            self.velocity[1] = self.jump_force
            self.is_on_floor = False
            self.jump_buffer = 0.0
        
        # Pulo (apenas se estiver no chão)
        if self.input_buffer["jump"] and self.is_on_floor:
            self.velocity[1] = self.jump_force
            self.is_on_floor = False
        
        # Gravidade
        if not self.is_on_floor:
            self.velocity[1] += self.gravity * delta_time
        
        # Aplicar velocidade à posição
        self.position[0] += self.velocity[0] * delta_time
        self.position[1] += self.velocity[1] * delta_time
        
        # Simular colisão com o chão (básica)
        ground_y = 184.0  # Altura do chão padrão
        if self.position[1] >= ground_y:
            self.position[1] = ground_y
            self.velocity[1] = 0.0
            self.is_on_floor = True
        
        # Limites do mapa
        if map_bounds:
            if self.position[0] < map_bounds.get("min_x", -1000):
                self.position[0] = map_bounds.get("min_x", -1000)
            if self.position[0] > map_bounds.get("max_x", 1000):
                self.position[0] = map_bounds.get("max_x", 1000)
        
        # Determinar animação
        new_animation = self._determine_animation()
        if new_animation != self.animation:
            self.animation = new_animation
        
        # Processar ataque
        self._process_attack(delta_time)
        
        # Verificar se houve mudanças
        position_changed = (abs(self.position[0] - old_position[0]) > 0.1 or 
                           abs(self.position[1] - old_position[1]) > 0.1)
        velocity_changed = (abs(self.velocity[0] - old_velocity[0]) > 1.0 or 
                           abs(self.velocity[1] - old_velocity[1]) > 1.0)
        animation_changed = (self.animation != old_animation)
        facing_changed = (self.facing_left != old_facing)
        
        return position_changed or velocity_changed or animation_changed or facing_changed
    
    def _determine_animation(self) -> str:
        """Determina animação baseada no estado atual"""
        if self.is_attacking:
            return "attack"
        elif not self.is_on_floor:
            return "jump"
        elif abs(self.velocity[0]) > 10.0:
            return "walk"
        else:
            return "idle"
    
    def _process_attack(self, delta_time: float):
        """Processa lógica de ataque"""
        if self.attack_cooldown > 0:
            self.attack_cooldown -= delta_time
        
        # Ataque com buffer (evita perder frame de just_pressed)
        if self.attack_buffer > 0.0 and self.attack_cooldown <= 0:
            self.is_attacking = True
            self.attack_cooldown = self.attack_duration
            self.attack_buffer = 0.0
        
        # Compatibilidade com input direto
        if self.input_buffer["attack"] and self.attack_cooldown <= 0:
            self.is_attacking = True
            self.attack_cooldown = self.attack_duration
        
        if self.is_attacking and self.attack_cooldown <= 0:
            self.is_attacking = False
    
    def take_damage(self, damage: int) -> bool:
        """
        Aplica dano ao player.
        Retorna True se o player morreu.
        """
        if not self.is_alive:
            return False
            
        self.hp = max(0, self.hp - damage)
        
        if self.hp <= 0:
            self.is_alive = False
            self.animation = "death"
            print(f"[DEATH] Player {self.name} ({self.player_id}) morreu")
            return True
        
        print(f"[DAMAGE] Player {self.name} recebeu {damage} dano (HP: {self.hp})")
        return False
    
    def get_attack_hitbox(self) -> Optional[dict]:
        """
        Retorna hitbox do ataque se estiver atacando.
        """
        if not self.is_attacking:
            return None
            
        # Hitbox básico na frente do player
        hitbox_width = 40
        hitbox_height = 30
        
        if self.facing_left:
            hitbox_x = self.position[0] - hitbox_width
        else:
            hitbox_x = self.position[0] + 20
            
        return {
            "x": hitbox_x,
            "y": self.position[1] - 10,
            "width": hitbox_width,
            "height": hitbox_height
        }
    
    def get_sync_data(self) -> dict:
        """Retorna dados para sincronização com clientes"""
        return {
            "id": self.player_id,
            "name": self.name,
            "position": {"x": self.position[0], "y": self.position[1]},
            "velocity": {"x": self.velocity[0], "y": self.velocity[1]},
            "animation": self.animation,
            "facing": -1.0 if self.facing_left else 1.0,
            "hp": self.hp,
            "max_hp": self.max_hp,
            "is_attacking": self.is_attacking,
            "is_alive": self.is_alive
        }
    
    def respawn(self, spawn_position: dict):
        """Revive o player em uma posição específica"""
        self.position = [float(spawn_position.get("x", 0)), float(spawn_position.get("y", 0))]
        self.velocity = [0.0, 0.0]
        self.hp = self.max_hp
        self.is_alive = True
        self.animation = "idle"
        self.is_attacking = False
        self.attack_cooldown = 0.0
        print(f"[RESPAWN] Player {self.name} ({self.player_id}) respawnou em {self.position}")
