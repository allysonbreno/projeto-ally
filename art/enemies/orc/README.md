# 🧌 ORC - Inimigo Principal da Floresta

## 📋 **Informações do Inimigo**

- **Tipo**: Orc Guerreiro
- **Localização**: Mapa Floresta
- **Comportamento**: Agressivo, persegue jogadores
- **HP**: 100 (configurável)
- **Velocidade**: 112.0 (configurável)

## 🎬 **Animações Necessárias**

### **idle/** - Animação Parado
- Orc respirando/aguardando
- Loop infinito
- FPS recomendado: 4-6

### **walk/** - Animação Caminhada  
- Orc se movendo em direção ao jogador
- Loop infinito
- FPS recomendado: 8

### **attack/** - Animação Ataque
- Orc realizando ataque corpo a corpo
- Uma execução (não loop)
- FPS recomendado: 7

## 📐 **Orientação dos Sprites**

- **Direção padrão**: Voltado para a DIREITA
- **Flip automático**: Código inverte quando necessário
- **Centralização**: Sprites devem estar centralizados

## 🔄 **Para Substituir Sprites Atuais:**

1. Coloque os frames em suas respectivas pastas
2. Mantenha a numeração `frame_000.png`, `frame_001.png`...
3. O código já está preparado para carregar automaticamente

---
*Substitui os sprites atuais de `art/enemy_forest/`*