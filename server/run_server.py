#!/usr/bin/env python3
"""
🎮 PROJETO ALLY - SERVIDOR MULTIPLAYER
Servidor dedicado para o jogo Projeto Ally

Uso:
    python run_server.py

Requisitos:
    pip install websockets asyncio-mqtt

Interface:
    - Ligar/Desligar Servidor
    - Reiniciar Servidor  
    - Monitor de jogadores online
    - Logs em tempo real
"""

import sys
import os

# Adicionar pasta src ao path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

try:
    from server_gui import ServerGUI
    
    def main():
        print("Iniciando Projeto Ally - Servidor Multiplayer")
        print("Carregando interface...")
        
        app = ServerGUI()
        app.run()
        
        print("Servidor encerrado")

    if __name__ == "__main__":
        main()
        
except ImportError as e:
    print(f"Erro ao importar dependencias: {e}")
    print("Instale as dependencias com: pip install websockets")
    sys.exit(1)
except Exception as e:
    print(f"Erro critico: {e}")
    sys.exit(1)