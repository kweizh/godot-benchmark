# test.gd
extends SceneTree

func _init() -> void:
	print("--- Starting Event Bus Tests ---")
	
	var BusScript = preload("res://autoloads/Bus.gd")
	var bus = BusScript.new()
	if bus == null:
		print("FAIL: Bus could not be instantiated")
		quit(1)
		return
		
	# Add bus to root to simulate autoload/node lifecycle if needed
	root.add_child(bus)
	
	test_basic_subscription_and_publish(bus)
	test_multiple_subscribers(bus)
	test_unsubscribe(bus)
	test_publish_once(bus)
	test_middleware_drop(bus)
	test_middleware_modification(bus)
	test_auto_pruning(bus)
	test_clear_channel(bus)
	test_clear_middleware(bus)
	
	print("--- All Tests Passed Successfully! ---")
	quit(0)

# Helper to assert conditions
func assert_true(cond: bool, msg: String) -> void:
	if not cond:
		print("ASSERTION FAILED: ", msg)
		OS.kill(OS.get_process_id()) # Force immediate exit on failure

func assert_eq(val1: Variant, val2: Variant, msg: String) -> void:
	if val1 != val2:
		print("ASSERTION FAILED: ", msg, " (Expected: ", val2, ", Got: ", val1, ")")
		OS.kill(OS.get_process_id()) # Force immediate exit on failure

func test_basic_subscription_and_publish(bus: Bus) -> void:
	print("Running test_basic_subscription_and_publish...")
	var called_payload = [null]
	var callable = func(payload):
		called_payload[0] = payload
		
	var sub_id = bus.subscribe(&"test_channel", callable)
	assert_true(sub_id > 0, "Subscription ID should be positive")
	assert_eq(bus.subscription_count(&"test_channel"), 1, "Subscription count should be 1")
	
	# Set up signal listener
	var signal_received = [false]
	var signal_channel = [&""]
	var signal_payload = [null]
	var on_event_published = func(channel, payload):
		signal_received[0] = true
		signal_channel[0] = channel
		signal_payload[0] = payload
	bus.event_published.connect(on_event_published)
	
	bus.publish(&"test_channel", "hello")
	assert_eq(called_payload[0], "hello", "Subscriber should receive the payload")
	assert_true(signal_received[0], "event_published signal should be emitted")
	assert_eq(signal_channel[0], &"test_channel", "Signal channel should match")
	assert_eq(signal_payload[0], "hello", "Signal payload should match")
	
	# Clean up
	bus.unsubscribe(sub_id)
	bus.event_published.disconnect(on_event_published)
	assert_eq(bus.subscription_count(&"test_channel"), 0, "Subscription count should be 0")

func test_multiple_subscribers(bus: Bus) -> void:
	print("Running test_multiple_subscribers...")
	var count_a = [0]
	var count_b = [0]
	var call_a = func(p): count_a[0] += 1
	var call_b = func(p): count_b[0] += 1
	
	var sub_a = bus.subscribe(&"multi", call_a)
	var sub_b = bus.subscribe(&"multi", call_b)
	
	assert_eq(bus.subscription_count(&"multi"), 2, "Should have 2 subscribers")
	
	bus.publish(&"multi", "go")
	assert_eq(count_a[0], 1, "Subscriber A should be invoked once")
	assert_eq(count_b[0], 1, "Subscriber B should be invoked once")
	
	bus.unsubscribe(sub_a)
	bus.unsubscribe(sub_b)

func test_unsubscribe(bus: Bus) -> void:
	print("Running test_unsubscribe...")
	var count = [0]
	var callable = func(p): count[0] += 1
	
	var sub_id = bus.subscribe(&"unsub", callable)
	assert_eq(bus.subscription_count(&"unsub"), 1, "Should have 1 subscriber")
	
	bus.publish(&"unsub", "first")
	assert_eq(count[0], 1, "Should have been invoked once")
	
	var unsub_success = bus.unsubscribe(sub_id)
	assert_true(unsub_success, "Unsubscribe should return true for valid subscription")
	assert_eq(bus.subscription_count(&"unsub"), 0, "Should have 0 subscribers after unsubscribe")
	
	bus.publish(&"unsub", "second")
	assert_eq(count[0], 1, "Should not be invoked after unsubscribe")
	
	var unsub_fail = bus.unsubscribe(sub_id)
	assert_true(not unsub_fail, "Unsubscribe should return false for already unsubscribed id")

