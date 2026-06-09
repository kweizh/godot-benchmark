class_name BTSequence
extends BTNode

@export var children: Array[BTNode] = []

func tick(blackboard: Dictionary) -> int:
	for child in children:
		var status: int = child.tick(blackboard)
		if status == FAILURE:
			return FAILURE
		elif status == RUNNING:
			return RUNNING
	return SUCCESS
