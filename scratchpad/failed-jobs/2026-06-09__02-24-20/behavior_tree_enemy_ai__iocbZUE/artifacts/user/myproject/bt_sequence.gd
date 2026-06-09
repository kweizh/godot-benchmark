extends BTNode
class_name BTSequence

var children: Array[BTNode] = []

func tick(blackboard: Dictionary) -> int:
	for child in children:
		var status: int = child.tick(blackboard)
		if status == FAILURE:
			return FAILURE
		if status == RUNNING:
			return RUNNING
	return SUCCESS
