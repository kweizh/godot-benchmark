extends Node

signal quest_started(id)
signal quest_progress(id, progress)
signal quest_completed(id, reward_gold, reward_items)

# All registered quests keyed by StringName id
var _quests: Dictionary = {}
# Set of quest ids that are currently active
var _active_ids: Array[StringName] = []
# Set of quest ids that have been completed
var completed_ids: Array[StringName] = []


func register_quest(quest: Quest) -> void:
	_quests[quest.id] = quest


func can_start(quest_id: StringName) -> bool:
	var quest: Quest = _quests.get(quest_id, null)
	if quest == null:
		return false
	for prereq_id in quest.prerequisite_quest_ids:
		if not prereq_id in completed_ids:
			return false
	return true


func start_quest(quest_id: StringName) -> bool:
	if not can_start(quest_id):
		return false
	if quest_id in _active_ids:
		return false
	_active_ids.append(quest_id)
	emit_signal("quest_started", quest_id)
	return true


func report_progress(objective_key: StringName, amount: int = 1) -> void:
	for quest_id in _active_ids:
		var quest: Quest = _quests.get(quest_id, null)
		if quest == null:
			continue
		var changed := false
		for objective in quest.objectives:
			if StringName(objective.description) == objective_key:
				if objective.current_count < objective.target_count:
					objective.current_count = mini(
						objective.current_count + amount,
						objective.target_count
					)
					changed = true
		if changed:
			emit_signal("quest_progress", quest_id, quest.get_progress())


func complete_quest(quest_id: StringName) -> bool:
	var quest: Quest = _quests.get(quest_id, null)
	if quest == null:
		return false
	if not quest.is_complete():
		return false
	if quest_id in completed_ids:
		return false
	# Remove from active list
	var idx := _active_ids.find(quest_id)
	if idx != -1:
		_active_ids.remove_at(idx)
	completed_ids.append(quest_id)
	emit_signal("quest_completed", quest_id, quest.reward_gold, quest.reward_items)
	return true
