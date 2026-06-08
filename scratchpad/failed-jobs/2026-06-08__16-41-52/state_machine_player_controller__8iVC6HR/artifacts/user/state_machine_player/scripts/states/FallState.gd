class_name FallState
extends State


func physics_update(_delta: float) -> void:
	# Horizontal movement while in air
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0.0:
		player.velocity.x = direction * RunState.RUN_SPEED

	# Landed -> Idle
	if player.is_on_floor():
		state_machine.transition_to(&"Idle")
