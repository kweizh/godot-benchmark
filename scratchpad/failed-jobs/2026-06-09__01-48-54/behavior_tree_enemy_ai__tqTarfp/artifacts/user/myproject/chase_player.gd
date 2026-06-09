class_name ChasePlayer
extends BTAction

func tick(blackboard: Dictionary) -> int:
    blackboard["action"] = "chase"
    if blackboard.get("distance_to_player", 0) <= blackboard.get("attack_range", 0):
        return SUCCESS
    blackboard["distance_to_player"] = blackboard.get("distance_to_player", 0) - blackboard.get("chase_speed", 0)
    return RUNNING
