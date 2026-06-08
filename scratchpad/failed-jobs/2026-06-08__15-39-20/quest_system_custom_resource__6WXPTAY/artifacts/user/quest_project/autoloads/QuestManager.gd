extends Node

signal quest_started(id: StringName)
signal quest_progress(id: StringName, progress: float)
signal quest_completed(id: StringName, reward_gold: int, reward_items: Array[StringName])

var registered_quests: Dictionary = {} # StringName -> Quest
var active_quests: Dictionary = {} # StringName -> Quest
var completed_ids: Array[StringName] = []

func register_quest(quest: Quest) -> void:
	registered_quests[quest.id] = quest

func can_start(quest_id: StringName) -> bool:
	if not registered_quests.has(quest_id):
		return false
	if active_quests.has(quest_id) or completed_ids.has(quest_id):
		return false
		
	var quest: Quest = registered_quests[quest_id]
	for prereq in quest.prerequisite_quest_ids:
		if not completed_ids.has(prereq):
			return false
	return true

func start_quest(quest_id: StringName) -> bool:
	if not can_start(quest_id):
		return false
	
	var quest: Quest = registered_quests[quest_id]
	active_quests[quest_id] = quest
	quest_started.emit(quest_id)
	return true

func report_progress(objective_key: StringName, amount: int = 1) -> void:
	for quest_id in active_quests:
		var quest: Quest = active_quests[quest_id]
		var changed: bool = false
		for obj in quest.objectives:
			if StringName(obj.description) == objective_key:
				var old_count = obj.current_count
				obj.current_count = min(obj.current_count + amount, obj.target_count)
				if obj.current_count != old_count:
					changed = true
		
		if changed:
			quest_progress.emit(quest_id, quest.get_progress())

func complete_quest(quest_id: StringName) -> bool:
	if not active_quests.has(quest_id):
		return false
		
	var quest: Quest = active_quests[quest_id]
	if not quest.is_complete():
		return false
		
	active_quests.erase(quest_id)
	completed_ids.append(quest_id)
	quest_completed.emit(quest_id, quest.reward_gold, quest.reward_items)
	return true
