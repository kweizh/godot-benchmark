class_name BTInverter
extends BTNode

var child: BTNode = null

func tick(blackboard: Dictionary) -> int:
	var result: int = child.tick(blackboard)
	if result == SUCCESS:
		return FAILURE
	elif result == FAILURE:
		return SUCCESS
	return RUNNING