func test_publish_once(bus: Bus) -> void:
	print("Running test_publish_once...")
	var count_a = [0]
	var count_b = [0]
	var call_a = func(p): count_a[0] += 1
	var call_b = func(p): count_b[0] += 1
	
	bus.subscribe(&"once", call_a)
	bus.subscribe(&"once", call_b)
	
	assert_eq(bus.subscription_count(&"once"), 2, "Should have 2 subscribers before publish_once")
	
	bus.publish_once(&"once", "now")
	assert_eq(count_a[0], 1, "Subscriber A should be invoked once")
	assert_eq(count_b[0], 1, "Subscriber B should be invoked once")
	assert_eq(bus.subscription_count(&"once"), 0, "Should have 0 subscribers after publish_once")
	
	bus.publish(&"once", "again")
	assert_eq(count_a[0], 1, "Subscriber A should not be invoked again")
	assert_eq(count_b[0], 1, "Subscriber B should not be invoked again")

func test_middleware_drop(bus: Bus) -> void:
	print("Running test_middleware_drop...")
	var count = [0]
	var callable = func(p): count[0] += 1
	var sub_id = bus.subscribe(&"drop_chan", callable)
	
	# Middleware that drops event if payload is "drop"
	var middleware = func(channel, payload):
		if payload == "drop":
			return null
		return payload
		
	bus.add_middleware(middleware)
	
	# Set up signal listener
	var signal_received = [false]
	var on_event_published = func(channel, payload):
		signal_received[0] = true
	bus.event_published.connect(on_event_published)
	
	# Publish non-drop payload
	bus.publish(&"drop_chan", "keep")
	assert_eq(count[0], 1, "Should invoke subscriber for non-drop payload")
	assert_true(signal_received[0], "Signal should fire")
	
	signal_received[0] = false
	# Publish drop payload
	bus.publish(&"drop_chan", "drop")
	assert_eq(count[0], 1, "Should NOT invoke subscriber for dropped payload")
	assert_true(signal_received[0], "Signal should STILL fire even when middleware drops")
	
	# Clean up
	bus.unsubscribe(sub_id)
	bus.clear_middleware()
	bus.event_published.disconnect(on_event_published)

func test_middleware_modification(bus: Bus) -> void:
	print("Running test_middleware_modification...")
	var received_payload = [null]
	var callable = func(p): received_payload[0] = p
	var sub_id = bus.subscribe(&"modify_chan", callable)
	
	# Middleware that appends "_modified" to string payloads
	var middleware = func(channel, payload):
		if payload is String:
			return payload + "_modified"
		return payload
		
	bus.add_middleware(middleware)
	
	bus.publish(&"modify_chan", "hello")
	assert_eq(received_payload[0], "hello_modified", "Subscriber should receive modified payload")
	
	# Clean up
	bus.unsubscribe(sub_id)
	bus.clear_middleware()

func test_auto_pruning(bus: Bus) -> void:
	print("Running test_auto_pruning...")
	# Create a dummy object
	var target_node = Node.new()
	var callable_bound = Callable(target_node, "get_name")
	
	var sub_id = bus.subscribe(&"prune_chan", callable_bound)
	assert_eq(bus.subscription_count(&"prune_chan"), 1, "Should have 1 subscriber initially")
	
	# Free the object
	target_node.free()
	
	# Now the Callable is bound to a freed object.
	# Let's verify that subscription_count auto-prunes it!
	var count_after = bus.subscription_count(&"prune_chan")
	assert_eq(count_after, 0, "Subscription should be auto-pruned and count should be 0")
	
	# Publishing should not crash
	bus.publish(&"prune_chan", "test")

func test_clear_channel(bus: Bus) -> void:
	print("Running test_clear_channel...")
	var count = [0]
	var callable = func(p): count[0] += 1
	bus.subscribe(&"clear_chan", callable)
	bus.subscribe(&"clear_chan", callable)
	
	assert_eq(bus.subscription_count(&"clear_chan"), 2, "Should have 2 subscribers")
	bus.clear_channel(&"clear_chan")
	assert_eq(bus.subscription_count(&"clear_chan"), 0, "Should have 0 subscribers after clear")

func test_clear_middleware(bus: Bus) -> void:
	print("Running test_clear_middleware...")
	var count = [0]
	var callable = func(p): count[0] += 1
	var sub_id = bus.subscribe(&"mid_clear_chan", callable)
	
	var middleware = func(channel, payload):
		return null # Drops everything
		
	bus.add_middleware(middleware)
	bus.publish(&"mid_clear_chan", "test")
	assert_eq(count[0], 0, "Should be dropped by middleware")
	
	bus.clear_middleware()
	bus.publish(&"mid_clear_chan", "test")
	assert_eq(count[0], 1, "Should be invoked after clearing middleware")
	
	bus.unsubscribe(sub_id)
