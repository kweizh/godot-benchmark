class_name BTSequence
extends BTNode

@export var children: Array[BTNode] = []

func tick(blackboard: Dictionary) -> int:
	for child in children:
		if child == null:
			continue
		var result = child.tick(blackboard)
		if result == FAILURE:
			return FAILURE
		elif result == RUNNING:
			return RUNNING
		# If SUCCESS, continue to next child
	return SUCCESS
