extends BTNode
class_name BTInverter

var child: BTNode = null

func tick(blackboard: Dictionary) -> int:
	if child == null:
		return FAILURE
	var status: int = child.tick(blackboard)
	if status == SUCCESS:
		return FAILURE
	if status == FAILURE:
		return SUCCESS
	return RUNNING
