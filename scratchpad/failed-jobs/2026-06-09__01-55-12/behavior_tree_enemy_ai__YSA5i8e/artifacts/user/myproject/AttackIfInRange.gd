class_name AttackIfInRange
extends BTAction

func tick(blackboard: Dictionary) -> int:
	if blackboard["distance_to_player"] <= blackboard["attack_range"]:
		blackboard["action"] = "attack"
		blackboard["last_attack_damage"] = blackboard["attack_damage"]
		return SUCCESS
	return FAILURE
