extends Node2D


var _state_changes: Array = []


func _ready() -> void:
	# Load the player scene authored by the executor.
	var player_packed: PackedScene = load("res://scenes/Player.tscn")
	if player_packed == null:
		printerr("FAIL: could not load res://scenes/Player.tscn")
		get_tree().quit(2)
		return

	var player: Node = player_packed.instantiate()
	if player == null:
		printerr("FAIL: could not instantiate res://scenes/Player.tscn")
		get_tree().quit(3)
		return

	# Place the player above a mock floor.
	if player is Node2D:
		(player as Node2D).position = Vector2(0, 0)
	add_child(player)

	# Ensure the player has at least one CollisionShape2D so is_on_floor() works.
	# If the authored Player.tscn already has one this is harmless.
	var has_player_collider := false
	for c in player.get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D:
			has_player_collider = true
			break
	if not has_player_collider:
		var cs := CollisionShape2D.new()
		var pshape := RectangleShape2D.new()
		pshape.size = Vector2(16, 16)
		cs.shape = pshape
		player.add_child(cs)

	# Build a static floor directly below the player.
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(2000, 40)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(0, 32)
	add_child(floor_body)

	# Locate the state machine and connect to its state_changed signal.
	var sm: Node = player.get_node_or_null("StateMachine")
	if sm == null:
		printerr("FAIL: Player has no StateMachine child node")
		get_tree().quit(4)
		return
	if not sm.has_signal("state_changed"):
		printerr("FAIL: StateMachine has no `state_changed` signal")
		get_tree().quit(5)
		return
	sm.connect("state_changed", Callable(self, "_on_state_changed"))

	# Step a few physics frames so the player settles on the floor.
	for i in range(10):
		await get_tree().physics_frame

	if not _state_is(sm, "Idle"):
		printerr("FAIL: initial state expected Idle, got '%s'" % _state_name(sm))
		get_tree().quit(6)
		return

	# Idle -> Run on horizontal input.
	_state_changes.clear()
	Input.action_press("ui_right")
	for i in range(4):
		await get_tree().physics_frame
	if not _state_is(sm, "Run"):
		printerr("FAIL: expected Run after pressing ui_right, got '%s'" % _state_name(sm))
		get_tree().quit(7)
		return
	var idle_to_run_seen := false
	for change in _state_changes:
		if String(change[0]) == "Idle" and String(change[1]) == "Run":
			idle_to_run_seen = true
			break
	if not idle_to_run_seen:
		printerr("FAIL: state_changed signal did not fire with (Idle, Run); saw: %s" % str(_state_changes))
		get_tree().quit(8)
		return

	# Run -> Idle on release.
	Input.action_release("ui_right")
	for i in range(4):
		await get_tree().physics_frame
	if not _state_is(sm, "Idle"):
		printerr("FAIL: expected Idle after releasing ui_right, got '%s'" % _state_name(sm))
		get_tree().quit(9)
		return

	# Idle -> Jump on ui_accept.
	Input.action_press("ui_accept")
	for i in range(3):
		await get_tree().physics_frame
	if not _state_is(sm, "Jump"):
		printerr("FAIL: expected Jump after pressing ui_accept on floor, got '%s'" % _state_name(sm))
		get_tree().quit(10)
		return
	Input.action_release("ui_accept")

	# Jump -> Fall once velocity.y > 0.
	if "velocity" in player:
		player.velocity.y = 50.0
	for i in range(4):
		await get_tree().physics_frame
	if not _state_is(sm, "Fall"):
		printerr("FAIL: expected Fall after velocity.y > 0, got '%s'" % _state_name(sm))
		get_tree().quit(11)
		return

	# Fall -> Idle once back on floor.
	for i in range(120):
		await get_tree().physics_frame
		if _state_is(sm, "Idle"):
			break
	if not _state_is(sm, "Idle"):
		printerr("FAIL: expected Idle after landing on floor, got '%s'" % _state_name(sm))
		get_tree().quit(12)
		return

	print("STATES_OK")
	get_tree().quit(0)


func _state_name(sm: Node) -> String:
	var cs = sm.get("current_state")
	if cs == null:
		return "<null>"
	return String((cs as Node).name)


func _state_is(sm: Node, expected: String) -> bool:
	return _state_name(sm) == expected


func _on_state_changed(prev, next) -> void:
	_state_changes.append([prev, next])
