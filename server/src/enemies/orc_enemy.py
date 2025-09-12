import sys
import os
sys.path.append(os.path.dirname(__file__))

from multiplayer_enemy import MultiplayerEnemy
from typing import Tuple

class OrcEnemy(MultiplayerEnemy):
    def __init__(self, enemy_id: str, position: Tuple[float, float], map_name: str):
        super().__init__(enemy_id, position, map_name)
        
        # Configurações específicas do Orc
        self.enemy_type = "orc"
        self.hp = 50
        self.max_hp = 50
        self.speed = 112.0
        self.attack_damage = 10
        self.attack_range = 24.0  # contato mais realista
        self.attack_interval = 0.7
        
        print(f"[ORC] Orc enemy criado: {self.enemy_id} na posição {position}")
        print(f"[ORC] DEBUG - posição armazenada: {self.position}")
        
        # Adicionar log do sync data para debug
        sync_data = self.get_sync_data()
        print(f"[ORC] DEBUG - sync_data inicial: x={sync_data.get('x')}, y={sync_data.get('y')}")
    
    def _on_death(self) -> None:
        """Orc tem comportamento específico na morte"""
        print(f"[ORC] Orc {self.enemy_id} foi derrotado! Dropou Espada de Ferro.")
        
        # Aqui você pode adicionar lógica específica:
        # - Enviar evento de drop de item específico
        # - Tocar som específico de morte do orc
        # - Efeitos visuais específicos
    
    def _process_ai(self, target_player: dict, delta_time: float, other_enemies: list) -> None:
        """IA específica do Orc - mais agressiva"""
        # Chamar IA base
        super()._process_ai(target_player, delta_time, other_enemies)
        
        # Orcs podem ter comportamento mais agressivo:
        # - Menor tempo de cooldown de ataque quando próximo
        # - Movimento mais direto (menos afetado por separação)
        
        # Exemplo: Reduzir cooldown se muito próximo do jogador
        if target_player:
            import math
            distance = math.sqrt(
                (target_player['x'] - self.position[0])**2 + 
                (target_player['y'] - self.position[1])**2
            )
            
            if distance < 50.0:  # Muito próximo
                self.attack_cooldown *= 0.8  # 20% mais rápido
