# Projeto Ally - Jogo 2D RPG

## Versão Atual: v2.1

Um jogo 2D desenvolvido em Godot 4 com sistema completo de RPG, incluindo combate, progressão de personagem, inventário, drop de itens e sistema de auto attack. 

**🎯 Status do Projeto:** Jogo completo e funcional, disponível para Windows e Android!

## 🎮 Funcionalidades Implementadas

### Sistema de Personagem
- **Sistema de HP**: Barra de vida funcional
- **Sistema de XP e Level**: 
  - Ganho de XP ao derrotar inimigos
  - Sistema de level up automático
  - XP necessário aumenta 20% a cada nível
- **Sistema de Atributos**:
  - **Força**: Aumenta dano de ataque
  - **Defesa**: Reduz dano recebido
  - **Inteligência**: (reservado para uso futuro)
  - **Vitalidade**: Aumenta HP máximo (+20 HP por ponto)
  - **Pontos de Atributo**: Ganho de 5 pontos por level up

### Sistema de Combate
- **Ataque do Player**: Combate corpo a corpo
- **Sistema de Auto Attack**: Ataque automático ativável/desativável
- **Sistema de Dano**: Calculado com força + dano da arma equipada
- **Redução de Dano**: Baseada no atributo defesa
- **Hitbox de Ataque**: Sistema de colisão para ataques
- **Feedback Visual**: Números flutuantes de dano

### Sistema de Inventário (v2.0)
- **5 Slots de Inventário**: Para armazenar itens
- **Slot de Arma Equipada**: Separado do inventário principal
- **Interface Visual**: Ícones dos itens ao invés de apenas texto
- **Sistema de Equipar/Desequipar**: Armas com um clique
- **Drop de Itens**: Inimigos dropam "Espada de Ferro" ao morrer
- **Coleta Interativa**: Aproxime-se do item e pressione Enter
- **Feedback Visual**: Mensagens de item coletado/inventário cheio

### Mapas e Navegação
- **Cidade**: Mapa hub principal
- **Floresta**: Mapa de combate com inimigos
- **Navegação**: Sistema de seleção de mapas via HUD
- **Reset automático**: Player volta à cidade ao morrer ou completar mapa

### Interface (HUD)
- **Barras de Status**: HP e XP com estilos visuais
- **Distribuição de Pontos**: Interface para alocar pontos de atributo
- **Inventário**: Janela completa com slots visuais
- **Status**: Visualização detalhada dos atributos
- **Botões**: Mapas, Status, Inventário

### Sistema de Audio
- **SFX**: Sons de ataque, hit, dano, morte, completar mapa
- **Volume Balanceado**: Níveis ajustados para cada som

### Animações
- **Player**: Idle, Walk, Jump, Attack (todas direcionais)
- **Inimigos**: Walk e Attack com sprites animados
- **Sprites Escalados**: Personagens e inimigos em tamanho apropriado

## 🗂️ Estrutura de Arquivos

```
projeto-ally/
├── main.gd                 # Sistema principal do jogo
├── scripts/
│   ├── player.gd          # Lógica do personagem
│   ├── enemy.gd           # Lógica dos inimigos
│   ├── hud.gd             # Interface do usuário
│   ├── item_drop.gd       # Sistema de itens no chão
│   ├── city_map.gd        # Mapa da cidade
│   ├── forest_map.gd      # Mapa da floresta
│   └── input_setup.gd     # Configuração de controles
├── art/
│   ├── player/            # Sprites do personagem
│   ├── enemy_forest/      # Sprites dos inimigos
│   ├── items/             # Ícones dos itens
│   └── bg/                # Backgrounds dos mapas
└── audio/                 # Efeitos sonoros
```

## 🎯 Como Jogar

### Controles
- **Movimento**: WASD ou setas
- **Pular**: Space
- **Atacar**: Mouse esquerdo
- **Auto Attack**: A (ativa/desativa ataque automático)
- **Coletar Item**: Enter (quando próximo)
- **Interface**: Clique nos botões da HUD

### Progressão
1. Explore a cidade (tutorial/hub)
2. Vá para a Floresta via menu Mapas
3. Derrote inimigos para ganhar XP
4. Colete espadas dropadas pelos inimigos
5. Use pontos de atributo para fortalecer seu personagem
6. Gerencie seu inventário equipando melhores armas

### Sistema de Atributos
- **Força**: Cada ponto = +1 dano de ataque
- **Defesa**: Cada ponto = -1 dano recebido
- **Vitalidade**: Cada ponto = +20 HP máximo
- **Inteligência**: Reservado para magias futuras

## 📈 Histórico de Versões

### v2.1 - Sistema de Auto Attack e Distribuição Completa ⭐
- ✅ Sistema de auto attack ativável/desativável
- ✅ Sprites corrigidos para builds compilados
- ✅ Build Windows com instalador NSIS
- ✅ Build Android APK assinado
- ✅ Recursos pré-carregados para melhor performance

### v2.0 - Sistema de Inventário e Drop
- ✅ Inventário completo com 5 slots
- ✅ Sistema de drop de itens
- ✅ Interface visual com ícones
- ✅ Equipar/desequipar armas
- ✅ Coleta interativa de itens

### v1.9 - Sistema de Atributos
- ✅ Distribuição de pontos completa
- ✅ Interface de atributos
- ✅ Cálculo de stats baseado em atributos

### v1.8 - Sistema de XP e Level
- ✅ Ganho de XP por inimigo morto
- ✅ Level up automático
- ✅ Progressão de dificuldade

### v1.7 e anteriores
- ✅ Sistema de combate básico
- ✅ Animações e sprites
- ✅ Mapas e navegação
- ✅ Audio e feedback visual

## 🔧 Tecnologias

- **Engine**: Godot 4.4.1
- **Linguagem**: GDScript
- **Resolução**: Adaptável
- **Plataformas**: Windows (Instalador) e Android (APK)

## 📦 Downloads

### Windows
- **Instalador**: `builds/Projeto Ally v2.1 Installer.exe` (48MB)
- **Inclui**: Executável, recursos e desinstalador
- **Compatibilidade**: Windows 7+ (x64)

### Android  
- **APK**: `builds/projeto-ally-signed.apk` (31.6MB)
- **Arquitetura**: ARM64-v8a
- **Android**: 5.0+ (API 21+)
- **Permissões**: Mínimas necessárias

## 🔧 Desenvolvimento

Para compilar o projeto:
- Consulte `README_BUILD.md` para instruções detalhadas
- Requer Android SDK para builds Android
- NSIS para geração do instalador Windows

## 🎨 Assets

- Sprites de personagem e inimigos customizados
- Ícones de itens 64x64
- Backgrounds de cenário
- Efeitos sonoros integrados

---

**🎮 Projeto Ally v2.1 - RPG 2D Completo**  
**Desenvolvido com Godot 4.4.1 | Project Brothers**  
**Disponível para Windows e Android** 🖥️📱