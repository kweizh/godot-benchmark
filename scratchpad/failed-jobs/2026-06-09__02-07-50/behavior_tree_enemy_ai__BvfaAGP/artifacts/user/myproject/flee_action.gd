class_name FleeAction
extends BTAction

func tick(blackboard: Dictionary) -> int:
	blackboard["action"] = "flee"
	return SUCCESS
