class_name IdleState
extends State

func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity.y += player.gravity * delta
	else:
		player.velocity.y = 0.0
		
	player.velocity.x = 0.0
	player.move_and_slide()
	
	if not player.is_on_floor():
		state_machine.transition_to("Fall")
		return
		
	if Input.is_action_just_pressed("attack"):
		state_machine.transition_to("Attack")
		return
		
	if Input.is_action_just_pressed("ui_accept"):
		state_machine.transition_to("Jump")
		return
		
	var input_direction := Input.get_axis("ui_left", "ui_right")
	if input_direction != 0.0:
		state_machine.transition_to("Run")
		return
