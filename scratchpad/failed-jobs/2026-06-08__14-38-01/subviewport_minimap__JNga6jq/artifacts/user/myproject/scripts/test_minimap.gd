extends SceneTree

func _init():
	call_deferred("_run_test")

func _run_test():
	print("Starting minimap tests...")
	
	# Instantiate World
	var world_scene = load("res://scenes/World.tscn")
	var world = world_scene.instantiate()
	root.add_child(world)
	
	# Instantiate Minimap
	var minimap_scene = load("res://scenes/Minimap.tscn")
	var minimap = minimap_scene.instantiate()
	
	# Wire up export paths
	# Since World and Minimap are siblings under root:
	# World path from Minimap: "../World"
	# Player path from Minimap: "../World/Player"
	minimap.world_root = "../World"
	minimap.player_path = "../World/Player"
	
	var test_state = { "poi_added_count": 0 }
	minimap.poi_added.connect(func(index):
		test_state["poi_added_count"] += 1
		print("POI added signal received for index: ", index)
	)
	
	root.add_child(minimap)
	
	# Wait one process frame to let everything initialize and process
	await process_frame
	
	# Check POI added emissions (should be at least 3)
	var poi_added_count = test_state["poi_added_count"]
	print("POI added count: ", poi_added_count)
	if poi_added_count < 3:
		print("ERROR: POI added count is less than 3")
		quit(1)
		return
	
	# Check POI 0 marker position
	var poi_0_marker = minimap.get_marker_for_poi(0)
	if poi_0_marker == null:
		print("ERROR: POI 0 marker is null")
		quit(1)
		return
		
	var first_poi = world.get_node("Poi1")
	print("First POI world position: ", first_poi.global_position)
	print("POI 0 marker position: ", poi_0_marker.position)
	if poi_0_marker.position.distance_to(first_poi.global_position) >= 0.01:
		print("ERROR: POI marker position does not match POI world position")
		quit(1)
		return
	
	# Set player global position and wait one frame
	var player = world.get_node("Player")
	player.global_position = Vector2(123, -45)
	print("Set player position to (123, -45)")
	
	await process_frame
	
	# Check player marker position
	var player_marker = minimap.get_node("SubViewport/PlayerMarker")
	if player_marker == null:
		print("ERROR: Player marker does not exist")
		quit(1)
		return
		
	print("Player marker position: ", player_marker.position)
	if player_marker.position.distance_to(Vector2(123, -45)) >= 0.01:
		print("ERROR: Player marker position does not equal player global position")
		quit(1)
		return
	
	print("All tests passed successfully!")
	quit(0)
