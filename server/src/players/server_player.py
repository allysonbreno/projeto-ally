import time
from typing import Optional


class ServerPlayer:
    """
    Representa um player completamente server-side.
    Processa input, física e lógica no servidor (server-authoritative).
    """

    def __init__(self, player_id: str, player_name: str, spawn_pos: dict, store=None, character_id=None):
        self.player_id = player_id
        self.name = player_name
        self.store = store
        self.character_id = character_id
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

        # Stats padrão (serão sobrescritos se carregar do banco)
        self.level = 1
        self.xp = 0
        self.xp_max = 100
        self.attribute_points = 0

        # Atributos padrão (serão sobrescritos se carregar do banco)
        self.strength = 5
        self.defense_attr = 5
        self.intelligence = 5
        self.vitality = 5

        self.max_hp = self.vitality * 20
        self.hp = self.max_hp
        
        # Carregar dados salvos do banco de dados se disponível
        self._load_from_database()
        self.is_alive = True
        self.animation = "idle"
        self.facing_left = False

        # Física
        self.speed = 500.0
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
        print(f"[XP_GAIN] {self.name} ganhou {amount} XP! (Atual: {self.xp} -> {self.xp + amount})")
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
        
        # Auto-save no banco de dados
        self.auto_save()
        return leveled

    def auto_save(self):
        """Salva automaticamente o estado do personagem no banco de dados"""
        print(f"[AUTO_SAVE] Tentando salvar {self.name} - store: {self.store is not None}, character_id: {self.character_id}")
        if self.store and self.character_id:
            try:
                print(f"[AUTO_SAVE] Salvando estado: Level={self.level}, XP={self.xp}, HP={self.hp}")
                # Salvar estado básico
                self.store.save_character_state(self.character_id, {
                    "level": self.level,
                    "xp": self.xp,
                    "xp_max": self.xp_max,
                    "attr_points": self.attribute_points,
                    "hp": self.hp,
                    "hp_max": self.max_hp,
                    "pos_x": self.position[0],
                    "pos_y": self.position[1]
                })
                print(f"[AUTO_SAVE] Estado salvo com sucesso!")
                
                # Salvar atributos
                self.store.save_character_attributes(self.character_id, {
                    "strength": self.strength,
                    "defense": self.defense_attr,
                    "intelligence": self.intelligence,
                    "vitality": self.vitality
                })
                print(f"[AUTO_SAVE] Atributos salvos com sucesso!")
                print(f"[AUTO_SAVE] Personagem {self.name} salvo completamente! Level: {self.level}, XP: {self.xp}")
            except Exception as e:
                import traceback
                print(f"[ERROR] Falha ao salvar personagem {self.name}: {e}")
                print(f"[ERROR] Traceback: {traceback.format_exc()}")
        else:
            print(f"[AUTO_SAVE] ERRO: Não salvou {self.name} - store: {self.store is not None}, character_id: {self.character_id}")

    def _load_from_database(self):
        """Carrega dados salvos do banco de dados se disponível"""
        if not self.store or not self.character_id:
            print(f"[LOAD] {self.name}: Usando valores padrão (sem banco ou character_id)")
            return
            
        try:
            print(f"[LOAD] Carregando dados salvos para {self.name} (character_id: {self.character_id})")
            
            # Carregar dados do personagem diretamente pelo character_id
            char = self.store.get_character_by_id(self.character_id)
            
            # Carregar atributos do personagem
            attrs_row = self.store.conn.execute(
                "SELECT * FROM character_attributes WHERE character_id=?",
                (self.character_id,),
            ).fetchone()
            attrs = dict(attrs_row) if attrs_row else None
            
            if char:
                # Carregar stats do personagem
                self.level = char.get("level", 1)
                self.xp = char.get("xp", 0) 
                self.xp_max = char.get("xp_max", 100)
                self.attribute_points = char.get("attr_points", 0)
                self.hp = char.get("hp", 100)
                self.max_hp = char.get("hp_max", 100)
                
                print(f"[LOAD] Stats carregados: Level={self.level}, XP={self.xp}, HP={self.hp}, AttrPts={self.attribute_points}")
                
            if attrs:
                # Carregar atributos do personagem  
                self.strength = attrs.get("strength", 5)
                self.defense_attr = attrs.get("defense", 5)
                self.intelligence = attrs.get("intelligence", 5)
                self.vitality = attrs.get("vitality", 5)
                
                print(f"[LOAD] Atributos carregados: STR={self.strength}, DEF={self.defense_attr}, INT={self.intelligence}, VIT={self.vitality}")
                
                # Recalcular HP máximo baseado na vitalidade carregada
                if not char:  # Se não carregou HP do char, calcular baseado na vitalidade
                    self.max_hp = self.vitality * 20
                    self.hp = self.max_hp
                else:
                    # Se carregou HP do char, garantir que HP máximo bate com vitalidade
                    calculated_max_hp = self.vitality * 20
                    if self.max_hp != calculated_max_hp:
                        print(f"[LOAD] Ajustando HP máximo: {self.max_hp} -> {calculated_max_hp} (baseado em VIT={self.vitality})")
                        self.max_hp = calculated_max_hp
                        # Não deixar HP atual maior que o máximo
                        if self.hp > self.max_hp:
                            self.hp = self.max_hp
                    
            print(f"[LOAD] {self.name} carregado com sucesso do banco de dados!")
            print(f"[LOAD] Estado final: Level={self.level}, XP={self.xp}/{self.xp_max}, HP={self.hp}/{self.max_hp}, AttrPts={self.attribute_points}")
            
        except Exception as e:
            import traceback
            print(f"[LOAD] ERRO ao carregar {self.name}: {e}")
            print(f"[LOAD] Traceback: {traceback.format_exc()}")
            print(f"[LOAD] Usando valores padrão para {self.name}")

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
        
        # Auto-save após gastar ponto de atributo
        self.auto_save()
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
