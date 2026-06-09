class_name AttackIfInRange
extends BTAction

func tick(blackboard: Dictionary) -> int:
    if blackboard.get("distance_to_player", 0) <= blackboard.get("attack_range", 0):
        blackboard["action"] = "attack"
        blackboard["last_attack_damage"] = blackboard.get("attack_damage", 0)
        return SUCCESS
    return FAILURE
