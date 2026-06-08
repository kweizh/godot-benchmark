class_name QuestObjective
extends Resource

@export var description: String
@export var target_count: int
@export var current_count: int = 0

func is_complete() -> bool:
	return current_count >= target_count
