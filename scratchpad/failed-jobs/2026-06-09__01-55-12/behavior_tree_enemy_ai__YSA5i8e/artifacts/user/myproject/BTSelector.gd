class_name BTSelector
extends BTNode

var children: Array[BTNode] = []

func tick(blackboard: Dictionary) -> int:
	for child in children:
		var result: int = child.tick(blackboard)
		if result == SUCCESS:
			return SUCCESS
		elif result == RUNNING:
			return RUNNING
		# FAILURE => continue to next child
	return FAILURE
