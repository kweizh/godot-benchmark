class_name BTSequence
extends BTNode

var children: Array[BTNode] = []

func tick(blackboard: Dictionary) -> int:
	for child in children:
		var result: int = child.tick(blackboard)
		if result == FAILURE:
			return FAILURE
		elif result == RUNNING:
			return RUNNING
		# SUCCESS => continue to next child
	return SUCCESS
