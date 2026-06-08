extends Node

## Comprehensive test suite for the Bus autoload.
## Each test logs its result. A final summary is printed at the end.

var _passed := 0
var _failed := 0


func _ready() -> void:
	print("========================================")
	print("  Bus Autoload Acceptance Test Suite")
	print("========================================")
	print("")

	_test_subscribe_and_publish()
	_test_multiple_subscribers()
	_test_unsubscribe()
	_test_publish_once()
	_test_publish_once_then_publish_again()
	_test_subscription_count()
	_test_clear_channel()
	_test_middleware_modify()
	_test_middleware_drop()
	_test_event_published_signal()
	_test_event_published_on_drop()
	_test_auto_prune_freed_object()
	_test_add_and_clear_middleware()

	print("")
	print("========================================")
	print("  RESULTS: %d passed, %d failed" % [_passed, _failed])
	print("========================================")

	if _failed > 0:
		print("SOME TESTS FAILED — exiting with code 1")
		get_tree().quit(1)
	else:
		print("ALL TESTS PASSED — exiting with code 0")
		get_tree().quit(0)


func _assert(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % description)
	else:
		_failed += 1
		print("  FAIL: %s" % description)


# ─── Test: subscribe + publish ──────────────────────────────────────────────

func _test_subscribe_and_publish() -> void:
	print("[test] subscribe + publish")
	var received = null
	var sid = Bus.subscribe(&"test1", func(p): received = p)
	Bus.publish(&"test1", "hello")
	_assert(received == "hello", "subscriber receives published payload")
	Bus.clear_channel(&"test1")


# ─── Test: multiple subscribers on same channel ─────────────────────────────

func _test_multiple_subscribers() -> void:
	print("[test] multiple subscribers")
	var results := []
	Bus.subscribe(&"test2", func(p): results.push_back("a:" + str(p)))
	Bus.subscribe(&"test2", func(p): results.push_back("b:" + str(p)))
	Bus.publish(&"test2", 42)
	_assert(results.has("a:42"), "first subscriber received payload")
	_assert(results.has("b:42"), "second subscriber received payload")
	_assert(results.size() == 2, "exactly two subscribers invoked")
	Bus.clear_channel(&"test2")


# ─── Test: unsubscribe ──────────────────────────────────────────────────────

func _test_unsubscribe() -> void:
	print("[test] unsubscribe")
	var results := []
	var sid_a = Bus.subscribe(&"test3", func(p): results.push_back("a"))
	var sid_b = Bus.subscribe(&"test3", func(p): results.push_back("b"))
	var ok = Bus.unsubscribe(sid_a)
	_assert(ok, "unsubscribe returns true for valid id")
	Bus.publish(&"test3", null)
	_assert(results == ["b"], "only remaining subscriber invoked after unsubscribe")
	_assert(not Bus.unsubscribe(99999), "unsubscribe returns false for invalid id")
	Bus.clear_channel(&"test3")


# ─── Test: publish_once invokes then removes subscribers ────────────────────

func _test_publish_once() -> void:
	print("[test] publish_once")
	var results := []
	Bus.subscribe(&"test4", func(p): results.push_back("a:" + str(p)))
	Bus.subscribe(&"test4", func(p): results.push_back("b:" + str(p)))
	Bus.publish_once(&"test4", 99)
	_assert(results.has("a:99"), "publish_once invokes first subscriber")
	_assert(results.has("b:99"), "publish_once invokes second subscriber")
	_assert(results.size() == 2, "publish_once invokes exactly two subscribers")
	_assert(Bus.subscription_count(&"test4") == 0, "publish_once removes all subscribers")


# ─── Test: publish_once then publish again — no subscribers remain ──────────

func _test_publish_once_then_publish_again() -> void:
	print("[test] publish_once then publish again")
	var results := []
	Bus.subscribe(&"test5", func(p): results.push_back("x"))
	Bus.publish_once(&"test5", null)
	results.clear()
	Bus.publish(&"test5", null)
	_assert(results.is_empty(), "publish after publish_once invokes no subscribers")


# ─── Test: subscription_count ───────────────────────────────────────────────

func _test_subscription_count() -> void:
	print("[test] subscription_count")
	_assert(Bus.subscription_count(&"nonexistent") == 0, "count is 0 for nonexistent channel")
	var s1 = Bus.subscribe(&"test6", func(p): pass)
	var s2 = Bus.subscribe(&"test6", func(p): pass)
	_assert(Bus.subscription_count(&"test6") == 2, "count reflects two subscribers")
	Bus.unsubscribe(s1)
	_assert(Bus.subscription_count(&"test6") == 1, "count decrements after unsubscribe")
	Bus.clear_channel(&"test6")


# ─── Test: clear_channel ────────────────────────────────────────────────────

func _test_clear_channel() -> void:
	print("[test] clear_channel")
	var results := []
	Bus.subscribe(&"test7", func(p): results.push_back("a"))
	Bus.subscribe(&"test7", func(p): results.push_back("b"))
	Bus.clear_channel(&"test7")
	_assert(Bus.subscription_count(&"test7") == 0, "clear_channel removes all subscribers")
	Bus.publish(&"test7", null)
	_assert(results.is_empty(), "publish after clear_channel invokes no subscribers")


# ─── Test: middleware modifies payload ──────────────────────────────────────

