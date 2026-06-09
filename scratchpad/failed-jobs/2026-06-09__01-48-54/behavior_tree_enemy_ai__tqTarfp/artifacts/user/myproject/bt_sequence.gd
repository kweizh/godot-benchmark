class_name BTSequence
extends BTNode

var children: Array[BTNode] = []

func _init(p_children: Array[BTNode] = []):
    children = p_children

func tick(blackboard: Dictionary) -> int:
    for child in children:
        var status = child.tick(blackboard)
        if status == FAILURE:
            return FAILURE
        elif status == RUNNING:
            return RUNNING
    return SUCCESS
