class_name FallState
extends State

var speed := 300.0

func physics_update(delta: float) -> void:
	player.velocity.y += player.gravity * delta

	var direction := Input.get_axis("ui_left", "ui_right")
	player.velocity.x = direction * speed

	player.move_and_slide()

	if player.is_on_floor():
		if is_zero_approx(direction):
			state_machine.transition_to("Idle")
		else:
			state_machine.transition_to("Run")
