class_name PatrolUntilSpotted
extends BTAction

func tick(blackboard: Dictionary) -> int:
    if blackboard.get("player_spotted", false):
        return SUCCESS
    blackboard["action"] = "patrol"
    blackboard["patrol_steps"] = blackboard.get("patrol_steps", 0) + 1
    return RUNNING
