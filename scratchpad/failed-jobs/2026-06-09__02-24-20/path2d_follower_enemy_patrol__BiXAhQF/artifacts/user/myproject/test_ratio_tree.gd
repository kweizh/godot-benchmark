extends SceneTree

func _init() -> void:
	print("=== RATIO DEBUG IN TREE ===")
	var scene = load("res://scenes/PatrolEnemy.tscn")
	var instance = scene.instantiate()
	root.add_child(instance)
	instance.load_waypoints("res://data/waypoints.json")
	
	var pf = instance.get_node("PathFollow2D")
	
	# Try setting progress and reading ratio
	pf.progress = 300.0
	print("After pf.progress = 300.0:")
	print("  pf.progress = ", pf.progress)
	print("  pf.progress_ratio = ", pf.progress_ratio)
	
	var total = pf.get_parent().curve.get_baked_length()
	print("  manual ratio = ", 300.0 / total)
	
	# Now test via tick
	instance.set_mode("loop")
	instance.set_speed(100.0)
	instance.set_direction(1)
	pf.progress = 0.0
	print("\nBefore tick: progress=", pf.progress, " ratio=", pf.progress_ratio)
	instance.tick(1.0)
	print("After tick 1s: progress=", pf.progress, " ratio=", pf.progress_ratio)
	
	quit(0)
