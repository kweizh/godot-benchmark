class_name StateMachine
extends Node

## Finite state machine that manages player states.
## Emits state_changed whenever a transition occurs.

signal state_changed(prev: StringName, next: StringName)

## The name of the initial state to enter on _ready.
@export var initial_state: StringName = &"Idle"

var current_state: Node = null
var _states: Dictionary = {}


func _ready() -> void:
	# Build state registry from child nodes.
	for child in get_children():
		_states[StringName(child.name)] = child
		child.set("player", get_parent() as CharacterBody2D)
		child.set("state_machine", self)

	# Enter the initial state without emitting a signal (no previous state).
	if _states.has(initial_state):
		current_state = _states[initial_state]
		if current_state.has_method("enter"):
			current_state.enter()
	else:
		push_warning("StateMachine: initial_state '%s' not found." % initial_state)


func _physics_process(delta: float) -> void:
	if current_state == null:
		return
	if not current_state.has_method("physics_update"):
		return
	var next: StringName = current_state.physics_update(delta)
	if next != &"" and next != StringName(current_state.name):
		transition_to(next)


func _process(delta: float) -> void:
	if current_state == null:
		return
	if current_state.has_method("update"):
		current_state.update(delta)


## Request a transition to the state identified by `state_name`.
## Transitions to unknown names are silently ignored.
func transition_to(state_name: StringName) -> void:
	if not _states.has(state_name):
		return
	if current_state != null and StringName(current_state.name) == state_name:
		return

	var prev_name: StringName = &""
	if current_state != null:
		prev_name = StringName(current_state.name)
		if current_state.has_method("exit"):
			current_state.exit()

	current_state = _states[state_name]
	if current_state.has_method("enter"):
		current_state.enter()
	state_changed.emit(prev_name, state_name)
