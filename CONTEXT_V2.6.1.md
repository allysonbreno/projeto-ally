# Contexto V2.6.1 – Servidor Autoritativo (2025-09-12)

## Visão Geral
- Modelo autoritativo no servidor Python: o cliente apenas envia input e renderiza estado.
- Mapas gerenciados por `MapManager` (Cidade/Floresta) com inimigos server-side.
- Banco SQLite em `server_data/game.db` (auto-criado/migrado no startup).

## Principais Mudanças
- Combate inimigo→player corrigido (defesa aplicada uma vez) e padronização do orc:
  - Fórmula: `dano_final = max(0, dano_inimigo − defesa_player)`.
  - Orc: `attack_damage = 10`, `attack_range = 24`.
  - Evento `player_damage` envia o dano final (pós-defesa) e HP atualizado.
- XP/Level/Stats:
  - Ganho de XP e level up (+5 pontos) autoritativos.
  - Eventos: `xp_gain`, `level_up`, `player_stats_update`.
  - Persistência automática (nível/XP/atributos/HP/posição/mapa) no SQLite.
- Atributos:
  - Novo endpoint `spend_attribute_point` no servidor; cliente só solicita.
- Sincronismo de players:
  - `players_list` agora cria players remotos ausentes (cada instância vê a outra no mesmo mapa).
- Entrada/Teclas:
  - Ação de ataque passou a ser `attack` (Ctrl/J). Space removido de `jump` (pular = W/↑).

## Como Rodar
1. Instalar dependências: `pip install -r server/requirements.txt`
2. Subir servidor: `python server/src/game_server.py`
3. Cliente (Godot): conectar, logar e alternar mapas (Cidade/Floresta).

## Testes Rápidos
- Dois clientes na Floresta se enxergam e veem orcs.
- Ctrl/J ataca; orcs tomam dano, XP sobe e level up distribui pontos.
- Ao encostar no orc, HP do player cai e popup de dano aparece (0 quando defesa cobre dano).
- Gastar ponto em Vitalidade aumenta HP máximo e persiste.

## Arquivos Relevantes
- `server/src/game_server.py`: roteamento, broadcast, persistência, `spend_attribute_point`.
- `server/src/maps/map_instance.py`: IA por mapa, dano inimigo→player e eventos.
- `server/src/enemies/multiplayer_enemy.py`: IA base, janela de impacto e sync de inimigos.
- `server/src/enemies/orc_enemy.py`: configuração do orc (dano 10, alcance 24).
- `server/src/players/server_player.py`: física, ataque, defesa, stats e alias `position`.
- `scripts/multiplayer_manager.gd`: sinais/handlers dos eventos do servidor.
- `multiplayer_game.gd`: criação de remotos via `players_list`, HUD e handlers.
- `scripts/input_setup.gd`: binds – `attack` (Ctrl/J); `jump` (W/↑).

