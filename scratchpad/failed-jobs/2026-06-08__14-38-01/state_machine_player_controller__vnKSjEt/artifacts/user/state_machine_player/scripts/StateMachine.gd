class_name StateMachine
extends Node

signal state_changed(prev: StringName, next: StringName)

@export var initial_state: NodePath

var state: State

func _ready() -> void:
	# Wait for the owner to be ready so that we can safely reference it
	await owner.ready
	
	# Initialize all child states with references
	for child in get_children():
		if child is State:
			child.player = owner
			child.state_machine = self
			
	if initial_state:
		state = get_node(initial_state) as State
	else:
		# Fallback to the first child State
		for child in get_children():
			if child is State:
				state = child
				break
				
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

func transition_to(target_state_name: StringName, msg: Dictionary = {}) -> void:
	if not has_node(String(target_state_name)):
		# Transition requests to unknown names are ignored
		return
		
	var target_state = get_node(String(target_state_name))
	if not target_state is State:
		return
		
	var prev_name = StringName(state.name if state else "")
	if state:
		state.exit()
		
	state = target_state
	state.enter(msg)
	state_changed.emit(prev_name, StringName(target_state.name))
