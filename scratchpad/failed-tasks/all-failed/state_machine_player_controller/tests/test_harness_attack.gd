extends Node2D


func _ready() -> void:
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
	if player is Node2D:
		(player as Node2D).position = Vector2(0, 0)
	add_child(player)

	# Ensure a collider on the player so floor detection works.
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

	# Mock floor under the player.
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(2000, 40)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(0, 32)
	add_child(floor_body)

	var sm: Node = player.get_node_or_null("StateMachine")
	if sm == null:
		printerr("FAIL: Player has no StateMachine child node")
		get_tree().quit(4)
		return

	# Settle on the floor.
	for i in range(10):
		await get_tree().physics_frame

	if _state_name(sm) != "Idle":
		printerr("FAIL: initial state expected Idle, got '%s'" % _state_name(sm))
		get_tree().quit(5)
		return

	# Trigger attack via the `attack` action.
	Input.action_press("attack")
	for i in range(3):
		await get_tree().physics_frame
	Input.action_release("attack")
	if _state_name(sm) != "Attack":
		printerr("FAIL: expected Attack after pressing attack action, got '%s'" % _state_name(sm))
		get_tree().quit(6)
		return

	# Attack should auto-return to Idle within 0.4 s.
	await get_tree().create_timer(0.4).timeout
	await get_tree().physics_frame

	if _state_name(sm) != "Idle":
		printerr("FAIL: expected Idle 0.4s after Attack, got '%s'" % _state_name(sm))
		get_tree().quit(7)
		return

	print("ATTACK_OK")
	get_tree().quit(0)


func _state_name(sm: Node) -> String:
	var cs = sm.get("current_state")
	if cs == null:
		return "<null>"
	return String((cs as Node).name)
