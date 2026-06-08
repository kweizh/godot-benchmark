class_name AttackState
extends State

const MIN_DURATION := 0.3
const MAX_DURATION := 0.6

var _timer: float = 0.0


func enter(_prev_state: StringName) -> void:
	_timer = 0.0
	player.velocity.x = 0.0


func physics_update(delta: float) -> void:
	_timer += delta

	if _timer >= MIN_DURATION:
		# Between 0.3s and 0.6s, transition back to Idle
		# We transition at a random point in that window, or simply
		# at the minimum (0.3s) — the requirement says "between 0.3s
		# and 0.6s later". We'll use the minimum for deterministic
		# behavior, which satisfies "between 0.3s and 0.6s".
		state_machine.transition_to(&"Idle")
