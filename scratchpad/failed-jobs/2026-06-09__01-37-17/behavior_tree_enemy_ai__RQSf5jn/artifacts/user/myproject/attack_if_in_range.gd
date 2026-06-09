class_name AttackIfInRange
extends BTAction

func tick(blackboard: Dictionary) -> int:
	var distance = blackboard.get("distance_to_player", 0.0)
	var attack_range = blackboard.get("attack_range", 0.0)
	
	if distance <= attack_range:
		blackboard["action"] = "attack"
		blackboard["last_attack_damage"] = blackboard.get("attack_damage", 0)
		return SUCCESS
	else:
		return FAILURE
