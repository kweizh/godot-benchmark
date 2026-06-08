extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_velocity: float = 7.5
@export var gravity: float = 25.0
@export var max_air_jumps: int = 1
@export var coyote_time: float = 0.15
@export var jump_buffer_time: float = 0.15

signal jumped(remaining_air_jumps: int)

var air_jumps_left: int
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

func _ready() -> void:
	air_jumps_left = max_air_jumps

func _physics_process(delta: float) -> void:
	# 1. Update ground/coyote state and apply gravity
	if is_on_floor():
		air_jumps_left = max_air_jumps
		coyote_timer = coyote_time
	else:
		coyote_timer = max(0.0, coyote_timer - delta)
		velocity.y -= gravity * delta

	# 2. Update jump buffer timer
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = jump_buffer_time
	elif jump_buffer_timer > 0.0:
		jump_buffer_timer = max(0.0, jump_buffer_timer - delta)

	# 3. Check and execute jump
	if jump_buffer_timer > 0.0:
		if is_on_floor() or coyote_timer > 0.0:
			# Grounded-style jump (consumes coyote timer, does not consume an air jump)
			velocity.y = jump_velocity
			coyote_timer = 0.0
			jump_buffer_timer = 0.0
			jumped.emit(air_jumps_left)
		elif air_jumps_left > 0:
			# Air-style jump (consumes an air jump)
			air_jumps_left -= 1
			velocity.y = jump_velocity
			coyote_timer = 0.0
			jump_buffer_timer = 0.0
			jumped.emit(air_jumps_left)

	# 4. Horizontal movement input
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity.x = input_dir.x * speed
	velocity.z = input_dir.y * speed

	# 5. Move the character
	move_and_slide()

func get_movement_state() -> StringName:
	if is_on_floor():
		return &"grounded"
	elif velocity.y > 0:
		return &"jumping"
	elif coyote_timer > 0:
		return &"coyote"
	else:
		return &"falling"
