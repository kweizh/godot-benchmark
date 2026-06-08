extends Node

# Verification harness for the Bus autoload event bus.
# Exercises every requirement and emits a single line:
#   RESULTS={...JSON...}
# Each value must be true for the task to be considered correct.


class Recorder extends Node:
	var calls: Array = []

	func handler(payload) -> void:
		calls.append(payload)


class SignalSink extends Node:
	var events: Array = []

	func on_event_published(channel, payload) -> void:
		events.append([channel, payload])


func _fail(reason: String) -> void:
	printerr("HARNESS_FAIL: " + reason)


func _ready() -> void:
	var results: Dictionary = {}

	var bus := get_node_or_null("/root/Bus")
	if bus == null:
		_fail("Bus autoload not found at /root/Bus")
		print("RESULTS=" + JSON.stringify({"autoload": false}))
		get_tree().quit(2)
		return
	results["autoload"] = true

	# --- Multi subs ---
	var rec_a := Recorder.new()
	var rec_b := Recorder.new()
	add_child(rec_a)
	add_child(rec_b)
	var sid_a: int = int(bus.call("subscribe", StringName("tick"), Callable(rec_a, "handler")))
	var sid_b: int = int(bus.call("subscribe", StringName("tick"), Callable(rec_b, "handler")))
	bus.call("publish", StringName("tick"), {"value": 42})
	await get_tree().process_frame
	results["multi_subs"] = (
		rec_a.calls.size() == 1
		and rec_b.calls.size() == 1
		and typeof(rec_a.calls[0]) == TYPE_DICTIONARY
		and int(rec_a.calls[0].get("value", -1)) == 42
		and int(rec_b.calls[0].get("value", -1)) == 42
	)

	# --- Unsubscribe ---
	rec_a.calls.clear()
	rec_b.calls.clear()
	var unsub_ok: bool = bool(bus.call("unsubscribe", sid_a))
	var unsub_bogus_ok: bool = not bool(bus.call("unsubscribe", 999999))
	bus.call("publish", StringName("tick"), {"value": 7})
	await get_tree().process_frame
	results["unsubscribe"] = (
		unsub_ok
		and unsub_bogus_ok
		and rec_a.calls.size() == 0
		and rec_b.calls.size() == 1
		and int(rec_b.calls[0].get("value", -1)) == 7
	)
	# Clean up remaining tick sub.
	bus.call("clear_channel", StringName("tick"))

	# --- publish_once ---
	var rec_c := Recorder.new()
	var rec_d := Recorder.new()
	add_child(rec_c)
	add_child(rec_d)
	bus.call("subscribe", StringName("once"), Callable(rec_c, "handler"))
	bus.call("subscribe", StringName("once"), Callable(rec_d, "handler"))
	bus.call("publish_once", StringName("once"), {"n": 1})
	await get_tree().process_frame
	var first_pass: bool = (
		rec_c.calls.size() == 1
		and rec_d.calls.size() == 1
		and int(rec_c.calls[0].get("n", -1)) == 1
		and int(rec_d.calls[0].get("n", -1)) == 1
	)
	rec_c.calls.clear()
	rec_d.calls.clear()
	bus.call("publish", StringName("once"), {"n": 2})
	await get_tree().process_frame
	var second_pass: bool = rec_c.calls.size() == 0 and rec_d.calls.size() == 0
	results["publish_once"] = first_pass and second_pass

	# --- Middleware drop + event_published signal ---
	if not bus.has_signal("event_published"):
		_fail("Bus missing required signal event_published")
		print("RESULTS=" + JSON.stringify(results))
		get_tree().quit(3)
		return
	var sink := SignalSink.new()
	add_child(sink)
	bus.connect("event_published", Callable(sink, "on_event_published"))

	bus.call("clear_middleware")
	bus.call("add_middleware", Callable(self, "_drop_middleware"))
	var rec_e := Recorder.new()
	add_child(rec_e)
	bus.call("subscribe", StringName("drop"), Callable(rec_e, "handler"))
	bus.call("publish", StringName("drop"), {"x": 1})
	await get_tree().process_frame
	var signal_seen: bool = false
	for ev in sink.events:
		var ch = ev[0]
		var pl = ev[1]
		if String(ch) == "drop" and typeof(pl) == TYPE_DICTIONARY and int(pl.get("x", -1)) == 1:
			signal_seen = true
			break
	results["middleware_drop"] = (rec_e.calls.size() == 0) and signal_seen

	# --- Middleware transform ---
	bus.call("clear_middleware")
	bus.call("add_middleware", Callable(self, "_wrap_middleware"))
	var rec_f := Recorder.new()
	add_child(rec_f)
	bus.call("subscribe", StringName("wrap"), Callable(rec_f, "handler"))
	bus.call("publish", StringName("wrap"), {"x": 1})
	await get_tree().process_frame
	results["middleware_transform"] = (
		rec_f.calls.size() == 1
		and typeof(rec_f.calls[0]) == TYPE_DICTIONARY
		and rec_f.calls[0].has("wrapped")
		and typeof(rec_f.calls[0]["wrapped"]) == TYPE_DICTIONARY
		and int(rec_f.calls[0]["wrapped"].get("x", -1)) == 1
	)
	bus.call("clear_middleware")

	# --- Freed object auto-prune ---
	var target: Node = Node.new()
	add_child(target)
	target.set_script(load("res://_zealt_tests/freed_target.gd"))
	bus.call("subscribe", StringName("gc"), Callable(target, "_handler"))
	target.queue_free()
	# Free immediately so the callable becomes invalid.
	target.free()
	var crashed := false
	# If anything crashed inside publish, the engine would abort; we just trust no error.
	bus.call("publish", StringName("gc"), null)
	await get_tree().process_frame
	var count_after: int = int(bus.call("subscription_count", StringName("gc")))
	results["freed_autoprune"] = (count_after == 0) and not crashed

	# --- clear_channel ---
	var rec_g := Recorder.new()
	var rec_h := Recorder.new()
	add_child(rec_g)
	add_child(rec_h)
	bus.call("subscribe", StringName("z"), Callable(rec_g, "handler"))
	bus.call("subscribe", StringName("z"), Callable(rec_h, "handler"))
	bus.call("clear_channel", StringName("z"))
	bus.call("publish", StringName("z"), {"k": 1})
	await get_tree().process_frame
	results["clear_channel"] = (
		rec_g.calls.size() == 0
		and rec_h.calls.size() == 0
		and int(bus.call("subscription_count", StringName("z"))) == 0
	)

	print("RESULTS=" + JSON.stringify(results))
	get_tree().quit(0)


func _drop_middleware(_channel, _payload):
	return null


func _wrap_middleware(_channel, payload):
	return {"wrapped": payload}
