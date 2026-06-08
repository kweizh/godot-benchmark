extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_velocity: float = 7.5
@export var gravity: float = 25.0
@export var max_air_jumps: int = 1
@export var coyote_time: float = 0.15
@export var jump_buffer_time: float = 0.15

signal jumped(remaining_air_jumps: int)

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var air_jumps_left: int = 0


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Coyote timer
	if is_on_floor():
		coyote_timer = coyote_time
		air_jumps_left = max_air_jumps
	else:
		coyote_timer -= delta

	# Jump buffer
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	# Jump logic
	if jump_buffer_timer > 0.0:
		if is_on_floor() or coyote_timer > 0.0:
			# Grounded-style jump (floor or coyote)
			velocity.y = jump_velocity
			coyote_timer = 0.0
			jump_buffer_timer = 0.0
			air_jumps_left = max_air_jumps
			jumped.emit(air_jumps_left)
		elif air_jumps_left > 0:
			# Air jump
			air_jumps_left -= 1
			velocity.y = jump_velocity
			jump_buffer_timer = 0.0
			jumped.emit(air_jumps_left)

	# Horizontal movement
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()


func get_movement_state() -> StringName:
	if is_on_floor() and velocity.y <= 0.0:
		return &"grounded"
	if not is_on_floor() and velocity.y > 0.0:
		return &"jumping"
	if not is_on_floor() and velocity.y <= 0.0 and coyote_timer > 0.0:
		return &"coyote"
	return &"falling"
