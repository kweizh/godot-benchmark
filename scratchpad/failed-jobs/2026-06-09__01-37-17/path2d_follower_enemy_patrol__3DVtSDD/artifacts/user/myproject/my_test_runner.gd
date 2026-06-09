extends SceneTree

func _init() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	print("--- Running PatrolEnemy tests ---")
	
	var scene_path = "res://scenes/PatrolEnemy.tscn"
	var scene_resource = load(scene_path)
	if not scene_resource:
		print("FAIL: Could not load scene: ", scene_path)
		quit(1)
		return
		
	# Wait one frame to let the engine initialize nodes and bake curves
	await process_frame
	
	# Scenario 1: loop forward without wrap
	await run_scenario_1(scene_resource)
	
	# Scenario 2: loop forward with wrap
	await run_scenario_2(scene_resource)
	
	# Scenario 3: pingpong with endpoint reversal
	await run_scenario_3(scene_resource)
	
	# Scenario 4: loop reverse from the starting position
	await run_scenario_4(scene_resource)
	
	print("--- All tests completed ---")
	quit(0)

func run_scenario_1(scene_resource: PackedScene) -> void:
	print("\n[Scenario 1: loop forward without wrap]")
	var inst = scene_resource.instantiate()
	root.add_child(inst)
	
	inst.load_waypoints("res://data/waypoints.json")
	inst.set_mode("loop")
	inst.set_speed(100.0)
	inst.set_direction(1)
	
	# Wait a frame after loading waypoints to let PathFollow2D update its curve cache
	await process_frame
	
	var path_follow = inst.get_node("PathFollow2D")
	
	var emissions = []
	inst.progress_changed.connect(func(ratio):
		emissions.append(ratio)
	)
	
	# Tick 1: delta = 1.0 (travel 100.0)
	inst.tick(1.0)
	print("Tick 1 ratio: ", path_follow.progress_ratio, " (expected ~0.1111)")
	assert(abs(path_follow.progress_ratio - (100.0 / 900.0)) < 0.01)
	
	# Tick 2: delta = 2.5 (travel 250.0, total 350.0)
	inst.tick(2.5)
	print("Tick 2 ratio: ", path_follow.progress_ratio, " (expected ~0.3889)")
	assert(abs(path_follow.progress_ratio - (350.0 / 900.0)) < 0.01)
	
	print("Emissions: ", emissions, " (expected [0.3333])")
	assert(emissions.size() == 1)
	assert(abs(emissions[0] - 0.333333) < 0.01)
	
	inst.queue_free()
	print("Scenario 1 PASS")

func run_scenario_2(scene_resource: PackedScene) -> void:
	print("\n[Scenario 2: loop forward with wrap]")
	var inst = scene_resource.instantiate()
	root.add_child(inst)
	
	inst.load_waypoints("res://data/waypoints.json")
	inst.set_mode("loop")
	inst.set_speed(400.0)
	inst.set_direction(1)
	
	await process_frame
	
	var path_follow = inst.get_node("PathFollow2D")
	
	var emissions = []
	inst.progress_changed.connect(func(ratio):
		emissions.append(ratio)
	)
	
	# Tick 1: delta = 2.5 (travel 1000.0, wraps to 100.0)
	inst.tick(2.5)
	print("Tick 1 ratio: ", path_follow.progress_ratio, " (expected ~0.1111)")
	assert(abs(path_follow.progress_ratio - (100.0 / 900.0)) < 0.01)
	
	print("Emissions: ", emissions, " (expected [0.3333, 0.6667, 1.0])")
	assert(emissions.size() == 3)
	assert(abs(emissions[0] - 0.333333) < 0.01)
	assert(abs(emissions[1] - 0.666667) < 0.01)
	assert(abs(emissions[2] - 1.0) < 0.01)
	
	inst.queue_free()
	print("Scenario 2 PASS")

func run_scenario_3(scene_resource: PackedScene) -> void:
	print("\n[Scenario 3: pingpong with endpoint reversal]")
	var inst = scene_resource.instantiate()
	root.add_child(inst)
	
	inst.load_waypoints("res://data/waypoints.json")
	inst.set_mode("pingpong")
	inst.set_speed(400.0)
	inst.set_direction(1)
	
	await process_frame
	
	var path_follow = inst.get_node("PathFollow2D")
	
	var emissions = []
	inst.progress_changed.connect(func(ratio):
		emissions.append(ratio)
	)
	
	# Tick 1: delta = 2.5 (travel 1000.0, reaches 900.0, reverses, goes backward by 100.0 to 800.0)
	inst.tick(2.5)
	print("Tick 1 ratio: ", path_follow.progress_ratio, " (expected ~0.8889)")
	assert(abs(path_follow.progress_ratio - (800.0 / 900.0)) < 0.01)
	
	print("Emissions: ", emissions, " (expected [0.3333, 0.6667, 1.0])")
	assert(emissions.size() == 3)
	assert(abs(emissions[0] - 0.333333) < 0.01)
	assert(abs(emissions[1] - 0.666667) < 0.01)
	assert(abs(emissions[2] - 1.0) < 0.01)
	
	inst.queue_free()
	print("Scenario 3 PASS")

func run_scenario_4(scene_resource: PackedScene) -> void:
	print("\n[Scenario 4: loop reverse from the starting position]")
	var inst = scene_resource.instantiate()
	root.add_child(inst)
	
	inst.load_waypoints("res://data/waypoints.json")
	inst.set_mode("loop")
	inst.set_speed(100.0)
	inst.set_direction(-1)
	
	await process_frame
	
	var path_follow = inst.get_node("PathFollow2D")
	
	var emissions = []
	inst.progress_changed.connect(func(ratio):
		emissions.append(ratio)
	)
	
	# Tick 1: delta = 1.5 (travel 150.0 backwards, wraps to 750.0)
	inst.tick(1.5)
	print("Tick 1 ratio: ", path_follow.progress_ratio, " (expected ~0.8333)")
	assert(abs(path_follow.progress_ratio - (750.0 / 900.0)) < 0.01)
	
	# Tick 2: delta = 2.0 (travel 200.0 backwards, total 350.0 backwards, progress 550.0)
	inst.tick(2.0)
	print("Tick 2 ratio: ", path_follow.progress_ratio, " (expected ~0.6111)")
	assert(abs(path_follow.progress_ratio - (550.0 / 900.0)) < 0.01)
	
	print("Emissions: ", emissions, " (expected [0.6667])")
	assert(emissions.size() == 1)
	assert(abs(emissions[0] - 0.666667) < 0.01)
	
	inst.queue_free()
	print("Scenario 4 PASS")
