# Changelog

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

