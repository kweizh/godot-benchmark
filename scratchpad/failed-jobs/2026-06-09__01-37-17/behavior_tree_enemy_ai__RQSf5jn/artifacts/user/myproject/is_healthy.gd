class_name IsHealthy
extends BTAction

func tick(blackboard: Dictionary) -> int:
	var health = blackboard.get("health", 0)
	var threshold = blackboard.get("healthy_threshold", 0)
	if health >= threshold:
		return SUCCESS
	else:
		return FAILURE
