extends BTNode
class_name BTSelector

var children: Array[BTNode] = []

func tick(blackboard: Dictionary) -> int:
	for child in children:
		var status: int = child.tick(blackboard)
		if status == SUCCESS:
			return SUCCESS
		if status == RUNNING:
			return RUNNING
	return FAILURE
