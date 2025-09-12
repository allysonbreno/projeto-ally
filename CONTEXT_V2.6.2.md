# Contexto V2.6.2 – Respawn Autoritativo e UX (" + 2025-09-12 + ")

## Objetivo
Garantir que ao morrer o jogador volte para a Cidade de forma autoritativa, vivo e jogável, sem travas de movimento e sem artefatos visuais (HP 0 momentâneo).

## Mudanças Principais
- Respawn/Retorno para a Cidade (cliente/servidor):
  - Servidor já tinha lógica de mover o player para "Cidade" após morte (map_change + listas), e garantir is_alive = True, hp = max_hp, nimation = "idle".
  - Cliente agora reforça a troca com send_map_change("Cidade") ao detectar HP <= 0, cobrindo ordem de mensagens.
  - Cliente corrige HUD imediatamente após load_city(false): player_hp = player_hp_max e hud.update_health().
- UX de movimento pós-respawn:
  - Envia um snapshot de input (_send_input_snapshot()) logo após carregar a Cidade para evitar “travamento” até a próxima mudança de tecla.
  - Define current_map_node = city durante load_city para manter referências consistentes do mapa atual.
- Estabilidade do map_change:
  - Servidor ignora map_change para o mesmo mapa (evita respawn indevido).
  - Map_change do cliente não possui delay de 1s (aplicado em ajustes anteriores) para remover jank visual.

## Arquivos Relevantes
- multiplayer_game.gd
  - load_city(false): atualiza HUD para HP 100% e envia snapshot de input.
  - Envia send_map_change("Cidade") no handler de dano quando HP <= 0.
  - Mantém current_map_node = city após carregar cena.
- server/src/game_server.py
  - (anterior) Evita move_player para o mesmo mapa; respawn autoritativo e notificações de presence.

## Fluxo de Morte/Respawn
1. Inimigo aplica player_damage (HP pode chegar a 0).
2. Cliente:
   - Mostra popup, chama load_city(false).
   - Seta HP local para 100% (visual) e atualiza HUD.
   - Envia map_change("Cidade") (reforço autoritativo).
   - Envia snapshot de input para evitar travas.
3. Servidor:
   - Move para Cidade (se ainda não moveu), revive (hp = max_hp, is_alive = True) e notifica mapas.
   - Atualiza listas (players_list) e envia stats para o jogador.

## Testes Rápidos
- Morra na Floresta: cena troca para Cidade, HP 100% no HUD, movimento responde.
- Retorne à Floresta e tome dano: HUD permanece consistente.
- Verifique logs do servidor por map_change -> Cidade ao morrer.

