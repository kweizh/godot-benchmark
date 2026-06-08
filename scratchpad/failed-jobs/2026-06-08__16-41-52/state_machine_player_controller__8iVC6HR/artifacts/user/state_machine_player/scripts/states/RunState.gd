class_name RunState
extends State

const RUN_SPEED := 300.0


func physics_update(_delta: float) -> void:
	if not player.is_on_floor():
		return

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction == 0.0:
		state_machine.transition_to(&"Idle")
		return

	player.velocity.x = direction * RUN_SPEED

	if Input.is_action_just_pressed("ui_accept"):
		state_machine.transition_to(&"Jump")
		return

	if Input.is_action_just_pressed("attack"):
		state_machine.transition_to(&"Attack")
		return
