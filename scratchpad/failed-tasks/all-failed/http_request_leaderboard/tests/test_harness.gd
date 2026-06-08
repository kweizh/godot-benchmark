extends Node

# Test harness for the LeaderboardClient autoload.
#
# It exercises five behaviors and writes a structured report to
# `res://godot_test.log` (which the Python verifier reads back). Every line of
# the report ends with either `OK` or `FAIL: <reason>`.

const SERVER_URL := "http://127.0.0.1:8765"
const LOG_PATH := "res://godot_test.log"

var _lines: PackedStringArray = PackedStringArray()


func _ready() -> void:
	# Best-effort: ensure the verifier sees a fresh log even if a previous run
	# wrote one.
	var f := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f != null:
		f.close()

	await _run_all()

	_flush_log()
	get_tree().quit(0)


func _record(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		_lines.append("%s OK" % name)
	else:
		_lines.append("%s FAIL: %s" % [name, detail])


func _flush_log() -> void:
	var f := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f == null:
		printerr("Could not open %s for writing" % LOG_PATH)
		return
	for line in _lines:
		f.store_line(line)
		print(line)
	f.close()


func _reset_server() -> void:
	# Hit /reset on the verifier-managed server so each subtest starts clean.
	var req := HTTPRequest.new()
	add_child(req)
	var err := req.request(SERVER_URL + "/reset")
	if err == OK:
		await req.request_completed
	req.queue_free()


func _set_top_failures(count: int) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	var err := req.request(SERVER_URL + "/set_top_failures?count=%d" % count)
	if err == OK:
		await req.request_completed
	req.queue_free()


func _get_client() -> Node:
	return get_node_or_null("/root/LeaderboardClient")


func _run_all() -> void:
	# ----- Autoload presence -------------------------------------------------
	var client := _get_client()
	if client == null:
		_record("autoload_present", false, "LeaderboardClient autoload not found at /root/LeaderboardClient")
		return
	_record("autoload_present", true)

	# Required signals and methods.
	var required_signals := ["leaderboard_fetched", "score_submitted", "request_failed"]
	for s in required_signals:
		_record("signal_%s" % s, client.has_signal(s),
			"signal %s missing" % s)

	var required_methods := ["fetch_top", "submit_score"]
	for m in required_methods:
		_record("method_%s" % m, client.has_method(m),
			"method %s missing" % m)

	# Configure base URL and max retries.
	client.set("base_url", SERVER_URL)
	client.set("max_retries", 2)

	# ----- Test 1: fetch_top happy path --------------------------------------
	await _reset_server()
	var fetched_entries: Array = []
	var fetch_count: int = 0
	var failed_calls: Array = []

	var on_fetched := func(entries):
		fetched_entries = entries
		fetch_count += 1
	var on_failed := func(endpoint, code):
		failed_calls.append({"endpoint": endpoint, "code": code})

	client.connect("leaderboard_fetched", on_fetched)
	client.connect("request_failed", on_failed)

	client.call("fetch_top", 10)
	var ok_wait := await _wait_for(func(): return fetch_count >= 1, 5.0)
	if not ok_wait:
		_record("fetch_top_happy", false, "leaderboard_fetched not emitted within timeout")
	else:
		var size_ok := fetched_entries.size() == 2
		var alice_ok := size_ok and str(fetched_entries[0].get("name", "")) == "Alice" \
			and int(fetched_entries[0].get("score", -1)) == 300
		var bob_ok := size_ok and str(fetched_entries[1].get("name", "")) == "Bob" \
			and int(fetched_entries[1].get("score", -1)) == 200
		_record("fetch_top_happy", size_ok and alice_ok and bob_ok,
			"got entries=%s" % str(fetched_entries))

	# ----- Test 2: submit_score happy path -----------------------------------
	var submit_results: Array = []
	var on_submitted := func(success, server_rank):
		submit_results.append({"success": success, "rank": server_rank})

	client.connect("score_submitted", on_submitted)

	client.call("submit_score", "Carol", 150)
	var ok_submit := await _wait_for(func(): return submit_results.size() >= 1, 5.0)
	if not ok_submit:
		_record("submit_score_happy", false, "score_submitted not emitted within timeout")
	else:
		var r = submit_results[0]
		var ok := bool(r["success"]) == true and int(r["rank"]) == 3
		_record("submit_score_happy", ok, "got=%s" % str(r))

	# ----- Test 3: fetch_top retry-success (max_retries=2, 2 failures) -------
	fetched_entries = []
	fetch_count = 0
	failed_calls = []
	await _reset_server()
	await _set_top_failures(2)
	client.set("max_retries", 2)

	client.call("fetch_top", 10)
	var ok_retry := await _wait_for(func(): return fetch_count >= 1, 8.0)
	if not ok_retry:
		_record("fetch_top_retry_success", false, "leaderboard_fetched not emitted within timeout")
	else:
		var sz := fetched_entries.size() == 2
		var no_fail := failed_calls.size() == 0
		_record("fetch_top_retry_success", sz and no_fail,
			"entries=%s failed_calls=%s" % [str(fetched_entries), str(failed_calls)])

	# ----- Test 4: fetch_top retry-exhaustion (max_retries=1, 3 failures) ----
	fetched_entries = []
	fetch_count = 0
	failed_calls = []
	await _reset_server()
	await _set_top_failures(3)
	client.set("max_retries", 1)

	client.call("fetch_top", 10)
	var ok_exhaust := await _wait_for(func(): return failed_calls.size() >= 1, 8.0)
	if not ok_exhaust:
		_record("fetch_top_retry_exhaust", false, "request_failed not emitted within timeout")
	else:
		var first = failed_calls[0]
		var endpoint_ok := str(first["endpoint"]).find("/top") != -1
		var code_ok := int(first["code"]) == 500
		var no_fetch := fetch_count == 0
		_record("fetch_top_retry_exhaust", endpoint_ok and code_ok and no_fetch,
			"first=%s fetch_count=%d" % [str(first), fetch_count])


func _wait_for(predicate: Callable, timeout_seconds: float) -> bool:
	# Poll once per frame until predicate is true or timeout elapses.
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if bool(predicate.call()):
			return true
		await get_tree().process_frame
		elapsed += max(0.001, get_process_delta_time())
	return bool(predicate.call())
