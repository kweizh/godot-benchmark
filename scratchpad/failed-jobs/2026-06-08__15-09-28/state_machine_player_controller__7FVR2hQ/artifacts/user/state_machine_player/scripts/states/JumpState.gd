class_name JumpState
extends "res://scripts/states/State.gd"

## Player has just jumped; moving upward (velocity.y <= 0).

const JUMP_VELOCITY := -400.0


func enter() -> void:
	player.velocity.y = JUMP_VELOCITY


func physics_update(delta: float) -> StringName:
	player.velocity.y += player.get_gravity().y * delta
	var dir := Input.get_axis(&"ui_left", &"ui_right")
	player.velocity.x = dir * 200.0
	player.move_and_slide()
	if player.velocity.y > 0.0:
		return &"Fall"
	return &""
