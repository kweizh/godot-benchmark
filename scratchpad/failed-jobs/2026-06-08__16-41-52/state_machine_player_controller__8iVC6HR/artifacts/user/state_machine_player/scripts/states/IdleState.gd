class_name IdleState
extends State


func physics_update(_delta: float) -> void:
	if not player.is_on_floor():
		return

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0.0:
		state_machine.transition_to(&"Run")
		return

	if Input.is_action_just_pressed("attack"):
		state_machine.transition_to(&"Attack")
		return


func enter(_prev_state: String) -> void:
	player.velocity.x = 0.0
