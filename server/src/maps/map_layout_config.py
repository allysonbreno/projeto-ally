"""
MAP LAYOUT CONFIGURATION - PROJETO ALLY v2.9.1+
Template padrão para configurações server-side de mapas
Garante consistência de layout e boundaries em todos os mapas
"""

# CONFIGURAÇÕES PADRÃO DE LAYOUT
# Área cinza direita (80%-100%) sempre reservada para HUD
HUD_RESERVED_AREA_START = 0.8  # 80% da tela
VIEWPORT_WIDTH = 1152  # Resolução padrão
VIEWPORT_HEIGHT = 648

# BOUNDARIES PADRÃO - SEMPRE manter estes valores para consistência
STANDARD_LEFT_BOUNDARY = -542.0   # Expandido para dar mais espaço de movimento
STANDARD_RIGHT_BOUNDARY = 200.0   # Fechado para reservar espaço HUD
STANDARD_CEILING = -200.0          # Teto padrão

# CONFIGURAÇÕES DE MAPAS
MAP_CONFIGS = {
    "Cidade": {
        "spawn_position": {"x": 0, "y": 240},
        "boundaries": {
            "min_x": STANDARD_LEFT_BOUNDARY,
            "max_x": STANDARD_RIGHT_BOUNDARY,
            "min_y": STANDARD_CEILING,
            "ground_y": 265.0  # Alinhado ao caminho de terra
        }
    },
    "Floresta": {
        "spawn_position": {"x": -200, "y": 265},
        "boundaries": {
            "min_x": STANDARD_LEFT_BOUNDARY,
            "max_x": STANDARD_RIGHT_BOUNDARY,
            "min_y": STANDARD_CEILING,
            "ground_y": 265.0  # Ground level da floresta (alinhado com cidade)
        }
    }
}

def get_map_spawn_position(map_name: str) -> dict:
    """Retorna posição de spawn para o mapa especificado"""
    return MAP_CONFIGS.get(map_name, {}).get("spawn_position", {"x": 0, "y": 0})

def get_map_boundaries(map_name: str) -> dict:
    """Retorna boundaries para o mapa especificado"""
    default_boundaries = {
        "min_x": STANDARD_LEFT_BOUNDARY,
        "max_x": STANDARD_RIGHT_BOUNDARY,
        "min_y": STANDARD_CEILING,
        "ground_y": 265.0
    }
    return MAP_CONFIGS.get(map_name, {}).get("boundaries", default_boundaries)

def add_new_map_config(map_name: str, spawn_pos: dict, ground_level: float, 
                      custom_boundaries: dict = None) -> None:
    """
    Adiciona configuração para um novo mapa seguindo o template padrão
    
    Args:
        map_name: Nome do mapa
        spawn_pos: {"x": float, "y": float}
        ground_level: Nível Y do chão do mapa
        custom_boundaries: Boundaries customizadas (opcional)
    """
    if custom_boundaries is None:
        boundaries = {
            "min_x": STANDARD_LEFT_BOUNDARY,
            "max_x": STANDARD_RIGHT_BOUNDARY,
            "min_y": STANDARD_CEILING,
            "ground_y": ground_level
        }
    else:
        boundaries = custom_boundaries
        # Garantir que boundaries críticos são preservados
        boundaries["min_x"] = min(boundaries.get("min_x", STANDARD_LEFT_BOUNDARY), STANDARD_LEFT_BOUNDARY)
        boundaries["max_x"] = max(boundaries.get("max_x", STANDARD_RIGHT_BOUNDARY), STANDARD_RIGHT_BOUNDARY)
    
    MAP_CONFIGS[map_name] = {
        "spawn_position": spawn_pos,
        "boundaries": boundaries
    }
    
    print(f"[MAP_CONFIG] Novo mapa adicionado: {map_name}")
    print(f"  Spawn: {spawn_pos}")
    print(f"  Boundaries: {boundaries}")

def validate_map_layout(map_name: str) -> bool:
    """
    Valida se o layout do mapa segue os padrões estabelecidos
    """
    if map_name not in MAP_CONFIGS:
        print(f"[MAP_CONFIG] ERRO: Mapa {map_name} não configurado!")
        return False
    
    config = MAP_CONFIGS[map_name]
    boundaries = config["boundaries"]
    
    # Validar boundaries críticos
    if boundaries["max_x"] > STANDARD_RIGHT_BOUNDARY:
        print(f"[MAP_CONFIG] AVISO: {map_name} invade área HUD (max_x={boundaries['max_x']} > {STANDARD_RIGHT_BOUNDARY})")
        return False
    
    if boundaries["min_x"] > STANDARD_LEFT_BOUNDARY:
        print(f"[MAP_CONFIG] AVISO: {map_name} pode ter área de movimento reduzida (min_x={boundaries['min_x']} > {STANDARD_LEFT_BOUNDARY})")
    
    print(f"[MAP_CONFIG] ✅ Layout do mapa {map_name} validado com sucesso")
    return True

def get_hud_area_info() -> dict:
    """Retorna informações sobre a área reservada para HUD"""
    hud_start_x = VIEWPORT_WIDTH * HUD_RESERVED_AREA_START
    hud_width = VIEWPORT_WIDTH - hud_start_x
    
    return {
        "start_x": hud_start_x,
        "width": hud_width,
        "percentage": (1.0 - HUD_RESERVED_AREA_START) * 100,
        "viewport_width": VIEWPORT_WIDTH,
        "viewport_height": VIEWPORT_HEIGHT
    }

# Exemplo de uso para novos mapas:
"""
# Para adicionar um novo mapa:
add_new_map_config(
    map_name="NovoCampo",
    spawn_pos={"x": -100, "y": 200},
    ground_level=200.0
)

# Para validar o layout:
if validate_map_layout("NovoCampo"):
    print("Layout aprovado!")
"""