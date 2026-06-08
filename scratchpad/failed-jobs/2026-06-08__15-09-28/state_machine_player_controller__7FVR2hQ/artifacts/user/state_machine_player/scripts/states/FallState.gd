class_name FallState
extends "res://scripts/states/State.gd"

## Player is falling (velocity.y > 0, not on floor).


func physics_update(delta: float) -> StringName:
	player.velocity.y += player.get_gravity().y * delta
	var dir := Input.get_axis(&"ui_left", &"ui_right")
	player.velocity.x = dir * 200.0
	player.move_and_slide()
	if player.is_on_floor():
		return &"Idle"
	return &""
