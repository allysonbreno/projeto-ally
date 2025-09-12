# Changelog

## v2.6.1 (2025-09-12)

### Fixed
- Combate inimigo→player: defesa do jogador aplicada uma única vez (server-authoritative).
- Ordem do ataque do inimigo (alvo definido antes da janela de impacto) para garantir acertos.
- Criação de players remotos a partir de `players_list` (ambas as instâncias se veem ao entrar no mesmo mapa).

### Changed
- Orcs padronizados: `attack_damage = 10`, `attack_range = 24`.
- Entrada: ataque usa a action `attack` (Ctrl/J); Space removido de `jump`.
- `ServerPlayer` refatorado (update limpo, alias `position`).
- Broadcast de eventos extras dos inimigos (ex.: `player_damage`) durante o loop, mesmo sem `enemies_update` no frame.

### Added
- Endpoint `spend_attribute_point` (servidor autoritativo) e persistência de nível/XP/atributos/HP/posição/mapa.
- Eventos: `xp_gain`, `level_up`, `player_stats_update`, `player_damage` no pipeline cliente-servidor.

### Verification Checklist
- Dois clientes na Floresta enxergam um ao outro; “Jogadores: 2” no HUD.
- Ctrl/J ataca; orcs levam dano; XP sobe; level up concede pontos.
- HP do player cai ao ser atingido por orc; popup exibe o dano final (0 quando defesa cobre o dano).
- Ponto em Vitalidade aumenta HP máximo e persiste após reconexão.

## v2.6 (2025-09-10)

### Added
- Presence by map (Cidade/Floresta) on the client using `players_list` and `player_left_map` events.
- New client signals and handlers:
  - `players_list_received(players)` — emitted after processing list; marks remotes in current map.
  - `player_left_map_received(player_id)` — emitted when someone leaves your map.
- Immediate spawn at the left side of Floresta to avoid visual teleport.
- Visual platforms (Polygon2D) for City/Forest with background disabled by default.
- Server authoritative map bounds (min_x/max_x/min_y/ground_y) and vertical clamp (ceiling/ground).
- Enemy assets (orc) and server modules (enemies/players) added to repository.
- Documentation: new `README.md` and detailed `CONTEXT_V2.6.md`.

### Changed
- Server: integrated `MapManager` and filtered broadcasts by map; ignored `player_update` from clients.
- Client: player label shows authoritative name from the server; parsing of enemy state uses flat fields `x`, `y`, `velocity_x`, `velocity_y`.
- Forest map: added small visual gap to avoid apparent overlap between orcs and the local player (display-only).

### Removed
- Legacy server files: `run_server.py`, `run_simple.py`, `server_gui.py`, `enemy_server.py`.
- Ignored caches and temps via `.gitignore` (pyc, __pycache__, TMP_*.txt, logs_*.txt).

### Verification Checklist
- Two clients in City see each other with correct names.
- When client A goes to Forest, client B (still in City) no longer sees A.
- When client B enters Forest, both see each other in Forest.
- Orcs spawn on the platform, move toward players, and attack on contact.
- Players remain inside the map “box” (cannot fall below/leave the map).
## v2.6.2 (2025-09-12)

### Fixed
- Respawn: jogador volta à Cidade vivo (is_alive = true) e com HP 100%, sem travas de movimento.
- HUD pós-morte: evita exibir HP 0 na Cidade (ajuste imediato no cliente), e sincroniza com stats do servidor.

### Changed
- Cliente envia map_change("Cidade") ao detectar HP <= 0 (reforço autoritativo de troca de mapa).
- Snapshot de input após load_city(false) para evitar travas até a próxima mudança de tecla.
- current_map_node é definido em City para consistência.

### Notes
- Servidor mantém proteção para ignorar map_change para o mesmo mapa, evitando respawn indevido.

