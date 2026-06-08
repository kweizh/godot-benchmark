extends Node3D

# Runtime harness that verifies the platformer controller's jump behavior.
# Builds a 3D scene with a flat StaticBody3D floor, instances res://scenes/Player.tscn,
# and drives it through several scripted scenarios using Input.action_press/release.
# On success prints "HARNESS_OK" and exits with code 0; on any failure prints a
# diagnostic and exits with a non-zero code.

var jumped_args: Array = []
var player: CharacterBody3D = null
var floor_body: StaticBody3D = null

const FLOOR_PRESENT_Y := -0.5  # box half-height 0.5 → floor top at y = 0
const FLOOR_REMOVED_Y := -100.0
const SPAWN_POS := Vector3(0, 1.5, 0)


func _ready() -> void:
	# Build floor once and reuse across scenarios.
	floor_body = _build_floor()
	add_child(floor_body)

	# Run all scenarios sequentially.
	if not await _scenario_exports():
		return
	if not await _scenario_grounded():
		return
	if not await _scenario_coyote():
		return
	if not await _scenario_no_jump_available():
		return
	if not await _scenario_air_jump():
		return

	print("HARNESS_OK")
	get_tree().quit(0)


func _build_floor() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Floor"
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100.0, 1.0, 100.0)
	collider.shape = box
	body.add_child(collider)
	body.position = Vector3(0, FLOOR_PRESENT_Y, 0)
	return body


func _set_floor_y(y: float) -> void:
	floor_body.position = Vector3(0, y, 0)


func _fail(code: int, msg: String) -> bool:
	printerr("FAIL[%d]: %s" % [code, msg])
	get_tree().quit(code)
	return false


func _approx(a: float, b: float, tol: float = 0.01) -> bool:
	return abs(a - b) <= tol


func _on_jumped(remaining: int) -> void:
	jumped_args.append(remaining)


func _respawn_player(pos: Vector3) -> bool:
	if player != null and is_instance_valid(player):
		if player.jumped.is_connected(_on_jumped):
			player.jumped.disconnect(_on_jumped)
		player.queue_free()
		player = null
		await get_tree().process_frame
	var packed: PackedScene = load("res://scenes/Player.tscn")
	if packed == null:
		return _fail(2, "Could not load res://scenes/Player.tscn")
	var inst := packed.instantiate()
	if not (inst is CharacterBody3D):
		return _fail(3, "Player scene root is not a CharacterBody3D")
	player = inst
	add_child(player)
	player.position = pos
	player.velocity = Vector3.ZERO
	if not player.has_signal("jumped"):
		return _fail(4, "Player script does not declare signal `jumped`")
	player.jumped.connect(_on_jumped)
	jumped_args.clear()
	# Best-effort reset of internal state if exposed (won't error if hidden).
	if "air_jumps_left" in player:
		player.air_jumps_left = player.max_air_jumps
	if "coyote_timer" in player:
		player.coyote_timer = 0.0
	if "jump_buffer_timer" in player:
		player.jump_buffer_timer = 0.0
	# Release ui_accept just in case a previous scenario left it pressed.
	if Input.is_action_pressed("ui_accept"):
		Input.action_release("ui_accept")
	return true


func _wait_for_floor(max_frames: int = 240) -> bool:
	for i in range(max_frames):
		await get_tree().physics_frame
		if player.is_on_floor():
			return true
	return false


func _press_jump() -> void:
	# One press → one physics frame for the player to observe `just_pressed` and
	# fire the jump → release → one more physics frame for cleanup.
	Input.action_press("ui_accept")
	await get_tree().physics_frame
	Input.action_release("ui_accept")
	await get_tree().physics_frame


# ---------------------------------------------------------------------------
# Scenarios
# ---------------------------------------------------------------------------

