class_name State
extends Node

## Base class for all player states.

var player: CharacterBody2D
var state_machine: Node


func enter() -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> StringName:
	return &""


func update(_delta: float) -> void:
	pass
