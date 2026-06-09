class_name BTInverter
extends BTNode

@export var child: BTNode

func tick(blackboard: Dictionary) -> int:
	if child == null:
		return FAILURE
	var result = child.tick(blackboard)
	if result == SUCCESS:
		return FAILURE
	elif result == FAILURE:
		return SUCCESS
	else:
		return RUNNING
