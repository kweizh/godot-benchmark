extends Node

func _ready():
	var bus = get_node("/root/Bus")
	
	# Test subscribe and publish
	var state = {"called1": 0, "called2": 0, "called3": 0, "called4": 0, "called5": 0, "mw_called": 0}
	
	var sub1 = bus.subscribe("test_pub", func(p): state.called1 += 1)
	var sub2 = bus.subscribe("test_pub", func(p): state.called2 += 1)
	bus.publish("test_pub", "hello")
	assert(state.called1 == 1 and state.called2 == 1, "Both should be called")
	
	# Test unsubscribe
	bus.unsubscribe(sub1)
	bus.publish("test_pub", "hello")
	assert(state.called1 == 1 and state.called2 == 2, "Only sub2 should be called")
	
	# Test publish_once
	bus.subscribe("test_once", func(p): state.called3 += 1)
	bus.subscribe("test_once", func(p): state.called4 += 1)
	bus.publish_once("test_once", "hello")
	assert(state.called3 == 1 and state.called4 == 1, "Both should be called once")
	bus.publish("test_once", "hello")
	assert(state.called3 == 1 and state.called4 == 1, "Neither should be called again")
	
	# Test middleware drop
	var mw1 = func(c, p):
		state.mw_called += 1
		return null
	bus.add_middleware(mw1)
	bus.subscribe("test_mw", func(p): state.called5 += 1)
	bus.publish("test_mw", "hello")
	assert(state.mw_called == 1, "Middleware should be called")
	assert(state.called5 == 0, "Subscriber should not be called due to drop")
	
	# Test middleware modify
	bus.clear_middleware()
	var mw2 = func(c, p):
		return p + " world"
	bus.add_middleware(mw2)
	var modified_payload = ""
	bus.subscribe("test_mw2", func(p): modified_payload = p)
	bus.publish("test_mw2", "hello")
	assert(modified_payload == "hello world", "Payload should be modified")
	
	# Test auto-prune
	var obj = Node.new()
	bus.subscribe("test_prune", obj.set_name)
	assert(bus.subscription_count("test_prune") == 1, "Should have 1 sub")
	obj.free()
	assert(bus.subscription_count("test_prune") == 0, "Should have 0 subs after free")
	bus.publish("test_prune", "hello") # Should not crash
	
	# Test signal
	var sig_called = [0]
	bus.event_published.connect(func(c, p): sig_called[0] += 1)
	bus.publish("test_sig", "hello")
	assert(sig_called[0] == 1, "Signal should be emitted")
	
	print("All tests passed!")
	get_tree().quit()
