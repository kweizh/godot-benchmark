class_name AttackState
extends "res://scripts/states/State.gd"

## Player performs an attack; returns to Idle after ~0.4 s.

const ATTACK_DURATION := 0.4

var _timer := 0.0


func enter() -> void:
	_timer = 0.0
	player.velocity.x = 0.0


func physics_update(delta: float) -> StringName:
	_timer += delta
	if not player.is_on_floor():
		player.velocity.y += player.get_gravity().y * delta
	player.move_and_slide()
	if _timer >= ATTACK_DURATION:
		return &"Idle"
	return &""
