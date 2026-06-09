class_name BTInverter
extends BTNode

var child: BTNode

func _init(p_child: BTNode = null):
    child = p_child

func tick(blackboard: Dictionary) -> int:
    var status = child.tick(blackboard)
    if status == SUCCESS:
        return FAILURE
    elif status == FAILURE:
        return SUCCESS
    return RUNNING
