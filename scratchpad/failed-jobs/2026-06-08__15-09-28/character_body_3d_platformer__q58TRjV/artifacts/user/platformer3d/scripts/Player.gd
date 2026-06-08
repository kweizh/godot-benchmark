extends CharacterBody3D

## Emitted on every successful jump. remaining_air_jumps reflects the value
## AFTER the jump (so 0 means this was the last air jump).
signal jumped(remaining_air_jumps: int)

@export var speed: float = 5.0
@export var jump_velocity: float = 7.5
@export var gravity: float = 25.0
@export var max_air_jumps: int = 1
@export var coyote_time: float = 0.15
@export var jump_buffer_time: float = 0.15

# Runtime state
var air_jumps_left: int = 0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

# Tracks whether the player was on the floor last frame to detect leaving it.
var _was_on_floor: bool = false


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()

	# ── Coyote timer ────────────────────────────────────────────────────────
	if on_floor:
		coyote_timer = coyote_time   # keep refreshed while grounded
	elif _was_on_floor:
		# Just left the floor this frame – start counting down
		coyote_timer = coyote_time
		coyote_timer -= delta
	else:
		coyote_timer -= delta
		if coyote_timer < 0.0:
			coyote_timer = 0.0

	# ── Landing reset ────────────────────────────────────────────────────────
	if on_floor and not _was_on_floor:
		air_jumps_left = max_air_jumps

	# Also reset on floor each frame so values are consistent at rest.
	if on_floor:
		air_jumps_left = max_air_jumps

	# ── Jump buffer ──────────────────────────────────────────────────────────
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = jump_buffer_time

	if jump_buffer_timer > 0.0:
		jump_buffer_timer -= delta
		if jump_buffer_timer < 0.0:
			jump_buffer_timer = 0.0

	# ── Jump execution ───────────────────────────────────────────────────────
	if jump_buffer_timer > 0.0:
		var can_jump_grounded := on_floor or coyote_timer > 0.0
		var can_jump_air := air_jumps_left > 0

		if can_jump_grounded or can_jump_air:
			# Consume the buffer
			jump_buffer_timer = 0.0

			if can_jump_grounded:
				# Grounded / coyote jump: exhaust coyote window, no air jump used
				coyote_timer = 0.0
			else:
				# Air jump
				air_jumps_left -= 1

			velocity.y = jump_velocity
			emit_signal("jumped", air_jumps_left)

	# ── Gravity ──────────────────────────────────────────────────────────────
	if not on_floor:
		velocity.y -= gravity * delta

	# ── Horizontal movement ───────────────────────────────────────────────────
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity.x = input_dir.x * speed
	velocity.z = input_dir.y * speed

	move_and_slide()

	_was_on_floor = on_floor


## Returns the current movement state as a StringName.
func get_movement_state() -> StringName:
	if is_on_floor() and velocity.y <= 0.0:
		return &"grounded"
	if not is_on_floor() and velocity.y > 0.0:
		return &"jumping"
	if not is_on_floor() and coyote_timer > 0.0:
		return &"coyote"
	return &"falling"
