import time
from typing import Optional


class ServerPlayer:
    """
    Representa um player completamente server-side.
    Processa input, física e lógica no servidor (server-authoritative).
    """

    def __init__(self, player_id: str, player_name: str, spawn_pos: dict):
        self.player_id = player_id
        self.name = player_name
        # Posição interna (mantém compatibilidade com código existente)
        self.posicaon = [float(spawn_pos.get("x", 0.0)), float(spawn_pos.get("y", 0.0))]
        self.velocity = [0.0, 0.0]

        # Buffer de input
        self.input_buffer = {
            "move_left": False,
            "move_right": False,
            "jump": False,
            "attack": False,
        }

        # Stats
        self.level = 1
        self.xp = 0
        self.xp_max = 100
        self.attribute_points = 0

        # Atributos
        self.strength = 5
        self.defense_attr = 5
        self.intelligence = 5
        self.vitality = 5

        self.max_hp = self.vitality * 20
        self.hp = self.max_hp
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
        self.jump_buffer = 0.0
        self.attack_buffer = 0.0

        # Metadados
        self.created_at = time.time()
        self.last_input_time = time.time()
        
        print(f"[PLAYER] Player server-side criado: {self.player_id} ({self.name}) na posição {self.posicaon}")
        # Último dano recebido (para telemetria/eventos)
        self.last_damage_taken = 0

    # ======= COMPAT: alias position =======
    @property
    def position(self):
        return self.posicaon

    @position.setter
    def position(self, value):
        try:
            if isinstance(value, (list, tuple)) and len(value) >= 2:
                self.posicaon[0] = float(value[0])
                self.posicaon[1] = float(value[1])
            elif isinstance(value, dict) and "x" in value and "y" in value:
                self.posicaon[0] = float(value.get("x", self.posicaon[0]))
                self.posicaon[1] = float(value.get("y", self.posicaon[1]))
        except Exception:
            pass

    # ======= STATS & ATRIBUTOS =======
    def get_attack_power(self) -> int:
        return 25 + int(self.strength)

    def get_damage_reduction(self) -> int:
        return int(self.defense_attr)

    def recalc_max_hp(self) -> None:
        self.max_hp = int(self.vitality) * 20
        self.hp = min(self.hp, self.max_hp)

    def gain_xp(self, amount: int) -> bool:
        leveled = False
        self.xp += int(amount)
        while self.xp >= self.xp_max:
            self.xp -= self.xp_max
            self.level += 1
            # Aumenta XP necessário ~20% por nível
            try:
                self.xp_max = int(max(1, self.xp_max * 1.2))
            except Exception:
                self.xp_max = self.xp_max + 20
            self.attribute_points += 5
            leveled = True
        return leveled

    def add_attribute_point(self, attr: str) -> bool:
        if self.attribute_points <= 0:
            return False
        if attr == "strength":
            self.strength += 1
        elif attr == "defense":
            self.defense_attr += 1
        elif attr == "intelligence":
            self.intelligence += 1
        elif attr == "vitality":
            self.vitality += 1
            self.recalc_max_hp()
        else:
            return False
        self.attribute_points -= 1
        return True

    def to_stats_dict(self) -> dict:
        return {
            "level": self.level,
            "xp": self.xp,
            "xp_max": self.xp_max,
            "attr_points": self.attribute_points,
            "hp": self.hp,
            "hp_max": self.max_hp,
            "attributes": {
                "strength": self.strength,
                "defense": self.defense_attr,
                "intelligence": self.intelligence,
                "vitality": self.vitality,
            },
        }

    # ======= INPUT =======
    def process_input(self, input_data: dict) -> bool:
        if not input_data:
            return False
        changed = False
        for key in ["move_left", "move_right", "jump", "attack"]:
            if key in input_data:
                old = self.input_buffer[key]
                self.input_buffer[key] = bool(input_data[key])
                if old != self.input_buffer[key]:
                    changed = True
        # Buffers (tolerância a latência)
        if input_data.get("jump", False):
            self.jump_buffer = max(self.jump_buffer, 0.12)
        if input_data.get("attack", False):
            self.attack_buffer = max(self.attack_buffer, 0.15)
        self.last_input_time = time.time()
        return changed

    # ======= UPDATE =======
    def update(self, delta_time: float, map_bounds: Optional[dict] = None) -> bool:
        if not self.is_alive:
            return False

        old_pos = self.posicaon.copy()
        old_vel = self.velocity.copy()
        old_anim = self.animation
        old_facing = self.facing_left

        # Movimento horizontal
        h = 0.0
        if self.input_buffer["move_left"]:
            h -= 1.0
        if self.input_buffer["move_right"]:
            h += 1.0
        self.velocity[0] = h * self.speed
        if abs(self.velocity[0]) > 1.0:
            self.facing_left = self.velocity[0] < 0

        # Buffers e pulo bufferizado
        if self.jump_buffer > 0.0:
            self.jump_buffer = max(0.0, self.jump_buffer - delta_time)
        if self.attack_buffer > 0.0:
            self.attack_buffer = max(0.0, self.attack_buffer - delta_time)
        if self.jump_buffer > 0.0 and self.is_on_floor:
            self.velocity[1] = self.jump_force
            self.is_on_floor = False
            self.jump_buffer = 0.0

        # Pulo
        if self.input_buffer["jump"] and self.is_on_floor:
            self.velocity[1] = self.jump_force
            self.is_on_floor = False

        # Gravidade
        if not self.is_on_floor:
            self.velocity[1] += self.gravity * delta_time

        # Integrar
        self.posicaon[0] += self.velocity[0] * delta_time
        self.posicaon[1] += self.velocity[1] * delta_time

        # Chão
        ground_y = 184.0
        if self.posicaon[1] >= ground_y:
            self.posicaon[1] = ground_y
            self.velocity[1] = 0.0
            self.is_on_floor = True

        # Limites do mapa
        if map_bounds:
            if self.posicaon[0] < map_bounds.get("min_x", -1000.0):
                self.posicaon[0] = map_bounds.get("min_x", -1000.0)
            if self.posicaon[0] > map_bounds.get("max_x", 1000.0):
                self.posicaon[0] = map_bounds.get("max_x", 1000.0)

        # Processar ataque ANTES de escolher animação
        self._process_attack(delta_time)

        # Determinar animação
        new_animation = self._determine_animation()
        if new_animation != self.animation:
            self.animation = new_animation

        # Mudanças relevantes
        pos_changed = (abs(self.posicaon[0] - old_pos[0]) > 0.1 or abs(self.posicaon[1] - old_pos[1]) > 0.1)
        vel_changed = (abs(self.velocity[0] - old_vel[0]) > 1.0 or abs(self.velocity[1] - old_vel[1]) > 1.0)
        anim_changed = (self.animation != old_anim)
        facing_changed = (self.facing_left != old_facing)

        return pos_changed or vel_changed or anim_changed or facing_changed

    def _determine_animation(self) -> str:
        if self.is_attacking:
            return "attack"
        if not self.is_on_floor:
            return "jump"
        if abs(self.velocity[0]) > 10.0:
            return "walk"
        return "idle"

    def _process_attack(self, delta_time: float):
        if self.attack_cooldown > 0:
            self.attack_cooldown -= delta_time
        # Ataque por buffer
        if self.attack_buffer > 0.0 and self.attack_cooldown <= 0:
            self.is_attacking = True
            self.attack_cooldown = self.attack_duration
            self.attack_buffer = 0.0
        # Compat: ataque direto
        if self.input_buffer["attack"] and self.attack_cooldown <= 0:
            self.is_attacking = True
            self.attack_cooldown = self.attack_duration
        # Encerrar ataque ao fim do cooldown
        if self.is_attacking and self.attack_cooldown <= 0:
            self.is_attacking = False

    # ======= COMBATE =======
    def take_damage(self, damage: int) -> bool:
        if not self.is_alive:
            return False
        final_damage = max(0, int(damage) - self.get_damage_reduction())
        self.last_damage_taken = final_damage
        self.hp = max(0, self.hp - final_damage)
        if self.hp <= 0:
            self.is_alive = False
            self.animation = "death"
            print(f"[DEATH] Player {self.name} ({self.player_id}) morreu")
            return True
        print(f"[DAMAGE] Player {self.name} recebeu {final_damage} dano (HP: {self.hp})")
        return False

    def get_attack_hitbox(self) -> Optional[dict]:
        if not self.is_attacking:
            return None
        hitbox_width = 40
        hitbox_height = 30
        if self.facing_left:
            hitbox_x = self.posicaon[0] - hitbox_width
        else:
            hitbox_x = self.posicaon[0] + 20
        return {
            "x": hitbox_x,
            "y": self.posicaon[1] - 10,
            "width": hitbox_width,
            "height": hitbox_height,
        }

    def get_sync_data(self) -> dict:
        return {
            "id": self.player_id,
            "name": self.name,
            "position": {"x": self.posicaon[0], "y": self.posicaon[1]},
            "velocity": {"x": self.velocity[0], "y": self.velocity[1]},
            "animation": self.animation,
            "facing": -1.0 if self.facing_left else 1.0,
            "hp": self.hp,
            "max_hp": self.max_hp,
            "is_attacking": self.is_attacking,
            "is_alive": self.is_alive,
        }

    def respawn(self, spawn_pos: dict):
        self.posicaon = [float(spawn_pos.get("x", 0.0)), float(spawn_pos.get("y", 0.0))]
        self.velocity = [0.0, 0.0]
        self.hp = self.max_hp
        self.is_alive = True
        self.animation = "idle"
        self.is_attacking = False
        self.attack_cooldown = 0.0
        print(f"[RESPAWN] Player {self.name} ({self.player_id}) respawnou em {self.posicaon}")
