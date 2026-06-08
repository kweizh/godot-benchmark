extends Node

signal quest_started(id: StringName)
signal quest_progress(id: StringName, progress: float)
signal quest_completed(id: StringName, reward_gold: int, reward_items: Array[StringName])

var _quests: Dictionary = {}  # StringName -> Quest
var _active_ids: Dictionary = {}  # StringName -> bool (set of active quest ids)
var completed_ids: Dictionary = {}  # StringName -> bool (set of completed quest ids)


func register_quest(quest: Quest) -> void:
	_quests[quest.id] = quest


func can_start(quest_id: StringName) -> bool:
	if not _quests.has(quest_id):
		return false
	var quest: Quest = _quests[quest_id]
	for prereq_id: StringName in quest.prerequisite_quest_ids:
		if not completed_ids.has(prereq_id):
			return false
	return true


func start_quest(quest_id: StringName) -> bool:
	if not can_start(quest_id):
		return false
	_active_ids[quest_id] = true
	quest_started.emit(quest_id)
	return true


func report_progress(objective_key: StringName, amount: int = 1) -> void:
	for quest_id: StringName in _active_ids:
		var quest: Quest = _quests[quest_id]
		for objective: QuestObjective in quest.objectives:
			if StringName(objective.description) == objective_key:
				objective.current_count = mini(objective.current_count + amount, objective.target_count)
				quest_progress.emit(quest_id, quest.get_progress())


func complete_quest(quest_id: StringName) -> bool:
	if not _quests.has(quest_id):
		return false
	var quest: Quest = _quests[quest_id]
	if not quest.is_complete():
		return false
	_active_ids.erase(quest_id)
	completed_ids[quest_id] = true
	quest_completed.emit(quest_id, quest.reward_gold, quest.reward_items)
	return true