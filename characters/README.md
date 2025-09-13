# Estrutura de Animações dos Personagens

Este diretório contém as animações para os 3 tipos de personagens disponíveis no jogo.

## Estrutura de Pastas

```
characters/
├── warrior/
│   ├── idle_east/     # Parado (virado para direita)
│   ├── walk_east/     # Caminhando (virado para direita)
│   ├── attack_east/   # Atacando (virado para direita)
│   └── jump_east/     # Pulando (virado para direita)
├── mage/
│   ├── idle_east/
│   ├── walk_east/
│   ├── attack_east/
│   └── jump_east/
└── archer/
    ├── idle_east/
    ├── walk_east/
    ├── attack_east/
    └── jump_east/
```

## Como Nomear os Frames

**IMPORTANTE**: Siga exatamente o padrão do projeto atual!

### Nomenclatura dos Frames:
- `frame_000.png` - Primeiro frame
- `frame_001.png` - Segundo frame  
- `frame_002.png` - Terceiro frame
- `frame_003.png` - Quarto frame
- ... e assim por diante

### Exemplo para Guerreiro Parado:
```
characters/warrior/idle_east/
├── frame_000.png
├── frame_001.png
├── frame_002.png
├── frame_003.png
└── frame_004.png
```

## Animações Obrigatórias

### Para cada personagem, crie estas pastas:
- **`idle_east/`** - Personagem parado (virado para direita)
- **`walk_east/`** - Personagem caminhando (virado para direita)
- **`attack_east/`** - Personagem atacando (virado para direita)
- **`jump_east/`** - Personagem pulando (virado para direita)

### Quantos frames usar:
- **idle_east**: 6-10 frames (respiração sutil)
- **walk_east**: 8-12 frames (ciclo de caminhada)
- **attack_east**: 4-8 frames (golpe rápido)
- **jump_east**: 4-6 frames (salto)

## Atributos dos Personagens

### Guerreiro (Warrior)
- **Força**: 8 - Alto dano físico
- **Defesa**: 7 - Boa resistência
- **Inteligência**: 3 - Baixo poder mágico
- **Vitalidade**: 7 - Boa quantidade de HP
- **Estilo**: Combate corpo a corpo, tanque

### Mago (Mage)
- **Força**: 3 - Baixo dano físico
- **Defesa**: 4 - Baixa resistência
- **Inteligência**: 8 - Alto poder mágico
- **Vitalidade**: 5 - HP médio
- **Estilo**: Ataques à distância, suporte

### Arqueiro (Archer)
- **Força**: 6 - Dano físico moderado
- **Defesa**: 5 - Resistência moderada
- **Inteligência**: 6 - Poder mágico moderado
- **Vitalidade**: 6 - HP moderado
- **Estilo**: Balanceado, versátil

## Integração no Godot

Após colocar as imagens nas pastas:
1. Abra o projeto no Godot
2. As imagens aparecerão automaticamente no FileSystem
3. Arraste as imagens para criar AnimatedSprite2D
4. Configure as animações no AnimationPlayer

## Sistema de Personagens

O sistema atual:
- Cada usuário pode ter apenas 1 personagem
- O tipo do personagem é selecionado na criação
- As animações são carregadas dinamicamente baseadas no tipo
- O estado do personagem é salvo automaticamente no banco de dados