@tool
class_name QuestObjective
extends Resource

@export var description: String = ""
@export var target_count: int = 1
@export var current_count: int = 0

func is_complete() -> bool:
	return current_count >= target_count
