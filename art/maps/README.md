# 🗺️ Sistema de Mapas - Estrutura de Assets

## 📁 **Organização de Pastas**

```
art/maps/
├── forest/        # 🌲 Mapa Floresta (atual)
│   ├── backgrounds/
│   ├── tilesets/
│   └── effects/
├── swamp/         # 🐸 Mapa Pântano (futuro)
│   ├── backgrounds/
│   ├── tilesets/
│   └── effects/
└── [outros]/      # Expandir conforme necessário
```

## 🎨 **Tipos de Assets por Mapa**

### **backgrounds/**
- Fundos parallax
- Céu, nuvens, horizonte
- Elementos distantes

### **tilesets/**  
- Plataformas, terreno
- Obstáculos, decoração
- Elementos de colisão

### **effects/**
- Partículas ambientais
- Efeitos de clima
- Animações de ambiente

## 🌍 **Mapas Planejados**

### **🌲 Forest (Atual)**
- Inimigos: Orc
- Ambiente: Árvores, vegetação
- Clima: Dia claro

### **🐸 Swamp (Futuro)**
- Inimigos: Slime
- Ambiente: Pântano, lama
- Clima: Neblina, umidade

## 🔧 **Padrões Técnicos**

- **Formato**: PNG com transparência
- **Orientação**: Baseada na perspectiva do mapa
- **Escala**: Adaptável pelo código
- **Organização**: Por tipo de asset

---
*Sistema escalável para múltiplos mapas*