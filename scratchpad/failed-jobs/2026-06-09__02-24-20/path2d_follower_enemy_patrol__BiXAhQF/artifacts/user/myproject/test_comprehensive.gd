extends SceneTree

func _init() -> void:
	print("=== COMPREHENSIVE PATROL TESTS ===")
	
	# Scenario 1: Loop forward without wrap
	print("\n--- Scenario 1: Loop forward without wrap ---")
	var s1 = _make_patrol()
	s1.set_mode("loop")
	s1.set_speed(100.0)
	s1.set_direction(1)
	var s1_signals = _capture_signals(s1)
	
	s1.tick(3.0)  # 300px out of 900
	
	var pf1 = s1.get_node("PathFollow2D")
	print("progress=", pf1.progress, " progress_ratio=", pf1.progress_ratio)
	print("signals=", s1_signals)
	
	# Scenario 2: Loop forward with wrap
	print("\n--- Scenario 2: Loop forward with wrap ---")
	var s2 = _make_patrol()
	s2.set_mode("loop")
	s2.set_speed(100.0)
	s2.set_direction(1)
	var s2_signals = _capture_signals(s2)
	
	s2.tick(12.0)  # 1200px out of 900 = 1 full wrap + 300px
	
	var pf2 = s2.get_node("PathFollow2D")
	print("progress=", pf2.progress, " progress_ratio=", pf2.progress_ratio)
	print("signals=", s2_signals)
	
	# Scenario 3: Pingpong with endpoint reversal
	print("\n--- Scenario 3: Pingpong with endpoint reversal ---")
	var s3 = _make_patrol()
	s3.set_mode("pingpong")
	s3.set_speed(100.0)
	s3.set_direction(1)
	var s3_signals = _capture_signals(s3)
	
	s3.tick(12.0)  # 1200px: 900 to end, reverse, 300 back
	
	var pf3 = s3.get_node("PathFollow2D")
	print("progress=", pf3.progress, " progress_ratio=", pf3.progress_ratio)
	print("direction=", s3._direction)
	print("signals=", s3_signals)
	
	# Scenario 4: Loop reverse from starting position
	print("\n--- Scenario 4: Loop reverse from starting position ---")
	var s4 = _make_patrol()
	s4.set_mode("loop")
	s4.set_speed(100.0)
	s4.set_direction(-1)
	var s4_signals = _capture_signals(s4)
	
	s4.tick(3.0)  # 300px backward from 0
	
	var pf4 = s4.get_node("PathFollow2D")
	print("progress=", pf4.progress, " progress_ratio=", pf4.progress_ratio)
	print("signals=", s4_signals)
	
	# Additional: verify progress_ratio computation
	print("\n--- Progress Ratio Debug ---")
	var dbg = _make_patrol()
	dbg.set_mode("loop")
	dbg.set_speed(100.0)
	dbg.set_direction(1)
	var dbg_pf = dbg.get_node("PathFollow2D")
	var total_len = dbg.curve.get_baked_length()
	print("Total baked length: ", total_len)
	print("Initial progress: ", dbg_pf.progress, " ratio: ", dbg_pf.progress_ratio)
	dbg.tick(1.5)
	print("After 1.5s: progress=", dbg_pf.progress, " ratio=", dbg_pf.progress_ratio, " expected_ratio=", (150.0/total_len))
	
	print("\n=== ALL SCENARIOS COMPLETE ===")
	quit(0)


func _make_patrol():
	var scene = load("res://scenes/PatrolEnemy.tscn")
	var instance = scene.instantiate()
	instance.load_waypoints("res://data/waypoints.json")
	return instance


func _capture_signals(patrol) -> Array:
	var captured = []
	patrol.progress_changed.connect(func(r): captured.append(r))
	return captured
