extends SceneTree

func _init() -> void:
	print("=== Testing PatrolEnemy scene load ===")
	
	var scene = load("res://scenes/PatrolEnemy.tscn")
	if scene == null:
		print("FAIL: Could not load scene")
		quit(1)
		return
	
	var instance = scene.instantiate()
	print("Scene instantiated: ", instance.name, " type=", instance.get_class())
	
	# Verify node tree
	var path_follow = instance.get_node_or_null("PathFollow2D")
	if path_follow == null:
		print("FAIL: No PathFollow2D child")
		quit(1)
		return
	print("PathFollow2D found: ", path_follow.get_class())
	
	var enemy = path_follow.get_node_or_null("Enemy")
	if enemy == null:
		print("FAIL: No Enemy child under PathFollow2D")
		quit(1)
		return
	print("Enemy found: ", enemy.get_class())
	
	# Verify script methods exist
	print("Has load_waypoints: ", instance.has_method("load_waypoints"))
	print("Has set_mode: ", instance.has_method("set_mode"))
	print("Has set_speed: ", instance.has_method("set_speed"))
	print("Has set_direction: ", instance.has_method("set_direction"))
	print("Has tick: ", instance.has_method("tick"))
	
	# Verify signal
	var signals = instance.get_signal_list()
	var has_signal = false
	for s in signals:
		if s["name"] == "progress_changed":
			has_signal = true
			break
	print("Has progress_changed signal: ", has_signal)
	
	# Test load_waypoints
	instance.load_waypoints("res://data/waypoints.json")
	print("Curve point count after load: ", instance.curve.get_point_count())
	print("PathFollow2D progress: ", path_follow.progress)
	
	# Test basic tick
	instance.set_mode("loop")
	instance.set_speed(100.0)
	instance.set_direction(1)
	
	# Connect to signal
	var captured = []
	instance.progress_changed.connect(func(r): captured.append(r))
	
	instance.tick(1.0)
	print("After tick 1s at 100px/s: progress=", path_follow.progress, " progress_ratio=", path_follow.progress_ratio)
	print("Captured signals: ", captured)
	
	# Test pingpong
	instance.set_mode("pingpong")
	instance.load_waypoints("res://data/waypoints.json")
	instance.set_speed(100.0)
	instance.set_direction(1)
	captured.clear()
	
	# 4 waypoints = 3 segments, total length = 300+300+300 = 900
	# tick 9 seconds at 100px/s = 900px = exactly to end
	instance.tick(9.0)
	print("After pingpong tick 9s: progress=", path_follow.progress, " progress_ratio=", path_follow.progress_ratio)
	print("Captured signals: ", captured)
	
	# tick more to test reversal
	instance.tick(3.0)
	print("After pingpong tick +3s: progress=", path_follow.progress, " progress_ratio=", path_follow.progress_ratio)
	
	print("=== ALL TESTS PASSED ===")
	quit(0)
