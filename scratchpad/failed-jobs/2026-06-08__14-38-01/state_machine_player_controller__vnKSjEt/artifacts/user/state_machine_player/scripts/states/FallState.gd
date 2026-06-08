class_name FallState
extends State

func physics_update(delta: float) -> void:
	player.velocity.y += player.gravity * delta
	
	var input_direction := Input.get_axis("ui_left", "ui_right")
	player.velocity.x = input_direction * player.speed
	player.move_and_slide()
	
	if player.is_on_floor():
		state_machine.transition_to("Idle")
		return