func _test_middleware_modify() -> void:
	print("[test] middleware — modify payload")
	var received = null
	Bus.add_middleware(func(ch, p): return str(p) + "_modified")
	Bus.subscribe(&"test8", func(p): received = p)
	Bus.publish(&"test8", "original")
	_assert(received == "original_modified", "middleware-modified payload reaches subscriber")
	Bus.clear_middleware()
	Bus.clear_channel(&"test8")


# ─── Test: middleware drops event (returns null) ────────────────────────────

func _test_middleware_drop() -> void:
	print("[test] middleware — drop event")
	var received = null
	Bus.add_middleware(func(ch, p): return null)
	Bus.subscribe(&"test9", func(p): received = p)
	Bus.publish(&"test9", "should_not_arrive")
	_assert(received == null, "subscriber NOT invoked when middleware drops event")
	Bus.clear_middleware()
	Bus.clear_channel(&"test9")


# ─── Test: event_published signal fires on publish ──────────────────────────

func _test_event_published_signal() -> void:
	print("[test] event_published signal")
	var captured_channel = null
	var captured_payload = null
	Bus.event_published.connect(func(ch, p):
		captured_channel = ch
		captured_payload = p
	, CONNECT_ONE_SHOT)
	Bus.publish(&"test10", "sig_payload")
	_assert(captured_channel == &"test10", "event_published captures correct channel")
	_assert(captured_payload == "sig_payload", "event_published captures correct payload")
	Bus.clear_channel(&"test10")


# ─── Test: event_published fires even when middleware drops ─────────────────

func _test_event_published_on_drop() -> void:
	print("[test] event_published fires on middleware drop")
	var signal_fired := false
	Bus.add_middleware(func(ch, p): return null)
	Bus.subscribe(&"test11", func(p): pass)
	Bus.event_published.connect(func(_ch, _p): signal_fired = true, CONNECT_ONE_SHOT)
	Bus.publish(&"test11", "dropped")
	_assert(signal_fired, "event_published fires even when middleware drops the event")
	Bus.clear_middleware()
	Bus.clear_channel(&"test11")


# ─── Test: auto-prune freed Object-bound callables ──────────────────────────

func _test_auto_prune_freed_object() -> void:
	print("[test] auto-prune freed Object")
	var obj := Node.new()
	var received = null
	# Bind to a method on obj so the Callable is tied to the object.
	obj.connect("tree_entered", func(): pass)  # dummy, just to have a signal
	# Use a lambda that captures obj to create a bound callable.
	var sid = Bus.subscribe(&"test12", func(p):
		received = p
	)
	# Now free the object that the lambda captured — but since lambdas in GDScript
	# don't bind to the object they're defined in, we need a different approach.
	# We'll use obj.call_deferred.bind("free") type pattern, but instead let's
	# use a callable that is explicitly bound to obj via Callable.bind().
	# Actually, the cleanest test: create a RefCounted, subscribe a method of it,
	# then let it go out of scope.

	# Let's use a RefCounted approach:
	var rc := RefCounted.new()
	var callable_ref = rc  # capture
	var sid_rc = Bus.subscribe(&"test13", func(p):
		callable_ref  # keep ref alive inside lambda
	)
	# This won't free since the lambda captures rc. Let's use a different strategy.
	Bus.clear_channel(&"test13")

	# Strategy: subscribe a Callable that IS a method on a freed Object.
	var obj2 := Node.new()
	# We'll call a method on obj2 by subscribing with obj2.method_name.
	# But we need a method... let's add a script dynamically.
	# Simpler: use obj2 as a target for a signal connection approach.
	# The simplest valid test: create a Node, subscribe with a callable
	# that references it, free the node, then check subscription_count.

	# Use obj2 with set_meta / get_meta — but those aren't Callables.
	# Let's use the approach of subscribing with a Callable created from
	# Callable(obj2, "queue_free") — no, that's weird.
	#
	# Best approach: create a small helper object with a method, subscribe
	# that method, then free the object.

	var helper := _TestHelper.new()
	var helper_sid = Bus.subscribe(&"test14", helper.on_event)
	_assert(Bus.subscription_count(&"test14") == 1, "subscription registered for bound object")
	helper.free()
	# Wait a frame so the free propagates.
	await get_tree().process_frame
	_assert(Bus.subscription_count(&"test14") == 0, "freed-object subscription is auto-pruned from count")
	# Publishing should not crash.
	Bus.publish(&"test14", "safe")
	_assert(true, "publishing after object freed does not crash")
	Bus.clear_channel(&"test14")


# ─── Test: add_middleware + clear_middleware ────────────────────────────────

func _test_add_and_clear_middleware() -> void:
	print("[test] add_middleware / clear_middleware")
	var received = null
	Bus.add_middleware(func(ch, p): return str(p) + "_mw")
	Bus.subscribe(&"test15", func(p): received = p)
	Bus.publish(&"test15", "x")
	_assert(received == "x_mw", "middleware applied")
	Bus.clear_middleware()
	received = null
	Bus.publish(&"test15", "y")
	_assert(received == "y", "middleware no longer applied after clear")
	Bus.clear_channel(&"test15")


# ─── Helper class for testing object-bound callable lifecycle ───────────────

class _TestHelper:
	extends RefCounted

	func on_event(_payload: Variant) -> void:
		pass
