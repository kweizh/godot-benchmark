class_name JumpState
extends State

var jump_velocity := -400.0
var speed := 300.0

func enter(_msg := {}) -> void:
	player.velocity.y = jump_velocity

func physics_update(delta: float) -> void:
	player.velocity.y += player.gravity * delta

	var direction := Input.get_axis("ui_left", "ui_right")
	player.velocity.x = direction * speed

	player.move_and_slide()

	if player.velocity.y > 0:
		state_machine.transition_to("Fall")
