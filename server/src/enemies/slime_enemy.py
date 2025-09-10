from .multiplayer_enemy import MultiplayerEnemy
from typing import Tuple
import random

class SlimeEnemy(MultiplayerEnemy):
    def __init__(self, enemy_id: str, position: Tuple[float, float], map_name: str):
        super().__init__(enemy_id, position, map_name)
        
        # Configurações específicas do Slime
        self.enemy_type = "slime"
        self.hp = 75
        self.max_hp = 75
        self.speed = 90.0  # Mais lento que Orc
        self.attack_damage = 8  # Dano menor
        self.attack_range = 28.0  # Alcance menor
        self.attack_interval = 1.0  # Ataque mais lento
        
        # Propriedades específicas do Slime
        self.jump_timer = 0.0
        self.jump_interval = 2.0
        self.can_jump = True
        
        print(f"[SLIME] Slime enemy criado: {self.enemy_id} na posição {position}")
    
    def _on_death(self) -> None:
        """Slime tem comportamento específico na morte"""
        drop_chance = random.random()
        if drop_chance < 0.8:  # 80% chance
            print(f"[SLIME] Slime {self.enemy_id} foi derrotado! Dropou Poção de Vida.")
        else:
            print(f"[SLIME] Slime {self.enemy_id} foi derrotado! Não dropou nada.")
        
        # Aqui você pode adicionar lógica específica:
        # - Enviar evento de drop de poção
        # - Efeito visual de "dissolução" do slime
        # - Som específico de morte gelatinosa
    
    def update(self, delta_time: float, players: dict, other_enemies: list = None) -> bool:
        """Override para adicionar lógica de salto específica do Slime"""
        # Atualizar timer de salto
        self.jump_timer -= delta_time
        
        # Chamar update base
        result = super().update(delta_time, players, other_enemies)
        
        return result
    
    def _process_ai(self, target_player: dict, delta_time: float, other_enemies: list) -> None:
        """IA específica do Slime - movimento em saltos"""
        # Chamar IA base
        super()._process_ai(target_player, delta_time, other_enemies)
        
        # Lógica específica do Slime: movimento em "saltos"
        if target_player and self.jump_timer <= 0.0 and self.can_jump:
            import math
            distance = math.sqrt(
                (target_player['x'] - self.position[0])**2 + 
                (target_player['y'] - self.position[1])**2
            )
            
            # Slime "salta" quando está numa distância ideal
            if 40.0 < distance < 120.0:
                self._perform_jump()
                self.jump_timer = self.jump_interval
    
    def _perform_jump(self) -> None:
        """Executa um 'salto' do slime (aumenta velocidade temporariamente)"""
        # Slime ganha velocidade extra por um momento
        self.velocity[0] *= 1.5  # 50% mais rápido temporariamente
        print(f"[SLIME] Slime {self.enemy_id} fez um salto!")
        
        # Efeito visual pode ser enviado para clientes aqui
    
    def take_damage(self, amount: int) -> bool:
        """Slimes recebem dano de forma diferente (podem "absorver" parte)"""
        # Slimes absorvem 10% do dano (são gelatinosos)
        reduced_damage = max(1, int(amount * 0.9))  # Mínimo 1 de dano
        
        result = super().take_damage(reduced_damage)
        
        if not result and self.hp > 0:
            print(f"[SLIME] Slime {self.enemy_id} absorveu parte do dano! ({amount} -> {reduced_damage})")
        
        return result