class_name RunState
extends State

var speed := 300.0

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
	if is_zero_approx(direction):
		state_machine.transition_to("Idle")
		return

	player.velocity.x = direction * speed
	player.move_and_slide()
