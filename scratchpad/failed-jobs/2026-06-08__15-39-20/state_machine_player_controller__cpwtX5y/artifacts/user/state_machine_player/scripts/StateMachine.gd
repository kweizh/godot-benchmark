class_name StateMachine
extends Node

signal state_changed(prev: StringName, next: StringName)

@export var initial_state: NodePath
@onready var state: State = get_node(initial_state) if initial_state else (get_child(0) if get_child_count() > 0 else null)

var states: Dictionary = {}

func _ready() -> void:
	await owner.ready
	for child in get_children():
		if child is State:
			states[child.name] = child
			child.state_machine = self
			child.player = owner
	if state:
		state.enter()

func _unhandled_input(event: InputEvent) -> void:
	if state:
		state.handle_input(event)

func _process(delta: float) -> void:
	if state:
		state.update(delta)

func _physics_process(delta: float) -> void:
	if state:
		state.physics_update(delta)

func transition_to(target_state_name: String, msg: Dictionary = {}) -> void:
	if not states.has(target_state_name):
		return
	
	var prev_name = state.name if state else ""
	if state:
		state.exit()
	
	state = states[target_state_name]
	state.enter(msg)
	emit_signal("state_changed", StringName(prev_name), StringName(target_state_name))
