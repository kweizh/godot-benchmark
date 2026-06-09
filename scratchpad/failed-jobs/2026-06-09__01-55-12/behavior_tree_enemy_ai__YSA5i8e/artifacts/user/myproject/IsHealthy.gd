class_name IsHealthy
extends BTAction

func tick(blackboard: Dictionary) -> int:
	if blackboard["health"] >= blackboard["healthy_threshold"]:
		return SUCCESS
	return FAILURE
