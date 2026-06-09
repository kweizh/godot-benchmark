extends BTAction
class_name IsHealthy

func tick(blackboard: Dictionary) -> int:
	if blackboard["health"] >= blackboard["healthy_threshold"]:
		return SUCCESS
	return FAILURE
