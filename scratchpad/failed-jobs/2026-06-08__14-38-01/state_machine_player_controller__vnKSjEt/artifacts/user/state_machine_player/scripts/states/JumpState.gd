class_name JumpState
extends State

func enter(_msg: Dictionary = {}) -> void:
	player.velocity.y = player.jump_velocity

func physics_update(delta: float) -> void:
	player.velocity.y += player.gravity * delta
	
	var input_direction := Input.get_axis("ui_left", "ui_right")
	player.velocity.x = input_direction * player.speed
	player.move_and_slide()
	
	if player.velocity.y > 0.0:
		state_machine.transition_to("Fall")
		return
