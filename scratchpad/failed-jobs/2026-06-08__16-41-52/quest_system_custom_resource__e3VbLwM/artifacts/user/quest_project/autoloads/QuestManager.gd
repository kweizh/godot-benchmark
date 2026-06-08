extends Node

const QuestClass := preload("res://scripts/Quest.gd")

signal quest_started(id: StringName)
signal quest_progress(id: StringName, progress: float)
signal quest_completed(id: StringName, reward_gold: int, reward_items: Array[StringName])

var _quests: Dictionary = {}  # StringName -> Quest
var _active_quests: Dictionary = {}  # StringName -> Quest
var completed_ids: Array[StringName] = []

func register_quest(quest: Resource) -> void:
	_quests[quest.id] = quest

func can_start(quest_id: StringName) -> bool:
	if not _quests.has(quest_id):
		return false
	var quest: Resource = _quests[quest_id]
	for prereq_id in quest.prerequisite_quest_ids:
		if prereq_id not in completed_ids:
			return false
	return true

func start_quest(quest_id: StringName) -> bool:
	if not can_start(quest_id):
		return false
	if not _quests.has(quest_id):
		return false
	var quest: Resource = _quests[quest_id]
	_active_quests[quest_id] = quest
	quest_started.emit(quest_id)
	return true

func report_progress(objective_key: StringName, amount: int = 1) -> void:
	var key: StringName = objective_key
	for quest_id in _active_quests:
		var quest: Resource = _active_quests[quest_id]
		for objective in quest.objectives:
			var obj_desc_sn: StringName = StringName(objective.description)
			if obj_desc_sn == key:
				objective.current_count = mini(objective.current_count + amount, objective.target_count)
		var progress: float = quest.get_progress()
		quest_progress.emit(quest_id, progress)

func complete_quest(quest_id: StringName) -> bool:
	if not _active_quests.has(quest_id):
		return false
	var quest: Resource = _active_quests[quest_id]
	if not quest.is_complete():
		return false
	_active_quests.erase(quest_id)
	completed_ids.append(quest_id)
	quest_completed.emit(quest_id, quest.reward_gold, quest.reward_items)
	return true
