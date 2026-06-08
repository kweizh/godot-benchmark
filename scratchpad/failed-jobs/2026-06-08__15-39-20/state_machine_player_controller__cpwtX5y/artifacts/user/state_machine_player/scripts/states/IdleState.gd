class_name IdleState
extends State

func physics_update(_delta: float) -> void:
	if not player.is_on_floor():
		state_machine.transition_to("Fall")
		return

	if Input.is_action_just_pressed("ui_accept"):
		state_machine.transition_to("Jump")
		return

	if Input.is_action_just_pressed("attack"):
		state_machine.transition_to("Attack")
		return

	var direction := Input.get_axis("ui_left", "ui_right")
	if not is_zero_approx(direction):
		state_machine.transition_to("Run")
		return

	player.velocity.x = move_toward(player.velocity.x, 0, 1000 * _delta)
	player.move_and_slide()
