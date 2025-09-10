# 🐺 Sistema de Inimigos - Estrutura de Assets

## 📁 **Organização de Pastas**

```
art/enemies/
├── orc/           # 🧌 Inimigo Orc (atual)
│   ├── idle/      # Animação parada
│   ├── walk/      # Animação caminhada  
│   └── attack/    # Animação ataque
├── slime/         # 🟢 Inimigo Slime (futuro)
│   ├── idle/
│   ├── walk/
│   └── attack/
└── [outros]/      # Expandir conforme necessário
```

## 🎨 **Padrão de Nomenclatura**

### **Arquivos de Animação:**
- `frame_000.png`, `frame_001.png`, `frame_002.png`...
- Numeração sequencial com 3 dígitos
- Formato PNG com transparência

### **Animações Obrigatórias:**
- **idle**: Inimigo parado/respirando
- **walk**: Inimigo se movendo
- **attack**: Inimigo atacando

## 🔧 **Instruções para Adicionar Novos Inimigos**

1. **Criar pasta**: `art/enemies/[nome_inimigo]/`
2. **Criar subpastas**: `idle/`, `walk/`, `attack/`
3. **Adicionar sprites**: Seguir padrão `frame_XXX.png`
4. **Configurar no código**: Atualizar `enemy_multiplayer.gd`

## 📊 **Especificações Técnicas**

- **Orientação**: Todos sprites voltados para a direita
- **Resolução**: Flexível (código adapta automaticamente)  
- **Formato**: PNG com canal alpha
- **FPS**: Configurável por animação (padrão 8 FPS)

---
*Sistema escalável para múltiplos tipos de inimigos*