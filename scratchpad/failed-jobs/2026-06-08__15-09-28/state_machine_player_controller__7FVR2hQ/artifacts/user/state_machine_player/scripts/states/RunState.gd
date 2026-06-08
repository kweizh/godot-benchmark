class_name RunState
extends "res://scripts/states/State.gd"

## Player is running horizontally on the ground.

const SPEED := 200.0


func physics_update(delta: float) -> StringName:
	if Input.is_action_just_pressed(&"attack"):
		return &"Attack"
	if Input.is_action_just_pressed(&"ui_accept") and player.is_on_floor():
		return &"Jump"
	var dir := Input.get_axis(&"ui_left", &"ui_right")
	if dir == 0.0:
		return &"Idle"
	player.velocity.x = dir * SPEED
	if not player.is_on_floor():
		player.velocity.y += player.get_gravity().y * delta
	player.move_and_slide()
	return &""
