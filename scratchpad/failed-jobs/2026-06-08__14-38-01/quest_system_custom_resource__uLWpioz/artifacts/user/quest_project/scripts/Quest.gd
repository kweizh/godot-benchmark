class_name Quest
extends Resource

@export var id: StringName
@export var title: String
@export var description: String
@export var objectives: Array[QuestObjective]
@export var prerequisite_quest_ids: Array[StringName]
@export var reward_gold: int
@export var reward_items: Array[StringName]

func is_complete() -> bool:
	if objectives.is_empty():
		return true
	for objective in objectives:
		if objective == null or not objective.is_complete():
			return false
	return true

func get_progress() -> float:
	if objectives.is_empty():
		return 1.0
	var total_progress: float = 0.0
	for objective in objectives:
		if objective != null:
			if objective.target_count > 0:
				var obj_progress = float(objective.current_count) / float(objective.target_count)
				total_progress += clampf(obj_progress, 0.0, 1.0)
			else:
				total_progress += 1.0
	return total_progress / float(objectives.size())