func _scenario_exports() -> bool:
	if not await _respawn_player(SPAWN_POS):
		return false
	if not _approx(player.speed, 5.0):
		return _fail(10, "speed default expected 5.0, got %f" % player.speed)
	if not _approx(player.jump_velocity, 7.5):
		return _fail(11, "jump_velocity default expected 7.5, got %f" % player.jump_velocity)
	if not _approx(player.gravity, 25.0):
		return _fail(12, "gravity default expected 25.0, got %f" % player.gravity)
	if int(player.max_air_jumps) != 1:
		return _fail(13, "max_air_jumps default expected 1, got %d" % int(player.max_air_jumps))
	if not _approx(player.coyote_time, 0.15):
		return _fail(14, "coyote_time default expected 0.15, got %f" % player.coyote_time)
	if not _approx(player.jump_buffer_time, 0.15):
		return _fail(15, "jump_buffer_time default expected 0.15, got %f" % player.jump_buffer_time)
	return true


func _scenario_grounded() -> bool:
	_set_floor_y(FLOOR_PRESENT_Y)
	if not await _respawn_player(SPAWN_POS):
		return false
	if not await _wait_for_floor():
		return _fail(20, "Player did not land on floor within timeout (grounded scenario)")
	if not player.is_on_floor():
		return _fail(21, "Expected is_on_floor()==true after settling")
	var state := player.get_movement_state()
	if state != &"grounded":
		return _fail(22, "Expected get_movement_state()==&\"grounded\" on floor, got %s" % str(state))
	jumped_args.clear()
	await _press_jump()
	if not _approx(player.velocity.y, player.jump_velocity, 0.05):
		return _fail(23, "Grounded jump: velocity.y expected ~%f, got %f" % [player.jump_velocity, player.velocity.y])
	if int(player.air_jumps_left) != int(player.max_air_jumps):
		return _fail(24, "Grounded jump should not consume air jumps; air_jumps_left=%d max=%d" % [int(player.air_jumps_left), int(player.max_air_jumps)])
	if jumped_args.size() != 1:
		return _fail(25, "Expected exactly 1 `jumped` emission for grounded jump, got %d (%s)" % [jumped_args.size(), str(jumped_args)])
	if int(jumped_args[0]) != int(player.max_air_jumps):
		return _fail(26, "Grounded jump signal arg expected %d, got %s" % [int(player.max_air_jumps), str(jumped_args[0])])
	if player.get_movement_state() != &"jumping":
		return _fail(27, "Expected get_movement_state()==&\"jumping\" after grounded jump, got %s" % str(player.get_movement_state()))
	return true


func _scenario_coyote() -> bool:
	_set_floor_y(FLOOR_PRESENT_Y)
	if not await _respawn_player(SPAWN_POS):
		return false
	if not await _wait_for_floor():
		return _fail(30, "Player did not land for coyote scenario")
	# Move the floor far away, then let one physics frame elapse so the player
	# detects it has just left the floor (coyote_timer should now be active).
	_set_floor_y(FLOOR_REMOVED_Y)
	await get_tree().physics_frame
	if player.is_on_floor():
		return _fail(31, "Player should no longer be on floor after it was moved away")
	if player.get_movement_state() != &"coyote":
		return _fail(32, "Expected get_movement_state()==&\"coyote\" just after leaving floor, got %s" % str(player.get_movement_state()))
	jumped_args.clear()
	var air_before := int(player.air_jumps_left)
	await _press_jump()
	if not _approx(player.velocity.y, player.jump_velocity, 0.05):
		return _fail(33, "Coyote jump: velocity.y expected ~%f, got %f" % [player.jump_velocity, player.velocity.y])
	if int(player.air_jumps_left) != air_before:
		return _fail(34, "Coyote jump should NOT consume air jumps; before=%d after=%d" % [air_before, int(player.air_jumps_left)])
	if jumped_args.size() != 1 or int(jumped_args[0]) != air_before:
		return _fail(35, "Coyote jump signal expected one emission with arg %d, got %s" % [air_before, str(jumped_args)])
	if player.get_movement_state() != &"jumping":
		return _fail(36, "Expected jumping state after coyote jump, got %s" % str(player.get_movement_state()))
	return true


