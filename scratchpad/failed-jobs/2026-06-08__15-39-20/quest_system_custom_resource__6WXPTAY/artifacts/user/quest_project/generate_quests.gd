extends SceneTree

func _init():
	var QuestObjective = load("res://scripts/QuestObjective.gd")
	var Quest = load("res://scripts/Quest.gd")
	
	var obj_a = QuestObjective.new()
	obj_a.description = "Collect Apples"
	obj_a.target_count = 5
	
	var quest_a = Quest.new()
	quest_a.id = "quest_a"
	quest_a.title = "First Quest"
	quest_a.description = "Get 5 apples"
	quest_a.objectives = [obj_a]
	quest_a.reward_gold = 10
	quest_a.reward_items = ["apple_pie"]
	
	ResourceSaver.save(quest_a, "res://resources/quests/quest_a.tres")
	
	var obj_b = QuestObjective.new()
	obj_b.description = "Defeat Slimes"
	obj_b.target_count = 3
	
	var quest_b = Quest.new()
	quest_b.id = "quest_b"
	quest_b.title = "Second Quest"
	quest_b.description = "Defeat 3 slimes"
	quest_b.objectives = [obj_b]
	quest_b.prerequisite_quest_ids = ["quest_a"]
	quest_b.reward_gold = 20
	quest_b.reward_items = ["slime_gel"]
	
	ResourceSaver.save(quest_b, "res://resources/quests/quest_b.tres")
	
	var obj_c = QuestObjective.new()
	obj_c.description = "Talk to King"
	obj_c.target_count = 1
	
	var quest_c = Quest.new()
	quest_c.id = "quest_c"
	quest_c.title = "Third Quest"
	quest_c.description = "Talk to the king"
	quest_c.objectives = [obj_c]
	quest_c.prerequisite_quest_ids = ["quest_b"]
	quest_c.reward_gold = 100
	quest_c.reward_items = ["crown"]
	
	ResourceSaver.save(quest_c, "res://resources/quests/quest_c.tres")
	
	quit()
