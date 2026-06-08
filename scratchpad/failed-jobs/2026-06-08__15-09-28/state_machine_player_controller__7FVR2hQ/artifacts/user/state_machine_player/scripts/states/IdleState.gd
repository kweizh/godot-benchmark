class_name IdleState
extends "res://scripts/states/State.gd"

## Player is standing still on the ground.


func enter() -> void:
	player.velocity.x = 0.0


func physics_update(_delta: float) -> StringName:
	if Input.is_action_just_pressed(&"attack"):
		return &"Attack"
	if Input.is_action_just_pressed(&"ui_accept") and player.is_on_floor():
		return &"Jump"
	var dir := Input.get_axis(&"ui_left", &"ui_right")
	if dir != 0.0:
		return &"Run"
	return &""
