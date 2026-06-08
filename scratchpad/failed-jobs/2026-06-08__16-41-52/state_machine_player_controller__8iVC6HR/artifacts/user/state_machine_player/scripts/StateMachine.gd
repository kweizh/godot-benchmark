class_name StateMachine
extends Node

## Finite state machine that manages transitions between State nodes.
## Emits [signal state_changed] on every valid transition.

signal state_changed(prev: StringName, next: StringName)

var _current_state: Node = null
var _states: Dictionary = {}  # StringName -> Node


func _ready() -> void:
	# Discover child State nodes by their node names
	for child in get_children():
		if child.has_method("enter") and child.has_method("exit"):
			_states[child.name] = child

	# Enter the first state found (default starting state)
	if _states.size() > 0:
		var first_key: StringName = _states.keys()[0]
		_current_state = _states[first_key]
		_current_state.enter(&"")


func _physics_process(delta: float) -> void:
	if _current_state:
		_current_state.physics_update(delta)


func _process(delta: float) -> void:
	if _current_state:
		_current_state.process_update(delta)


## Request a transition to [param target]. If the target state does not
## exist, the request is silently ignored.
func transition_to(target: StringName) -> void:
	if not _states.has(target):
		return

	var prev_state: Node = _current_state
	var next_state: Node = _states[target]

	if prev_state:
		prev_state.exit(target)

	_current_state = next_state
	state_changed.emit(prev_state.name if prev_state else &"", target)
	next_state.enter(prev_state.name if prev_state else &"")
