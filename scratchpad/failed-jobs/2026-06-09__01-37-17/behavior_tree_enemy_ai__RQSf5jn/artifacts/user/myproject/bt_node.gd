class_name BTNode
extends Resource

const SUCCESS = 0
const FAILURE = 1
const RUNNING = 2

# Virtual method to be overridden by subclasses
func tick(blackboard: Dictionary) -> int:
	return FAILURE
