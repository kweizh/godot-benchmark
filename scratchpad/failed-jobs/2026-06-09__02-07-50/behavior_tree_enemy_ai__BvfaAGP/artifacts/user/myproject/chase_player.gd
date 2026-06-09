class_name ChasePlayer
extends BTAction

func tick(blackboard: Dictionary) -> int:
	blackboard["action"] = "chase"
	if blackboard["distance_to_player"] <= blackboard["attack_range"]:
		return SUCCESS
	blackboard["distance_to_player"] = blackboard["distance_to_player"] - blackboard["chase_speed"]
	return RUNNING
