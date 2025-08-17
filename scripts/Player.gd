
extends CharacterBody2D

@export var speed: float = 220.0
@export var jump_velocity: float = -420.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") as float

func _physics_process(delta: float) -> void:
    var input_dir: float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
    var v: Vector2 = velocity

    if not is_on_floor():
        v.y += gravity * delta
    else:
        if Input.is_action_just_pressed("jump"):
            v.y = jump_velocity

    v.x = input_dir * speed
    velocity = v
    move_and_slide()

func _on_Hurtbox_area_entered(area: Area2D) -> void:
    if area.name == "Hitbox":
        _respawn()

func _respawn() -> void:
    global_position = Vector2(100, 300)
    velocity = Vector2.ZERO
