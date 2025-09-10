"""
Sistema de inimigos modular para servidor multiplayer
"""

from .multiplayer_enemy import MultiplayerEnemy
from .orc_enemy import OrcEnemy
from .slime_enemy import SlimeEnemy

__all__ = ['MultiplayerEnemy', 'OrcEnemy', 'SlimeEnemy']