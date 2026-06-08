extends CharacterBody3D

signal jumped(remaining_air_jumps: int)

@export var speed: float = 5.0
@export var jump_velocity: float = 7.5
@export var gravity: float = 25.0
@export var max_air_jumps: int = 1
@export var coyote_time: float = 0.15
@export var jump_buffer_time: float = 0.15

var air_jumps_left: int = 0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0


func _physics_process(delta: float) -> void:
	# Apply gravity when not on floor
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Horizontal movement from input
	var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction: Vector3 = Vector3(input_dir.x, 0.0, input_dir.y)
	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	# Coyote timer: when leaving the floor, start the countdown
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)

	# Jump buffer: start on jump press
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)

	# On landing, reset air jumps
	if is_on_floor():
		air_jumps_left = max_air_jumps

	# Determine if a jump should fire
	var should_jump: bool = false
	var is_grounded_jump: bool = false

	if jump_buffer_timer > 0.0:
		if is_on_floor():
			should_jump = true
			is_grounded_jump = true
		elif coyote_timer > 0.0:
			should_jump = true
			is_grounded_jump = true
		elif air_jumps_left > 0:
			should_jump = true
			is_grounded_jump = false

	if should_jump:
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0

		if is_grounded_jump:
			coyote_timer = 0.0
		else:
			air_jumps_left -= 1

		jumped.emit(air_jumps_left)

	move_and_slide()


func get_movement_state() -> StringName:
	if is_on_floor() and velocity.y <= 0.0:
		return &"grounded"
	if not is_on_floor() and velocity.y > 0.0:
		return &"jumping"
	if not is_on_floor() and velocity.y <= 0.0 and coyote_timer <= 0.0:
		return &"falling"
	if not is_on_floor() and coyote_timer > 0.0:
		return &"coyote"
	return &"grounded"
