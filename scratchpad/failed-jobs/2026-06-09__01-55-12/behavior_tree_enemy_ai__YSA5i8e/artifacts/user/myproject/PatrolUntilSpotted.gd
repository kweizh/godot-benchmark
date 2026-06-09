class_name PatrolUntilSpotted
extends BTAction

func tick(blackboard: Dictionary) -> int:
	if blackboard["player_spotted"]:
		return SUCCESS
	blackboard["action"] = "patrol"
	blackboard["patrol_steps"] = blackboard["patrol_steps"] + 1
	return RUNNING
