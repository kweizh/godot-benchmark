class_name IsHealthy
extends BTAction

func tick(blackboard: Dictionary) -> int:
    if blackboard.get("health", 0) >= blackboard.get("healthy_threshold", 0):
        return SUCCESS
    return FAILURE
