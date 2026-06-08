extends SceneTree

## Integration test for the Bus autoload.
## Run with: godot --headless --script res://tests/test_bus.gd

var _pass_count: int = 0
var _fail_count: int = 0

func _init() -> void:
	# Wait one frame so autoloads are fully initialised.
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)

func _run_tests() -> void:
	print("\n========== Bus Autoload Tests ==========\n")

	test_subscribe_and_publish()
	test_subscribe_twice_publish_invokes_both()
	test_unsubscribe_one_remaining_invoked()
	test_publish_once_invokes_then_clears()
	test_middleware_null_drops_dispatch_signal_still_fires()
	test_middleware_modifies_payload()
	test_freed_object_auto_prune()
	test_clear_channel()
	test_clear_middleware()
	test_subscription_count()

	print("\n========== Results ==========")
	print("Passed: %d  |  Failed: %d" % [_pass_count, _fail_count])
	if _fail_count > 0:
		print("SOME TESTS FAILED")
	else:
		print("ALL TESTS PASSED")
	quit()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func assert_true(condition: bool, description: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % description)
	else:
		_fail_count += 1
		push_error("  FAIL: %s" % description)
		print("  FAIL: %s" % description)

func assert_eq(actual: Variant, expected: Variant, description: String) -> void:
	assert_true(actual == expected, "%s (expected %s, got %s)" % [description, expected, actual])

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_subscribe_and_publish() -> void:
	print("[test_subscribe_and_publish]")
	var received: Array = []
	var id: int = Bus.subscribe(&"test_channel", func(p): received.append(p))
	assert_true(id > 0, "subscribe returns a positive id")
	Bus.publish(&"test_channel", 42)
	assert_eq(received.size(), 1, "subscriber invoked once")
	assert_eq(received[0], 42, "payload received correctly")
	Bus.clear_channel(&"test_channel")

func test_subscribe_twice_publish_invokes_both() -> void:
	print("[test_subscribe_twice_publish_invokes_both]")
	var a: Array = []
	var b: Array = []
	Bus.subscribe(&"dual", func(p): a.append(p))
	Bus.subscribe(&"dual", func(p): b.append(p))
	Bus.publish(&"dual", "hello")
	assert_eq(a.size(), 1, "first subscriber invoked")
	assert_eq(b.size(), 1, "second subscriber invoked")
	assert_eq(a[0], "hello", "first subscriber payload")
	assert_eq(b[0], "hello", "second subscriber payload")
	Bus.clear_channel(&"dual")

func test_unsubscribe_one_remaining_invoked() -> void:
	print("[test_unsubscribe_one_remaining_invoked]")
	var a: Array = []
	var b: Array = []
	var id_a: int = Bus.subscribe(&"unsub", func(p): a.append(p))
	var id_b: int = Bus.subscribe(&"unsub", func(p): b.append(p))
	var removed: bool = Bus.unsubscribe(id_a)
	assert_true(removed, "unsubscribe returns true for valid id")
	Bus.publish(&"unsub", 99)
	assert_eq(a.size(), 0, "unsubscribed callable NOT invoked")
	assert_eq(b.size(), 1, "remaining callable invoked")
	assert_eq(b[0], 99, "remaining callable payload correct")
	Bus.clear_channel(&"unsub")

func test_publish_once_invokes_then_clears() -> void:
	print("[test_publish_once_invokes_then_clears]")
	var a: Array = []
	var b: Array = []
	Bus.subscribe(&"once", func(p): a.append(p))
	Bus.subscribe(&"once", func(p): b.append(p))
	Bus.publish_once(&"once", "fire")
	assert_eq(a.size(), 1, "first subscriber invoked by publish_once")
	assert_eq(b.size(), 1, "second subscriber invoked by publish_once")
	assert_eq(Bus.subscription_count(&"once"), 0, "channel cleared after publish_once")
	# Subsequent publish should invoke nobody.
	Bus.publish(&"once", "again")
	assert_eq(a.size(), 1, "first subscriber NOT invoked after clear")
	assert_eq(b.size(), 1, "second subscriber NOT invoked after clear")

