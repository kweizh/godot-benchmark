@tool
class_name Quest
extends Resource

@export var id: StringName = &""
@export var title: String = ""
@export var description: String = ""
@export var objectives: Array[QuestObjective] = []
@export var prerequisite_quest_ids: Array[StringName] = []
@export var reward_gold: int = 0
@export var reward_items: Array[StringName] = []

func is_complete() -> bool:
	if objectives.is_empty():
		return false
	for objective in objectives:
		if not objective.is_complete():
			return false
	return true

func get_progress() -> float:
	if objectives.is_empty():
		return 0.0
	var total_target: int = 0
	var total_current: int = 0
	for objective in objectives:
		total_target += objective.target_count
		total_current += mini(objective.current_count, objective.target_count)
	if total_target == 0:
		return 1.0
	return float(total_current) / float(total_target)
