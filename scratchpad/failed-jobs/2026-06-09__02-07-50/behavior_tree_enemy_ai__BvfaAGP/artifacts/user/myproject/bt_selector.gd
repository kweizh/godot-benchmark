class_name BTSelector
extends BTNode

@export var children: Array[BTNode] = []

func tick(blackboard: Dictionary) -> int:
	for child in children:
		var status: int = child.tick(blackboard)
		if status == SUCCESS:
			return SUCCESS
		elif status == RUNNING:
			return RUNNING
	return FAILURE
