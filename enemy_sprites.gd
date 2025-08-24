extends Resource
class_name EnemySprites

# Pre-load all enemy textures
const WALK_FRAMES = [
	preload("res://art/enemy_forest/walk_east/frame_000.png"),
	preload("res://art/enemy_forest/walk_east/frame_001.png"),
	preload("res://art/enemy_forest/walk_east/frame_002.png"),
	preload("res://art/enemy_forest/walk_east/frame_003.png")
]

const ATTACK_FRAMES = [
	preload("res://art/enemy_forest/attack_east/frame_000.png"),
	preload("res://art/enemy_forest/attack_east/frame_001.png"),
	preload("res://art/enemy_forest/attack_east/frame_002.png"),
	preload("res://art/enemy_forest/attack_east/frame_003.png"),
	preload("res://art/enemy_forest/attack_east/frame_004.png"),
	preload("res://art/enemy_forest/attack_east/frame_005.png"),
	preload("res://art/enemy_forest/attack_east/frame_006.png")
]

static func get_frames(animation: String) -> Array:
	match animation:
		"walk": return WALK_FRAMES
		"attack": return ATTACK_FRAMES
		_: return []