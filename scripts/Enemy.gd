
extends CharacterBody2D

@export var speed: float = 80.0
var left_x: float
var right_x: float
var dir: int = 1
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") as float

func _ready() -> void:
    var left_point := $LeftPoint.global_position.x
    var right_point := $RightPoint.global_position.x
    left_x = min(left_point, right_point)
    right_x = max(left_point, right_point)

func _physics_process(delta: float) -> void:
    var v: Vector2 = velocity
    if not is_on_floor():
        v.y += gravity * delta
    v.x = dir * speed
    velocity = v
    move_and_slide()

    if (dir == 1 and global_position.x >= right_x) or (dir == -1 and global_position.x <= left_x):
        dir *= -1
        if $Sprite2D:
            $Sprite2D.flip_h = dir < 0
