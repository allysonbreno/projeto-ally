# CHANGELOG - PROJETO ALLY v2.9.1

## [v2.9.1] - 2025-01-17

### 🎨 **VISUAL OVERHAUL**

#### **Background System Rework**
- **ADDED**: New city background with proper scaling algorithm
- **CHANGED**: Background positioning to left edge of screen
- **FIXED**: Background scaling using `min(scale_x, scale_y) * 1.2` for 1152x648 resolution
- **REACTIVATED**: Forest background display

#### **HUD Complete Redesign**
- **MOVED**: HUD from horizontal-top layout to vertical-right layout
- **CREATED**: Custom pixel art icons (32x32):
  - Status: Flexed arm with muscle
  - Inventory: Backpack with straps and pockets
  - Maps: Scroll with rivers, mountains, and X marker
- **POSITIONED**: HUD in right gray area (80%-100% of screen width)
- **OPTIMIZED**: Layout with 3-column grid for icon buttons

### 🎮 **GAMEPLAY IMPROVEMENTS**

#### **Player Positioning**
- **ALIGNED**: Player spawn with dirt path in background
- **UPDATED**: Server spawn position from (100, 159) to (0, 240)
- **ADJUSTED**: Ground collision from 184.0 to 265.0
- **MIGRATED**: 15 existing characters to new positions in database

#### **Collision System**
- **EXPANDED**: Left boundary by 30px (to x=-542.0)
- **CLOSED**: Right boundary at x=200 (near red line)
- **IMPLEMENTED**: Dynamic ground level per map

### 🏗️ **TECHNICAL CHANGES**

#### **Modified Files**
- `scripts/hud.gd`: Complete rewrite with icon generation
- `scripts/city_map_multiplayer.gd`: Background and collision updates
- `server/src/maps/map_instance.py`: New spawn positions and boundaries
- `server/src/players/server_player.py`: Dynamic ground level support
- `server_data/game.db`: Character position migration

#### **New Features**
- Programmatic pixel art icon generation
- Anchor-based HUD positioning system
- Map-specific ground level configuration
- Visual hierarchy with Z-index management

### 🐛 **Bug Fixes**
- Fixed HUD elements appearing outside gray area
- Corrected background scaling for different resolutions
- Resolved player position inconsistencies between client/server
- Fixed collision boundaries for proper movement constraints

### 📊 **Database Changes**
```sql
-- Updated all existing characters to new spawn position
UPDATE characters SET pos_y = 240.0 WHERE pos_y = 159.0;
```

### 🎯 **Visual Layout Specifications**
- **HUD Area**: Right 20% of screen (gray area)
- **Margins**: 5px on all sides
- **Font Sizes**: 12px title, 10px labels, 8px buttons
- **Icon Size**: 32x32 pixels
- **Button Size**: 50x50 pixels
- **Colors**: Custom styled progress bars (red HP, blue XP)

---

## **Migration Notes**
When updating from previous versions:
1. Backup existing `server_data/game.db`
2. Run character position migration if needed
3. Test HUD positioning on target resolution
4. Verify collision boundaries in both City and Forest maps

## **Known Issues**
- None reported in current version

## **Next Version Goals**
- Additional maps implementation
- Enhanced inventory system
- More character customization options
- Performance optimizations