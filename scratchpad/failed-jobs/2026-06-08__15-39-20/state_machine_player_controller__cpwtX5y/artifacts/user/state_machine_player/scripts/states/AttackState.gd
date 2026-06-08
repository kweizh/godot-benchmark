class_name AttackState
extends State

var timer := 0.0
var attack_duration := 0.4

func enter(_msg := {}) -> void:
	timer = 0.0
	player.velocity.x = 0

func physics_update(delta: float) -> void:
	timer += delta
	if not player.is_on_floor():
		player.velocity.y += player.gravity * delta
	player.move_and_slide()

	if timer >= attack_duration:
		state_machine.transition_to("Idle")
