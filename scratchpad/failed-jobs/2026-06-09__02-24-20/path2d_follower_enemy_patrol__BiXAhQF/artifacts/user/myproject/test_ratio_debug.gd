extends SceneTree

func _init() -> void:
	print("=== RATIO DEBUG ===")
	var scene = load("res://scenes/PatrolEnemy.tscn")
	var instance = scene.instantiate()
	instance.load_waypoints("res://data/waypoints.json")
	
	var pf = instance.get_node("PathFollow2D")
	print("pf.get_parent() = ", pf.get_parent())
	print("pf.get_parent().name = ", pf.get_parent().name)
	print("pf.get_parent().curve = ", pf.get_parent().curve)
	print("curve.get_baked_length() = ", pf.get_parent().curve.get_baked_length())
	
	# Try setting progress and reading ratio
	pf.progress = 300.0
	print("After pf.progress = 300.0:")
	print("  pf.progress = ", pf.progress)
	print("  pf.progress_ratio = ", pf.progress_ratio)
	print("  pf.get('progress_ratio') = ", pf.get("progress_ratio"))
	
	# Check if it's a getter issue
	var total = pf.get_parent().curve.get_baked_length()
	print("  manual ratio = ", 300.0 / total)
	
	quit(0)
