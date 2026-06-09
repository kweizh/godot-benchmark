class_name BTSelector
extends BTNode

@export var children: Array[BTNode] = []

func tick(blackboard: Dictionary) -> int:
	for child in children:
		if child == null:
			continue
		var result = child.tick(blackboard)
		if result == SUCCESS:
			return SUCCESS
		elif result == RUNNING:
			return RUNNING
		# If FAILURE, continue to next child
	return FAILURE
