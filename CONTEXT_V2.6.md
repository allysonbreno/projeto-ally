Contexto v2.6 — Projeto Ally

Objetivo
- Consolidar multiplayer server‑authoritative com presença por mapa (Cidade/Floresta), spawn consistente, plataformas visuais e sincronização de inimigos.

Arquitetura (resumo)
- Servidor (Python): asyncio + websockets; envia/recebe JSON; roda loops a 60 FPS para players e inimigos; aplica limites de mapa.
- Cliente (Godot 4): recebe estado autoritativo, renderiza players e inimigos; envia apenas input e eventos de mapa/ação.

Mapas
- Cidade: mapa inicial; limites e chão em y=184.
- Floresta: mapa com orcs; spawn do player local na extremidade esquerda; mesmos limites e chão y=184.
- Client: scripts/*_map_multiplayer.gd criam Polygon2D de chão/parede/teto (fundos desativados por padrão) — SHOW_BACKGROUND=false, SHOW_PLATFORM_VISUAL=true.

Presença por mapa (cliente)
- Eventos do servidor:
  - players_list: contém apenas players do SEU mapa; usado para marcar players remotos como current_map = mapa atual do cliente.
  - player_left_map: usado para esconder player remoto e marcar como “OUTRO”.
- Implementação:
  - scripts/multiplayer_manager.gd: emite os sinais players_list_received(players) e player_left_map_received(player_id).
  - multiplayer_game.gd: conecta aos sinais e atualiza meta current_map em cada remote_player; chama _update_remote_players_visibility().

Spawn e nomes
- Spawn na Floresta: _position_players_in_forest() é chamado imediatamente após carregar o mapa — evita “pulo” do centro para a esquerda.
- Label do player usa server_data["name"], garantindo nome correto por instância (labels não ficam como "PLAYER").

Inimigos (Orcs)
- Servidor envia campos planos: x, y, velocity_x, velocity_y, animation, facing_left...
- scripts/forest_map_multiplayer.gd: ajustado parsing para esses campos; orcs renderizados na plataforma e perseguição correta.
- Anti‑sobreposição visual: se orc e player local ficarem muito próximos, o X visual do orc é ajustado com um gap mínimo (display‑only; o servidor continua autoritativo).

Limites de Mapa (servidor)
- server/src/maps/map_instance.py:
  - _get_map_bounds() por mapa (min_x/max_x/min_y/ground_y).
  - update_players() aplica clamp vertical adicional (teto/chão), além do clamp lateral existente no ServerPlayer.

Sinais e mensagens
- Do servidor → cliente (relevantes):
  - login_response, players_list, player_sync, players_update, enemies_state, enemies_update, player_left_map
- Do cliente → servidor (relevantes):
  - login, player_input, map_change, player_attack_enemy

Como rodar
- Servidor: cd server/src; python game_server.py
- Cliente: abrir res://login_multiplayer.tscn no Godot (ou CLI). Para 2 clientes, use --user-data-dir distintos.

Checklist de verificação
- Cidade: duas instâncias logadas com nomes distintos → ambas se veem.
- Instância 1 vai para Floresta → instância 2 (Cidade) não vê mais a 1.
- Instância 2 entra na Floresta → ambas se veem e sincronizam nomes/posições/ações.
- Orcs nascem na plataforma e perseguem, atacando ao encostar.

Arquivos alterados principais (v2.6)
- README.md (novo): visão v2.6 + execução.
- CONTEXT_V2.6.md (este arquivo): contexto e decisões.
- scripts/multiplayer_manager.gd: novos sinais + roteamento de mensagens.
- multiplayer_game.gd: handlers de presença por mapa + spawn imediato na Floresta.
- scripts/forest_map_multiplayer.gd: parsing de inimigos e gap visual.
- scripts/city_map_multiplayer.gd / scripts/forest_map_multiplayer.gd: plataformas visuais alinhadas.
- scripts/multiplayer_player.gd: label com nome autoritativo.

Observações
- Alguns arquivos apresentam caracteres estranhos em logs (encoding); não afeta execução.
- Caso reinicie a sessão, use este arquivo para reconstituir o contexto e o README.md para passos de execução.

