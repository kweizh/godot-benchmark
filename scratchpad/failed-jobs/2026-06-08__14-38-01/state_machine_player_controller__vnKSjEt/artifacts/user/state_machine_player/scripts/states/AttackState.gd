class_name AttackState
extends State

var attack_time: float = 0.0
const ATTACK_DURATION: float = 0.4

func enter(_msg: Dictionary = {}) -> void:
	attack_time = 0.0
	player.velocity.x = 0.0

func physics_update(delta: float) -> void:
	attack_time += delta
	
	if not player.is_on_floor():
		player.velocity.y += player.gravity * delta
	else:
		player.velocity.y = 0.0
		
	player.move_and_slide()
	
	if attack_time >= ATTACK_DURATION:
		state_machine.transition_to("Idle")
		return
