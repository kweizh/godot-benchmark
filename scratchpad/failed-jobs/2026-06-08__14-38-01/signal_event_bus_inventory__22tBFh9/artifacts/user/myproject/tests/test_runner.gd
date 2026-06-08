extends Node

func _ready() -> void:
	print("--- Starting Inventory Tests ---")
	
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus == null:
		print("ERROR: EventBus autoload not found!")
		get_tree().quit(1)
		return
	else:
		print("EventBus successfully loaded as autoload!")

	var InventoryScript = load("res://scripts/Inventory.gd")
	var inventory = InventoryScript.new()
	add_child(inventory)
	
	var changed_emitted = false
	var last_snapshot = {}
	var full_emitted = false
	
	event_bus.inventory_changed.connect(func(snapshot):
		changed_emitted = true
		last_snapshot = snapshot
	)
	
	event_bus.inventory_full.connect(func():
		full_emitted = true
	)
	
	# Test 1: Pick up an item
	print("Test 1: Pick up item_a x5")
	event_bus.item_picked_up.emit("item_a", 5)
	assert(changed_emitted == true, "inventory_changed should be emitted")
	assert(last_snapshot.get("item_a") == 5, "item_a quantity should be 5")
	print("Test 1 Passed!")
	
	# Test 2: Pick up more of the same item
	changed_emitted = false
	print("Test 2: Pick up item_a x3")
	event_bus.item_picked_up.emit("item_a", 3)
	assert(changed_emitted == true, "inventory_changed should be emitted")
	assert(last_snapshot.get("item_a") == 8, "item_a quantity should be 8")
	print("Test 2 Passed!")
	
	# Test 3: Fill inventory to max_slots (8)
	print("Test 3: Fill inventory to max_slots")
	for i in range(1, 8):
		var item_name = "item_" + str(i)
		event_bus.item_picked_up.emit(item_name, 1)
	
	assert(last_snapshot.size() == 8, "Inventory should have 8 items, has: " + str(last_snapshot.size()))
	print("Inventory size is 8. Current items: ", last_snapshot.keys())
	
	# Test 4: Try to add a 9th distinct item
	full_emitted = false
	changed_emitted = false
	print("Test 4: Try to add 9th distinct item")
	event_bus.item_picked_up.emit("item_8", 1)
	assert(full_emitted == true, "inventory_full should be emitted")
	assert(changed_emitted == false, "inventory_changed should NOT be emitted")
	assert(last_snapshot.size() == 8, "Inventory size should remain 8")
	assert(not last_snapshot.has("item_8"), "item_8 should not be in inventory")
	print("Test 4 Passed!")
	
	# Test 5: Try to add more quantity to an existing item when full
	changed_emitted = false
	full_emitted = false
	print("Test 5: Try to add more of existing item_a when full")
	event_bus.item_picked_up.emit("item_a", 2)
	assert(changed_emitted == true, "inventory_changed should be emitted for existing item")
	assert(full_emitted == false, "inventory_full should NOT be emitted")
	assert(last_snapshot.get("item_a") == 10, "item_a quantity should be 10")
	print("Test 5 Passed!")
	
	# Test 6: Use an item
	changed_emitted = false
	print("Test 6: Use item_1")
	event_bus.item_used.emit("item_1")
	assert(changed_emitted == true, "inventory_changed should be emitted")
	assert(not last_snapshot.has("item_1"), "item_1 should be removed from inventory")
	assert(last_snapshot.size() == 7, "Inventory size should be 7")
	print("Test 6 Passed!")
	
	# Test 7: Pickup scene verification
	print("Test 7: Verify Pickup scene")
	var PickupScene = load("res://scenes/Pickup.tscn")
	var pickup = PickupScene.instantiate()
	pickup.item_id = "item_xyz"
	pickup.quantity = 10
	add_child(pickup)
	
	var player = Node2D.new()
	player.add_to_group("player")
	add_child(player)
	
	var pickup_detected = false
	event_bus.item_picked_up.connect(func(item_id, qty):
		if item_id == "item_xyz" and qty == 10:
			pickup_detected = true
	)
	
	pickup._on_body_entered(player)
	await get_tree().process_frame
	
	assert(pickup_detected == true, "Pickup should emit item_picked_up on player enter")
	assert(not is_instance_valid(pickup), "Pickup should be freed")
	player.free()
	print("Test 7 Passed!")
	
	# Test 8: Hotbar scene verification
	print("Test 8: Verify Hotbar scene")
	var HotbarScene = load("res://scenes/Hotbar.tscn")
	var hotbar = HotbarScene.instantiate()
	add_child(hotbar)
	
	var labels = []
	for child in hotbar.get_children():
		if child is Label:
			labels.append(child)
	assert(labels.size() == 8, "Hotbar should have 8 labels, has: " + str(labels.size()))
	
	var test_snapshot = {
		"apple": 3,
		"banana": 5
	}
	event_bus.inventory_changed.emit(test_snapshot)
	
	assert(labels[0].visible == true, "Label 1 should be visible")
	assert(labels[0].text == "apple x3", "Label 1 text should be 'apple x3'")
	assert(labels[1].visible == true, "Label 2 should be visible")
	assert(labels[1].text == "banana x5", "Label 2 text should be 'banana x5'")
	for i in range(2, 8):
		assert(labels[i].visible == false, "Label " + str(i+1) + " should be hidden")
	
	print("Test 8 Passed!")
	
	print("--- All Tests Passed Successfully! ---")
	get_tree().quit(0)
