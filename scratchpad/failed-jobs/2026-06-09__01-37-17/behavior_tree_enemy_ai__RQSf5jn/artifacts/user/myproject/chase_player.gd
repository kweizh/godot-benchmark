class_name ChasePlayer
extends BTAction

func tick(blackboard: Dictionary) -> int:
	blackboard["action"] = "chase"
	var distance = blackboard.get("distance_to_player", 0.0)
	var attack_range = blackboard.get("attack_range", 0.0)
	
	if distance <= attack_range:
		return SUCCESS
	
	var chase_speed = blackboard.get("chase_speed", 0.0)
	blackboard["distance_to_player"] = distance - chase_speed
	return RUNNING
