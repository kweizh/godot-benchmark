extends Node

# Test harness for the quest_system_custom_resource Harbor task.
# This scene is injected into the project under res://__verify__/ and executed
# headlessly. It emits one JSON line per assertion of the form:
#   RESULT:{"name":"...","ok":true|false,"detail":"..."}
# The Python verifier reads stdout and asserts that every RESULT has ok=true.

var _signal_log: Array = []


func _record(name: String, ok: bool, detail: String = "") -> void:
	var payload := {"name": name, "ok": ok, "detail": detail}
	print("RESULT:" + JSON.stringify(payload))


func _expect_export(script_resource: Script, prop_name: String, expected_type: int) -> bool:
	var props := script_resource.get_script_property_list()
	for p in props:
		if p.get("name", "") == prop_name:
			var usage: int = int(p.get("usage", 0))
			if (usage & PROPERTY_USAGE_STORAGE) == 0:
				continue
			var ptype: int = int(p.get("type", -1))
			if ptype == expected_type:
				return true
			_record(
				"export_%s" % prop_name,
				false,
				"property %s found with type %d, expected %d" % [prop_name, ptype, expected_type]
			)
			return false
	_record("export_%s" % prop_name, false, "property %s not found in script" % prop_name)
	return false


func _connect_signal(obj: Object, sig: StringName) -> void:
	if obj == null:
		return
	if not obj.has_signal(sig):
		return
	obj.connect(sig, Callable(self, "_on_any_signal").bind(sig))


func _on_any_signal(a = null, b = null, c = null, d = null, sig: StringName = &""):
	# Variadic-ish receiver. Callable.bind appends the StringName at the end.
	var args := []
	for v in [a, b, c, d]:
		if v == null:
			continue
		args.append(v)
	_signal_log.append({"signal": sig, "args": args})


func _last_signal(sig: StringName) -> Dictionary:
	for i in range(_signal_log.size() - 1, -1, -1):
		if _signal_log[i]["signal"] == sig:
			return _signal_log[i]
	return {}


func _count_signal(sig: StringName) -> int:
	var n := 0
	for entry in _signal_log:
		if entry["signal"] == sig:
			n += 1
	return n


