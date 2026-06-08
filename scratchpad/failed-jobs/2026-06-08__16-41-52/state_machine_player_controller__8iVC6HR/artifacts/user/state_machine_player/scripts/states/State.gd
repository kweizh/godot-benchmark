class_name State
extends Node

var player: CharacterBody2D
var state_machine: Node


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	state_machine = get_parent()


func enter(_prev_state: String) -> void:
	pass


func exit(_next_state: String) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func process_update(_delta: float) -> void:
	pass
