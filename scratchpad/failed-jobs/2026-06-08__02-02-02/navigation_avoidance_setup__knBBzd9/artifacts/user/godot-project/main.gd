extends Node2D

var agent: CharacterBody2D
var path_log: Array = []
var time_elapsed: float = 0.0
var simulation_done: bool = false

func _ready():
	# 1. Create NavigationRegion2D with NavigationPolygon
	var nav_region = NavigationRegion2D.new()
	var nav_polygon = NavigationPolygon.new()
	
	# Define a square traversable area from (0, 0) to (500, 500)
	var outline = PackedVector2Array([
		Vector2(0, 0),
		Vector2(500, 0),
		Vector2(500, 500),
		Vector2(0, 500)
	])
	nav_polygon.add_outline(outline)
	nav_polygon.make_polygons_from_outlines()
	
	nav_region.navigation_polygon = nav_polygon
	add_child(nav_region)
	
	# 2. Create NavigationObstacle2D representing the obstacle at (250, 250)
	var obstacle = NavigationObstacle2D.new()
	obstacle.position = Vector2(250, 250)
	obstacle.radius = 40.0
	obstacle.avoidance_enabled = true
	add_child(obstacle)
	
	# 3. Create the Agent starting at (50, 250)
	agent = CharacterBody2D.new()
	agent.name = "Agent"
	agent.position = Vector2(50, 250)
	agent.set_script(load("res://agent.gd"))
	add_child(agent)
	
	# 4. Wait for 3 physics frames to let NavigationServer2D synchronize
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	# 5. Set the target position to (450, 250)
	agent.nav_agent.target_position = Vector2(450, 250)
	print("Target position set to (450, 250). Starting pathfinding and avoidance.")

func _physics_process(delta: float):
	if simulation_done:
		return
	
	if is_instance_valid(agent):
		# Record the agent's global position
		var pos = agent.global_position
		path_log.append([pos.x, pos.y])
		
		# Track time elapsed
		time_elapsed += delta
		
		# Check termination conditions:
		# - Within 10.0 pixels of target (450, 250)
		# - Timeout of 6.0 seconds
		var dist_to_target = pos.distance_to(Vector2(450, 250))
		if dist_to_target <= 10.0:
			print("Target reached successfully at position: ", pos, " after ", time_elapsed, " seconds.")
			simulation_done = true
			write_log_and_exit()
		elif time_elapsed >= 6.0:
			print("Simulation timeout reached. Ending simulation. Current position: ", pos)
			simulation_done = true
			write_log_and_exit()

func write_log_and_exit():
	var velocity_computed_triggered = false
	if is_instance_valid(agent):
		velocity_computed_triggered = agent.velocity_computed_triggered
	
	var data = {
		"velocity_computed_triggered": velocity_computed_triggered,
		"path": path_log
	}
	
	var json_string = JSON.stringify(data)
	
	var file = FileAccess.open("/home/user/godot-project/path_log.json", FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("Path log successfully written to /home/user/godot-project/path_log.json")
	else:
		print("ERROR: Failed to write path log.")
	
	get_tree().quit()
