extends Resource
class_name PlayerSprites

# Pre-load all player textures
const IDLE_FRAMES = [
	preload("res://art/player/idle_east/frame_000.png"),
	preload("res://art/player/idle_east/frame_001.png"),
	preload("res://art/player/idle_east/frame_002.png"),
	preload("res://art/player/idle_east/frame_003.png"),
	preload("res://art/player/idle_east/frame_004.png"),
	preload("res://art/player/idle_east/frame_005.png"),
	preload("res://art/player/idle_east/frame_006.png"),
	preload("res://art/player/idle_east/frame_007.png"),
	preload("res://art/player/idle_east/frame_008.png"),
	preload("res://art/player/idle_east/frame_009.png")
]

const WALK_FRAMES = [
	preload("res://art/player/walk_east/frame_000.png"),
	preload("res://art/player/walk_east/frame_001.png"),
	preload("res://art/player/walk_east/frame_002.png"),
	preload("res://art/player/walk_east/frame_003.png"),
	preload("res://art/player/walk_east/frame_004.png"),
	preload("res://art/player/walk_east/frame_005.png"),
	preload("res://art/player/walk_east/frame_006.png"),
	preload("res://art/player/walk_east/frame_007.png")
]

const JUMP_FRAMES = [
	preload("res://art/player/jump_east/frame_000.png"),
	preload("res://art/player/jump_east/frame_001.png"),
	preload("res://art/player/jump_east/frame_002.png"),
	preload("res://art/player/jump_east/frame_003.png"),
	preload("res://art/player/jump_east/frame_004.png"),
	preload("res://art/player/jump_east/frame_005.png"),
	preload("res://art/player/jump_east/frame_006.png"),
	preload("res://art/player/jump_east/frame_007.png"),
	preload("res://art/player/jump_east/frame_008.png")
]

const ATTACK_FRAMES = [
	preload("res://art/player/attack_east/frame_000.png"),
	preload("res://art/player/attack_east/frame_001.png"),
	preload("res://art/player/attack_east/frame_002.png"),
	preload("res://art/player/attack_east/frame_003.png"),
	preload("res://art/player/attack_east/frame_004.png")
]

static func get_frames(animation: String) -> Array:
	match animation:
		"idle": return IDLE_FRAMES
		"walk": return WALK_FRAMES  
		"jump": return JUMP_FRAMES
		"attack": return ATTACK_FRAMES
		_: return []