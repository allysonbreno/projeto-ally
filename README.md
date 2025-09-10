Projeto Ally — v2.6

Visão Geral
- Cliente: Godot 4.4.1 (GDScript), renderização client‑only.
- Servidor: Python (asyncio + websockets), server‑authoritative.
- Protocolo: WebSocket ws://localhost:8765.
- Multiplayer com mapas: Cidade e Floresta, com presença por mapa (players só veem quem está no mesmo mapa).

Principais mudanças v2.6
- Presença por mapa no cliente: trata players_list e player_left_map para ativar/desativar players corretamente ao mudar de mapa.
- Spawn imediato na Floresta: posiciona local player na extremidade esquerda assim que o mapa carrega (sem “pulo”).
- Física de mapa “caixa fechada”: Cidade e Floresta com limites server‑side (teto, chão e laterais); cliente exibe plataformas visuais.
- Inimigos (Orcs) sincronizados do servidor: parsing ajustado (x, y, velocity_x, velocity_y). Evita sobreposição visual com player local.
- Nomes corretos nos labels: label do player renderiza o nome autoritativo enviado pelo servidor.

Como Executar
1) Servidor
   - cd server/src
   - python game_server.py

2) Cliente (Godot)
   - Abrir o projeto (project.godot) e executar res://login_multiplayer.tscn
   - Ou via CLI do Godot: Godot.exe --path <pasta do projeto> res://login_multiplayer.tscn

3) Testar múltiplas instâncias
   - Inicie 2 processos do Godot com diretórios de dados distintos (ex.: --user-data-dir .client1 e .client2)
   - Faça login com nomes distintos.

Mapas e Presença
- O servidor envia players_list com apenas os players do seu mapa atual e player_left_map quando alguém sai do seu mapa.
- O cliente usa esses eventos para marcar remotos com meta current_map e atualizar a visibilidade (somente players do mesmo mapa ficam visíveis e ativos).

Plataformas Visuais (cliente)
- Cidade: scripts/city_map_multiplayer.gd
- Floresta: scripts/forest_map_multiplayer.gd
- Fundos desativados por padrão; adicionadas barras (Polygon2D) para representar chão/parede/teto.

Servidor (limites de mapa)
- server/src/maps/map_instance.py define os limites de cada mapa (min_x, max_x, min_y, ground_y) e aplica clamp vertical/lateral a cada frame.

Problemas Conhecidos
- Encoding de alguns logs/strings pode mostrar caracteres estranhos; não afeta funcionalidade.
- Orcs são display‑only no cliente; o bloqueio “real” acontece no servidor. (Foi adicionado espaçamento visual mínimo no cliente.)

Changelog Resumido
- scripts/multiplayer_manager.gd: novos sinais e roteamento de mensagens; emite players_list_received e player_left_map_received.
- multiplayer_game.gd: conecta e trata eventos para visibilidade por mapa; spawn imediato na Floresta.
- scripts/forest_map_multiplayer.gd: parsing de inimigos do servidor; ajuste visual anti‑sobreposição.
- scripts/city_map_multiplayer.gd / scripts/forest_map_multiplayer.gd: plataformas visuais e alinhamento com ground_y=184.
- scripts/multiplayer_player.gd: label usa nome autoritativo do servidor.

Licença
- Interno para testes; ajustar conforme necessário.

