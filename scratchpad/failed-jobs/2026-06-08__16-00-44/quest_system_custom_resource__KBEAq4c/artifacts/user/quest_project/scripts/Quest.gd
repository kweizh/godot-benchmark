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
	for objective in objectives:
		if not objective.is_complete():
			return false
	return true


func get_progress() -> float:
	if objectives.is_empty():
		return 1.0 if is_complete() else 0.0
	var total_progress: float = 0.0
	for objective in objectives:
		if objective.target_count <= 0:
			total_progress += 1.0
		else:
			total_progress += float(objective.current_count) / float(objective.target_count)
	return total_progress / float(objectives.size())