class_name Player
extends CharacterBody2D

## Top-level player node.
## Delegates physics and input to the active State via the StateMachine.

@onready var _state_machine: Node = $StateMachine


func _ready() -> void:
	_state_machine.state_changed.connect(_on_state_changed)


func _on_state_changed(prev: StringName, next: StringName) -> void:
	print("[Player] state: %s -> %s" % [prev, next])