func _ready() -> void:
	# 1. Verify the scripts exist and have correct class_name / fields.
	var obj_script: Script = load("res://scripts/QuestObjective.gd") as Script
	_record(
		"objective_script_loaded",
		obj_script != null,
		"res://scripts/QuestObjective.gd"
	)
	if obj_script != null:
		_record(
			"objective_class_name",
			obj_script.get_global_name() == &"QuestObjective",
			"global_name=%s" % obj_script.get_global_name()
		)
		_expect_export(obj_script, "description", TYPE_STRING)
		_expect_export(obj_script, "target_count", TYPE_INT)
		_expect_export(obj_script, "current_count", TYPE_INT)

	var quest_script: Script = load("res://scripts/Quest.gd") as Script
	_record("quest_script_loaded", quest_script != null, "res://scripts/Quest.gd")
	if quest_script != null:
		_record(
			"quest_class_name",
			quest_script.get_global_name() == &"Quest",
			"global_name=%s" % quest_script.get_global_name()
		)
		_expect_export(quest_script, "id", TYPE_STRING_NAME)
		_expect_export(quest_script, "title", TYPE_STRING)
		_expect_export(quest_script, "description", TYPE_STRING)
		_expect_export(quest_script, "objectives", TYPE_ARRAY)
		_expect_export(quest_script, "prerequisite_quest_ids", TYPE_ARRAY)
		_expect_export(quest_script, "reward_gold", TYPE_INT)
		_expect_export(quest_script, "reward_items", TYPE_ARRAY)

	# 2. Load the three .tres quests and verify prerequisite chain.
	var quest_a: Resource = load("res://resources/quests/quest_a.tres")
	var quest_b: Resource = load("res://resources/quests/quest_b.tres")
	var quest_c: Resource = load("res://resources/quests/quest_c.tres")

	_record("quest_a_loaded", quest_a != null, "res://resources/quests/quest_a.tres")
	_record("quest_b_loaded", quest_b != null, "res://resources/quests/quest_b.tres")
	_record("quest_c_loaded", quest_c != null, "res://resources/quests/quest_c.tres")

	if quest_a != null:
		_record(
			"quest_a_id",
			StringName(quest_a.get("id")) == &"quest_a",
			"id=%s" % str(quest_a.get("id"))
		)
		var qa_objs: Array = quest_a.get("objectives")
		_record(
			"quest_a_has_objective",
			qa_objs != null and qa_objs.size() >= 1,
			"objective count=%d" % (qa_objs.size() if qa_objs != null else -1)
		)
	if quest_b != null:
		var prereqs_b: Array = quest_b.get("prerequisite_quest_ids")
		var ok_b := prereqs_b != null and prereqs_b.size() == 1 and StringName(prereqs_b[0]) == &"quest_a"
		_record("quest_b_prereqs", ok_b, "prereqs=%s" % str(prereqs_b))
	if quest_c != null:
		var prereqs_c: Array = quest_c.get("prerequisite_quest_ids")
		var ok_c := prereqs_c != null and prereqs_c.size() == 1 and StringName(prereqs_c[0]) == &"quest_b"
		_record("quest_c_prereqs", ok_c, "prereqs=%s" % str(prereqs_c))

	# 3. Autoload QuestManager must exist as /root/QuestManager.
	var qm: Node = get_node_or_null("/root/QuestManager")
	_record("quest_manager_autoloaded", qm != null, "/root/QuestManager")
	if qm == null:
		_finish()
		return

	# Connect to its signals so we can verify emissions.
	_signal_log.clear()
	_connect_signal(qm, &"quest_started")
	_connect_signal(qm, &"quest_progress")
	_connect_signal(qm, &"quest_completed")

	# 4. Register the three quests.
	if quest_a != null:
		qm.call("register_quest", quest_a)
	if quest_b != null:
		qm.call("register_quest", quest_b)
	if quest_c != null:
		qm.call("register_quest", quest_c)

	# 5. Prerequisite checks.
	_record(
		"can_start_quest_a_initial",
		bool(qm.call("can_start", &"quest_a")) == true,
		"expected true before any completion"
	)
	_record(
		"can_start_quest_b_initial",
		bool(qm.call("can_start", &"quest_b")) == false,
		"expected false before quest_a is completed"
	)

	# 6. Starting quest_a emits quest_started with id quest_a.
	var started_a: bool = bool(qm.call("start_quest", &"quest_a"))
	_record("start_quest_a_returns_true", started_a, "got %s" % str(started_a))
	await get_tree().process_frame
	var last_started := _last_signal(&"quest_started")
	var started_ok := last_started.size() > 0 and last_started["args"].size() >= 1 and StringName(last_started["args"][0]) == &"quest_a"
	_record("quest_started_signal_quest_a", started_ok, "last=%s" % str(last_started))

	# 7. Progress reporting: get_progress should be 0.0 before, 1.0 after all
	#    objectives are filled. report_progress must cap at target_count and
	#    emit quest_progress.
	var qa_progress_before := float(quest_a.call("get_progress"))
	_record(
		"quest_a_progress_before",
		is_equal_approx(qa_progress_before, 0.0),
		"got %f" % qa_progress_before
	)

	var progress_emissions_before := _count_signal(&"quest_progress")

	var qa_objectives: Array = quest_a.get("objectives")
	for obj in qa_objectives:
		var desc := StringName(obj.get("description"))
		var target := int(obj.get("target_count"))
		# Try to push more than target_count to verify the cap.
		for i in range(target + 2):
			qm.call("report_progress", desc, 1)
		await get_tree().process_frame
		_record(
			"objective_capped_%s" % str(desc),
			int(obj.get("current_count")) == target,
			"current_count=%d target=%d" % [int(obj.get("current_count")), target]
		)

	await get_tree().process_frame
	var progress_emissions_after := _count_signal(&"quest_progress")
	_record(
		"quest_progress_signal_emitted",
		progress_emissions_after > progress_emissions_before,
		"before=%d after=%d" % [progress_emissions_before, progress_emissions_after]
	)

	var qa_progress_after := float(quest_a.call("get_progress"))
	_record(
		"quest_a_progress_after",
		is_equal_approx(qa_progress_after, 1.0),
		"got %f" % qa_progress_after
	)

	_record(
		"quest_a_is_complete",
		bool(quest_a.call("is_complete")) == true,
		"is_complete should be true after all objectives filled"
	)

	# 8. complete_quest succeeds for quest_a and emits reward info.
	var completed_a: bool = bool(qm.call("complete_quest", &"quest_a"))
	_record("complete_quest_a_returns_true", completed_a, "got %s" % str(completed_a))
	await get_tree().process_frame
	var last_completed := _last_signal(&"quest_completed")
	var completed_ok := last_completed.size() > 0 and last_completed["args"].size() >= 1 and StringName(last_completed["args"][0]) == &"quest_a"
	_record("quest_completed_signal_quest_a", completed_ok, "last=%s" % str(last_completed))

	# 9. After quest_a is complete, can_start(quest_b) becomes true.
	_record(
		"can_start_quest_b_after_a",
		bool(qm.call("can_start", &"quest_b")) == true,
		"expected true after quest_a completed"
	)

	# 10. complete_quest must fail for quest_b before any progress is made.
	# Start quest_b first so it is active.
	qm.call("start_quest", &"quest_b")
	await get_tree().process_frame
	var completed_emissions_before := _count_signal(&"quest_completed")
	var completed_b: bool = bool(qm.call("complete_quest", &"quest_b"))
	await get_tree().process_frame
	var completed_emissions_after := _count_signal(&"quest_completed")
	_record(
		"complete_quest_b_rejected",
		completed_b == false and completed_emissions_after == completed_emissions_before,
		"returned=%s emissions_delta=%d" % [str(completed_b), completed_emissions_after - completed_emissions_before]
	)

	_finish()


func _finish() -> void:
	print("RESULT_DONE")
	get_tree().quit()
