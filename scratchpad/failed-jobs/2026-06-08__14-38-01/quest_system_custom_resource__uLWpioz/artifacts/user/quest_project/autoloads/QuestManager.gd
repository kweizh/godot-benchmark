extends Node

signal quest_started(id: StringName)
signal quest_progress(id: StringName, progress: float)
signal quest_completed(id: StringName, reward_gold: int, reward_items: Array[StringName])

var registered_quests: Dictionary = {}
var active_quests: Dictionary = {}
var completed_ids: Array[StringName] = []

func _ready() -> void:
	# Automatically load and register quests from res://resources/quests/
	var path = "res://resources/quests"
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var quest = load(path + "/" + file_name)
				if quest is Quest:
					register_quest(quest)
			file_name = dir.get_next()

func register_quest(quest: Quest) -> void:
	if quest != null:
		registered_quests[quest.id] = quest

func can_start(quest_id: StringName) -> bool:
	var quest = registered_quests.get(quest_id)
	if quest == null:
		return false
	for prereq in quest.prerequisite_quest_ids:
		if not prereq in completed_ids:
			return false
	return true

func start_quest(quest_id: StringName) -> bool:
	if not can_start(quest_id):
		return false
	var quest = registered_quests.get(quest_id)
	if quest == null:
		return false
	active_quests[quest_id] = quest
	quest_started.emit(quest_id)
	return true

func report_progress(objective_key: StringName, amount: int = 1) -> void:
	for quest_id in active_quests:
		var quest = active_quests[quest_id]
		var updated = false
		for objective in quest.objectives:
			if objective != null and StringName(objective.description) == objective_key:
				objective.current_count = clampi(objective.current_count + amount, 0, objective.target_count)
				updated = true
		if updated:
			quest_progress.emit(quest_id, quest.get_progress())

func complete_quest(quest_id: StringName) -> bool:
	var quest = active_quests.get(quest_id)
	if quest == null:
		quest = registered_quests.get(quest_id)
	if quest == null:
		return false
	if not quest.is_complete():
		return false
	
	if not quest_id in completed_ids:
		completed_ids.append(quest_id)
	
	active_quests.erase(quest_id)
	
	quest_completed.emit(quest_id, quest.reward_gold, quest.reward_items)
	return true