func test_middleware_null_drops_dispatch_signal_still_fires() -> void:
	print("[test_middleware_null_drops_dispatch_signal_still_fires]")
	var received: Array = []
	var signal_received: Array = []
	var sig_handler: Callable = func(ch: StringName, p: Variant): signal_received.append([ch, p])
	Bus.subscribe(&"drop_test", func(p): received.append(p))
	Bus.event_published.connect(sig_handler)
	Bus.add_middleware(func(_ch: StringName, _p: Variant): return null)  # drop everything
	Bus.publish(&"drop_test", "dropped")
	assert_eq(received.size(), 0, "subscriber NOT invoked when middleware returns null")
	assert_eq(signal_received.size(), 1, "event_published signal still fires")
	assert_eq(signal_received[0][0], &"drop_test", "signal channel correct")
	assert_eq(signal_received[0][1], "dropped", "signal payload correct (original)")
	Bus.clear_middleware()
	Bus.clear_channel(&"drop_test")
	Bus.event_published.disconnect(sig_handler)

func test_middleware_modifies_payload() -> void:
	print("[test_middleware_modifies_payload]")
	var received: Array = []
	Bus.subscribe(&"modify_test", func(p): received.append(p))
	# Middleware doubles integers.
	Bus.add_middleware(func(_ch: StringName, p: Variant): return p * 2)
	Bus.publish(&"modify_test", 5)
	assert_eq(received.size(), 1, "subscriber invoked")
	assert_eq(received[0], 10, "subscriber received modified payload (5*2=10)")
	Bus.clear_middleware()
	Bus.clear_channel(&"modify_test")

func test_freed_object_auto_prune() -> void:
	print("[test_freed_object_auto_prune]")
	Bus.clear_channel(&"prune_test")

	var alive_data: Array = []
	var alive_node: Node = Node.new()

	# Subscribe with alive node's method using a lambda that captures alive_node
	var sub_alive: int = Bus.subscribe(&"prune_test", func(p): alive_data.append(p))

	# Create a node that we will free. Subscribe with a callable that
	# references the node so freeing it invalidates the callable.
	var dead_node: Node = Node.new()
	var dead_data: Array = []
	var sub_dead: int = Bus.subscribe(&"prune_test", func(p): dead_data.append(p); dead_node.name = str(p))

	assert_eq(Bus.subscription_count(&"prune_test"), 2, "two subscribers before free")

	# Free the dead node — the lambda capturing dead_node will fail when invoked
	dead_node.free()

	# Publish should not crash and should auto-prune the dead subscription
	Bus.publish(&"prune_test", "test_payload")

	assert_eq(alive_data.size(), 1, "alive subscriber still invoked")
	assert_eq(alive_data[0], "test_payload", "alive subscriber received payload")
	assert_eq(Bus.subscription_count(&"prune_test"), 1, "dead subscription auto-pruned")

	alive_node.free()
	Bus.clear_channel(&"prune_test")

func test_clear_channel() -> void:
	print("[test_clear_channel]")
	Bus.subscribe(&"to_clear", func(_p): pass)
	Bus.subscribe(&"to_clear", func(_p): pass)
	assert_eq(Bus.subscription_count(&"to_clear"), 2, "two subscribers before clear")
	Bus.clear_channel(&"to_clear")
	assert_eq(Bus.subscription_count(&"to_clear"), 0, "zero subscribers after clear")

func test_clear_middleware() -> void:
	print("[test_clear_middleware]")
	Bus.add_middleware(func(_ch: StringName, p: Variant): return p)
	Bus.add_middleware(func(_ch: StringName, p: Variant): return p)
	Bus.clear_middleware()
	# If clear worked, no crash on publish (middleware array is empty)
	var received: Array = []
	Bus.subscribe(&"mw_clear", func(p): received.append(p))
	Bus.publish(&"mw_clear", "ok")
	assert_eq(received.size(), 1, "publish works after clear_middleware")
	Bus.clear_channel(&"mw_clear")

func test_subscription_count() -> void:
	print("[test_subscription_count]")
	assert_eq(Bus.subscription_count(&"nonexistent"), 0, "nonexistent channel returns 0")
	var id1: int = Bus.subscribe(&"count_test", func(_p): pass)
	assert_eq(Bus.subscription_count(&"count_test"), 1, "one subscriber")
	var id2: int = Bus.subscribe(&"count_test", func(_p): pass)
	assert_eq(Bus.subscription_count(&"count_test"), 2, "two subscribers")
	Bus.unsubscribe(id1)
	assert_eq(Bus.subscription_count(&"count_test"), 1, "one after unsubscribe")
	Bus.unsubscribe(id2)
	assert_eq(Bus.subscription_count(&"count_test"), 0, "zero after all unsubscribed")