func _scenario_no_jump_available() -> bool:
	_set_floor_y(FLOOR_PRESENT_Y)
	if not await _respawn_player(SPAWN_POS):
		return false
	if not await _wait_for_floor():
		return _fail(40, "Player did not land for no-jump-available scenario")
	# Drop the floor so the player is genuinely in the air.
	_set_floor_y(FLOOR_REMOVED_Y)
	# Wait long enough for coyote to fully expire AND for velocity.y to clearly
	# become negative (so state should be "falling").
	var wait_frames := int(ceil((player.coyote_time + 0.5) * 60.0))
	for i in range(wait_frames):
		await get_tree().physics_frame
	if player.is_on_floor():
		return _fail(41, "Player should not be on floor after floor removal")
	if player.get_movement_state() != &"falling":
		return _fail(42, "Expected get_movement_state()==&\"falling\" after coyote expired, got %s" % str(player.get_movement_state()))
	# Consume the single allowed air jump.
	jumped_args.clear()
	await _press_jump()
	if int(player.air_jumps_left) != 0:
		return _fail(43, "Air jump should drop air_jumps_left to 0, got %d" % int(player.air_jumps_left))
	if jumped_args.size() != 1 or int(jumped_args[0]) != 0:
		return _fail(44, "Air jump signal expected one emission with arg 0, got %s" % str(jumped_args))
	# Let gravity bring the player back into a falling state with no jumps left.
	for i in range(int(ceil((player.coyote_time + 1.0) * 60.0))):
		await get_tree().physics_frame
		if player.velocity.y < -0.5:
			break
	if int(player.air_jumps_left) != 0:
		return _fail(45, "air_jumps_left must remain 0 while in air; got %d" % int(player.air_jumps_left))
	if player.get_movement_state() != &"falling":
		return _fail(46, "Expected falling state with no jumps left, got %s" % str(player.get_movement_state()))
	# Press jump again — should NOT produce a fresh jump impulse.
	jumped_args.clear()
	var v_before := player.velocity.y
	await _press_jump()
	var v_after := player.velocity.y
	# v_after should differ from v_before only by gravity over the two stepped
	# frames (≈ -2 * gravity / 60). Crucially, it must not be re-set to
	# jump_velocity. We assert it is clearly below jump_velocity.
	if _approx(v_after, player.jump_velocity, 0.5):
		return _fail(47, "Jump after exhaustion should NOT set velocity.y to jump_velocity (~%f); got %f" % [player.jump_velocity, v_after])
	# Expected drift from gravity only.
	var expected_drift := -player.gravity * (2.0 / 60.0)
	if not _approx(v_after - v_before, expected_drift, 0.2):
		return _fail(48, "velocity.y delta after exhausted jump press expected ≈ %f (gravity-only), got %f (v_before=%f v_after=%f)" % [expected_drift, v_after - v_before, v_before, v_after])
	if jumped_args.size() != 0:
		return _fail(49, "No `jumped` signal expected when out of jumps, got %s" % str(jumped_args))
	return true


func _scenario_air_jump() -> bool:
	_set_floor_y(FLOOR_PRESENT_Y)
	if not await _respawn_player(SPAWN_POS):
		return false
	if not await _wait_for_floor():
		return _fail(50, "Player did not land for air-jump scenario")
	# Grounded jump.
	jumped_args.clear()
	await _press_jump()
	if not _approx(player.velocity.y, player.jump_velocity, 0.05):
		return _fail(51, "Pre-air-jump grounded jump failed: velocity.y=%f" % player.velocity.y)
	# Step one more physics frame so the player is unambiguously in the air.
	await get_tree().physics_frame
	if player.is_on_floor():
		return _fail(52, "Player should be airborne after grounded jump")
	# Now perform the air jump.
	jumped_args.clear()
	await _press_jump()
	if not _approx(player.velocity.y, player.jump_velocity, 0.05):
		return _fail(53, "Air jump: velocity.y expected ~%f, got %f" % [player.jump_velocity, player.velocity.y])
	if int(player.air_jumps_left) != 0:
		return _fail(54, "Air jump should consume the air jump (left=0); got %d" % int(player.air_jumps_left))
	if jumped_args.size() != 1 or int(jumped_args[0]) != 0:
		return _fail(55, "Air jump signal expected one emission with arg 0, got %s" % str(jumped_args))
	return true
