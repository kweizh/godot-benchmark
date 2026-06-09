extends BTAction
class_name FleeAction

func tick(blackboard: Dictionary) -> int:
	blackboard["action"] = "flee"
	return SUCCESS
