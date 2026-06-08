class_name Quest
extends Resource

const QuestObjectiveClass := preload("res://scripts/QuestObjective.gd")

@export var id: StringName = &""
@export var title: String = ""
@export var description: String = ""
@export var objectives: Array[Resource] = []
@export var prerequisite_quest_ids: Array[StringName] = []
@export var reward_gold: int = 0
@export var reward_items: Array[StringName] = []

func is_complete() -> bool:
	for objective in objectives:
		if not objective.is_complete():
			return false
	return true

func get_progress() -> float:
	if objectives.is_empty():
		return 0.0
	var total: float = 0.0
	for objective in objectives:
		if objective.target_count > 0:
			total += float(objective.current_count) / float(objective.target_count)
		else:
			total += 1.0
	return total / float(objectives.size())
