#!/usr/bin/env python3
import sys
import os
import asyncio

# Adicionar pasta src ao path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

try:
    from game_server import GameServer
    
    async def main():
        print("Iniciando Servidor Multiplayer...")
        server = GameServer()
        await server.start_server()
        
        try:
            await asyncio.Future()  # Run forever
        except KeyboardInterrupt:
            print("Parando servidor...")
            await server.stop_server()
    
    if __name__ == "__main__":
        asyncio.run(main())
        
except ImportError as e:
    print(f"Erro ao importar: {e}")
    print("Instale: pip install websockets")
    sys.exit(1)
except Exception as e:
    print(f"Erro: {e}")
    sys.exit(1)