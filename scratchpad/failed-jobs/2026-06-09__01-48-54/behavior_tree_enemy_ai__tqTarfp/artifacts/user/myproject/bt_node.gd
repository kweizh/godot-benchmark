class_name BTNode
extends Resource

const SUCCESS: int = 0
const FAILURE: int = 1
const RUNNING: int = 2

func tick(blackboard: Dictionary) -> int:
    return FAILURE
