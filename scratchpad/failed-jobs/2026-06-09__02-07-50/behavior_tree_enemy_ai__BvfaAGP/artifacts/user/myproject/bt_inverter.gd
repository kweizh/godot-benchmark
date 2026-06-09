class_name BTInverter
extends BTNode

@export var child: BTNode = null

func tick(blackboard: Dictionary) -> int:
	var status: int = child.tick(blackboard)
	if status == SUCCESS:
		return FAILURE
	elif status == FAILURE:
		return SUCCESS
	else:
		return RUNNING
