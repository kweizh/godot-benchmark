class_name JumpState
extends State

const JUMP_VELOCITY := -400.0


func enter(_prev_state: String) -> void:
	player.velocity.y = JUMP_VELOCITY


func physics_update(_delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0.0:
		player.velocity.x = direction * RunState.RUN_SPEED

	if player.velocity.y > 0.0:
		state_machine.transition_to(&"Fall")
