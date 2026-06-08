extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_velocity: float = 7.5
@export var gravity: float = 25.0
@export var max_air_jumps: int = 1
@export var coyote_time: float = 0.15
@export var jump_buffer_time: float = 0.15

signal jumped(remaining_air_jumps: int)

var air_jumps_left: int = 0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
		coyote_timer -= delta
	else:
		coyote_timer = coyote_time
		air_jumps_left = max_air_jumps

	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	if jump_buffer_timer > 0.0:
		if is_on_floor() or coyote_timer > 0.0:
			velocity.y = jump_velocity
			jump_buffer_timer = 0.0
			coyote_timer = 0.0
			jumped.emit(air_jumps_left)
		elif air_jumps_left > 0:
			velocity.y = jump_velocity
			jump_buffer_timer = 0.0
			air_jumps_left -= 1
			jumped.emit(air_jumps_left)

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

func get_movement_state() -> StringName:
	if is_on_floor() and velocity.y <= 0:
		return &"grounded"
	elif not is_on_floor() and velocity.y > 0:
		return &"jumping"
	elif not is_on_floor() and velocity.y <= 0 and coyote_timer <= 0:
		return &"falling"
	elif not is_on_floor() and coyote_timer > 0:
		return &"coyote"
	return &"grounded"
