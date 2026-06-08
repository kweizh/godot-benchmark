## TestRunner — headless acceptance tests for the Bus autoload.
## Runs on _ready, prints results, then calls get_tree().quit().
extends Node

# ---------------------------------------------------------------------------
# Tiny assertion helpers
# ---------------------------------------------------------------------------

var _pass: int = 0
var _fail: int = 0
var _current_suite: String = ""


func _suite(name: String) -> void:
	_current_suite = name
	print("\n--- %s ---" % name)


func _ok(label: String) -> void:
	_pass += 1
	print("  PASS  %s" % label)


func _fail_msg(label: String, detail: String) -> void:
	_fail += 1
	printerr("  FAIL  %s  (%s)" % [label, detail])


func _assert(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		_ok(label)
	else:
		_fail_msg(label, detail if detail != "" else "condition was false")


func _assert_eq(a: Variant, b: Variant, label: String) -> void:
	if a == b:
		_ok(label)
	else:
		_fail_msg(label, "expected %s  got %s" % [str(b), str(a)])

# ---------------------------------------------------------------------------
# Helper receiver objects
# ---------------------------------------------------------------------------

## A plain RefCounted that records every call.
class Receiver:
	var calls: Array = []
	func on_event(payload: Variant) -> void:
		calls.append(payload)
	func reset() -> void:
		calls.clear()

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Give the autoload one frame to fully initialise.
	await get_tree().process_frame
	_run_all()


func _run_all() -> void:
	print("\n========== Bus Acceptance Tests ==========")

	_test_subscribe_and_publish()
	_test_unsubscribe()
	_test_publish_once()
	_test_middleware_drop()
	_test_middleware_transform()
	_test_event_published_signal()
	_test_dead_object_pruning()
	_test_clear_channel()
	_test_clear_middleware()
	_test_subscription_count()

	print("\n==========================================")
	print("Results: %d passed, %d failed" % [_pass, _fail])

	if _fail > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


# ---------------------------------------------------------------------------
# Individual test suites
# ---------------------------------------------------------------------------

func _test_subscribe_and_publish() -> void:
	_suite("subscribe / publish")

	Bus.clear_channel(&"ch_basic")
	var r1 := Receiver.new()
	var r2 := Receiver.new()

	var id1 := Bus.subscribe(&"ch_basic", Callable(r1, "on_event"))
	var id2 := Bus.subscribe(&"ch_basic", Callable(r2, "on_event"))

	_assert(id1 > 0, "subscribe returns positive id (r1)")
	_assert(id2 > 0, "subscribe returns positive id (r2)")
	_assert(id1 != id2, "ids are unique")

	Bus.publish(&"ch_basic", 42)

	_assert_eq(r1.calls.size(), 1, "r1 received exactly one call")
	_assert_eq(r1.calls[0], 42, "r1 received correct payload")
	_assert_eq(r2.calls.size(), 1, "r2 received exactly one call")
	_assert_eq(r2.calls[0], 42, "r2 received correct payload")

	# Clean up
	Bus.unsubscribe(id1)
	Bus.unsubscribe(id2)


func _test_unsubscribe() -> void:
	_suite("unsubscribe")

	Bus.clear_channel(&"ch_unsub")
	var r1 := Receiver.new()
	var r2 := Receiver.new()

	var id1 := Bus.subscribe(&"ch_unsub", Callable(r1, "on_event"))
	var id2 := Bus.subscribe(&"ch_unsub", Callable(r2, "on_event"))

	# Publish once – both should fire.
	Bus.publish(&"ch_unsub", "first")
	_assert_eq(r1.calls.size(), 1, "r1 received first publish")
	_assert_eq(r2.calls.size(), 1, "r2 received first publish")

	# Unsubscribe r1.
	var ok := Bus.unsubscribe(id1)
	_assert(ok, "unsubscribe returns true for valid id")

	var ok_bad := Bus.unsubscribe(id1)
	_assert(not ok_bad, "unsubscribe returns false for already-removed id")

	# Publish again – only r2 should fire.
	Bus.publish(&"ch_unsub", "second")
	_assert_eq(r1.calls.size(), 1, "r1 not called after unsubscribe")
	_assert_eq(r2.calls.size(), 2, "r2 received second publish")

	Bus.unsubscribe(id2)


func _test_publish_once() -> void:
	_suite("publish_once")

	Bus.clear_channel(&"ch_once")
	var r1 := Receiver.new()
	var r2 := Receiver.new()

	Bus.subscribe(&"ch_once", Callable(r1, "on_event"))
	Bus.subscribe(&"ch_once", Callable(r2, "on_event"))

	Bus.publish_once(&"ch_once", "hello")

	_assert_eq(r1.calls.size(), 1, "r1 invoked by publish_once")
	_assert_eq(r2.calls.size(), 1, "r2 invoked by publish_once")

	# A subsequent publish must not invoke either subscriber.
	Bus.publish(&"ch_once", "should_not_arrive")
	_assert_eq(r1.calls.size(), 1, "r1 not invoked after publish_once")
	_assert_eq(r2.calls.size(), 1, "r2 not invoked after publish_once")

	_assert_eq(Bus.subscription_count(&"ch_once"), 0, "channel empty after publish_once")


func _test_middleware_drop() -> void:
	_suite("middleware — drop (return null)")

	Bus.clear_channel(&"ch_mw_drop")
	Bus.clear_middleware()

	var r := Receiver.new()
	Bus.subscribe(&"ch_mw_drop", Callable(r, "on_event"))

	# Middleware that always drops.
	Bus.add_middleware(func(_ch: StringName, _p: Variant) -> Variant: return null)

	Bus.publish(&"ch_mw_drop", "dropped")
	_assert_eq(r.calls.size(), 0, "subscriber not called when middleware drops")

	Bus.clear_middleware()
	Bus.unsubscribe(Bus.subscribe(&"ch_mw_drop", Callable(r, "on_event")))
	Bus.clear_channel(&"ch_mw_drop")


func _test_middleware_transform() -> void:
	_suite("middleware — transform payload")

	Bus.clear_channel(&"ch_mw_xform")
	Bus.clear_middleware()

	var r := Receiver.new()
	Bus.subscribe(&"ch_mw_xform", Callable(r, "on_event"))

	# Middleware that doubles integer payloads.
	Bus.add_middleware(func(_ch: StringName, p: Variant) -> Variant: return p * 2)

	Bus.publish(&"ch_mw_xform", 7)
	_assert_eq(r.calls.size(), 1, "subscriber called with transformed payload")
	_assert_eq(r.calls[0], 14, "payload was doubled by middleware")

	Bus.clear_middleware()
	Bus.clear_channel(&"ch_mw_xform")


func _test_event_published_signal() -> void:
	_suite("event_published signal")

	Bus.clear_channel(&"ch_sig")
	Bus.clear_middleware()

	var signal_log: Array = []
	var on_published := func(ch: StringName, p: Variant) -> void:
		signal_log.append({channel = ch, payload = p})

	Bus.event_published.connect(on_published)

	# Normal publish.
	Bus.publish(&"ch_sig", "ping")
	_assert_eq(signal_log.size(), 1, "event_published fires on publish")
	_assert_eq(signal_log[0].payload, "ping", "signal carries correct payload")

	# publish_once.
	Bus.publish_once(&"ch_sig", "pong")
	_assert_eq(signal_log.size(), 2, "event_published fires on publish_once")

	# Middleware drop — signal must still fire.
	Bus.add_middleware(func(_c: StringName, _p: Variant) -> Variant: return null)
	Bus.publish(&"ch_sig", "dropped_but_signalled")
	_assert_eq(signal_log.size(), 3, "event_published fires even when middleware drops")
	_assert_eq(signal_log[2].payload, "dropped_but_signalled", "dropped payload in signal")

	Bus.clear_middleware()
	Bus.event_published.disconnect(on_published)
	Bus.clear_channel(&"ch_sig")


func _test_dead_object_pruning() -> void:
	_suite("dead object auto-pruning")

	Bus.clear_channel(&"ch_dead")

	# Create a Node, subscribe its method, then free it.
	var node := Node.new()
	add_child(node)                            # give it a valid state
	Bus.subscribe(&"ch_dead", Callable(node, "get_name"))
	_assert_eq(Bus.subscription_count(&"ch_dead"), 1, "subscription registered")

	node.queue_free()
	# Process one frame so queue_free actually frees the object.
	await get_tree().process_frame

	# Publishing must not crash.
	Bus.publish(&"ch_dead", null)
	_assert(true, "publish after object freed does not crash")

	# subscription_count prunes and should return 0.
	_assert_eq(Bus.subscription_count(&"ch_dead"), 0, "dead subscription auto-pruned")


func _test_clear_channel() -> void:
	_suite("clear_channel")

	Bus.clear_channel(&"ch_clear")
	var r := Receiver.new()
	Bus.subscribe(&"ch_clear", Callable(r, "on_event"))
	Bus.subscribe(&"ch_clear", Callable(r, "on_event"))
	_assert_eq(Bus.subscription_count(&"ch_clear"), 2, "two subs before clear")

	Bus.clear_channel(&"ch_clear")
	_assert_eq(Bus.subscription_count(&"ch_clear"), 0, "zero subs after clear_channel")

	Bus.publish(&"ch_clear", "noop")
	_assert_eq(r.calls.size(), 0, "publish on cleared channel does nothing")


func _test_clear_middleware() -> void:
	_suite("clear_middleware")

	Bus.clear_channel(&"ch_mw_clear")
	Bus.clear_middleware()

	var r := Receiver.new()
	Bus.subscribe(&"ch_mw_clear", Callable(r, "on_event"))

	Bus.add_middleware(func(_c: StringName, _p: Variant) -> Variant: return null)
	Bus.publish(&"ch_mw_clear", 1)
	_assert_eq(r.calls.size(), 0, "middleware dropped event")

	Bus.clear_middleware()
	Bus.publish(&"ch_mw_clear", 2)
	_assert_eq(r.calls.size(), 1, "event passes through after clear_middleware")

	Bus.clear_channel(&"ch_mw_clear")


func _test_subscription_count() -> void:
	_suite("subscription_count")

	Bus.clear_channel(&"ch_count")
	_assert_eq(Bus.subscription_count(&"ch_count"), 0, "empty channel returns 0")

	var r := Receiver.new()
	var id1 := Bus.subscribe(&"ch_count", Callable(r, "on_event"))
	_assert_eq(Bus.subscription_count(&"ch_count"), 1, "count is 1 after one subscribe")

	var id2 := Bus.subscribe(&"ch_count", Callable(r, "on_event"))
	_assert_eq(Bus.subscription_count(&"ch_count"), 2, "count is 2 after two subscribes")

	Bus.unsubscribe(id1)
	_assert_eq(Bus.subscription_count(&"ch_count"), 1, "count is 1 after one unsubscribe")

	Bus.unsubscribe(id2)
	_assert_eq(Bus.subscription_count(&"ch_count"), 0, "count is 0 after all unsubscribed")
