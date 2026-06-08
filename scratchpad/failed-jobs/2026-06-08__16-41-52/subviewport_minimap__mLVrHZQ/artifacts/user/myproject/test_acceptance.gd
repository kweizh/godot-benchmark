extends SceneTree

var _minimap: Node
var _world: Node
var _process_frame_count := 0
var _poi_added_count := 0
var _checks_done := false


func _init() -> void:
	# Load scenes
	var minimap_scene := load("res://scenes/Minimap.tscn")
	var world_scene := load("res://scenes/World.tscn")

	_minimap = minimap_scene.instantiate()
	_world = world_scene.instantiate()

	# Add both to root
	root.add_child(_world)
	root.add_child(_minimap)

	# Wire up exports
	_minimap.world_root = _minimap.get_path_to(_world)
	_minimap.player_path = _minimap.get_path_to(_world.get_node("Player"))

	# Verify Minimap structure
	assert(_minimap is SubViewportContainer, "Root is SubViewportContainer")
	print("PASS: Root is SubViewportContainer")

	var svp := _minimap.get_node("SubViewport")
	assert(svp is SubViewport, "Child is SubViewport")
	print("PASS: Child is SubViewport")

	assert(svp.size == Vector2i(256, 256), "SubViewport size is 256x256")
	print("PASS: SubViewport size == Vector2i(256, 256)")

	assert(svp.transparent_bg == true, "SubViewport transparent_bg is true")
	print("PASS: SubViewport transparent_bg == true")

	var cam := svp.get_node("Camera2D")
	assert(cam is Camera2D, "Camera2D exists in SubViewport")
	print("PASS: Camera2D exists in SubViewport")

	assert(is_equal_approx(cam.zoom.x, 0.1) and is_equal_approx(cam.zoom.y, 0.1), "Camera2D zoom is (0.1, 0.1)")
	print("PASS: Camera2D zoom == Vector2(0.1, 0.1)")

	assert(cam.current == true, "Camera2D is current")
	print("PASS: Camera2D current == true")

	# Verify World structure
	assert(_world.name == "World", "World root named World")
	print("PASS: World root named 'World'")

	var player := _world.get_node("Player")
	assert(player is CharacterBody2D, "Player is CharacterBody2D")
	print("PASS: Player is CharacterBody2D")

	var pois := _get_nodes_in_group("poi")
	assert(pois.size() >= 3, "At least 3 POI nodes")
	print("PASS: At least 3 POI nodes in group 'poi': ", pois.size())

	# Connect to poi_added signal
	_minimap.poi_added.connect(func(idx: int):
		_poi_added_count += 1
		print("  poi_added(", idx, ")")
	)

	print("Processing frames...")


func _process(_delta: float) -> bool:
	_process_frame_count += 1

	if _checks_done:
		return false

	if _process_frame_count == 1:
		# After first process frame, check POI markers were created
		var pois := _get_nodes_in_group("poi")

		# Check all POI markers exist
		for i in range(pois.size()):
			var marker: Node2D = _minimap.get_marker_for_poi(i)
			assert(marker != null, "get_marker_for_poi(%d) returns non-null" % i)
			print("PASS: get_marker_for_poi(%d) returns non-null Node2D" % i)

		# Verify poi_added count
		assert(_poi_added_count == pois.size(), "poi_added emitted exactly %d times (got %d)" % [pois.size(), _poi_added_count])
		print("PASS: poi_added emitted exactly %d times" % pois.size())

		# Set player position
		var player := _world.get_node("Player")
		player.global_position = Vector2(123, -45)

	elif _process_frame_count == 2:
		# After one more frame, verify player marker position
		var svp := _minimap.get_node("SubViewport")
		var player_marker: Node2D = svp.get_node_or_null("PlayerMarker")
		assert(player_marker != null, "PlayerMarker exists")
		print("PASS: PlayerMarker exists in SubViewport")

		var expected := Vector2(123, -45)
		var diff: float = player_marker.global_position.distance_to(expected)
		assert(diff < 0.01, "Player marker position matches (diff: %.6f)" % diff)
		print("PASS: Player marker position == (123, -45) within 0.01 (diff: %.6f)" % diff)

		# Verify first POI marker position
		var pois := _get_nodes_in_group("poi")
		var poi_marker: Node2D = _minimap.get_marker_for_poi(0)
		var poi_world_pos: Vector2 = pois[0].global_position
		var poi_diff: float = poi_marker.global_position.distance_to(poi_world_pos)
		assert(poi_diff < 0.01, "POI marker 0 position matches world POI (diff: %.6f)" % poi_diff)
		print("PASS: POI marker 0 position equals first POI world position within 0.01 (diff: %.6f)" % poi_diff)

		print("\n=== ALL ACCEPTANCE TESTS PASSED ===")
		_checks_done = true
		quit(0)

	return false


func _get_nodes_in_group(group_name: String) -> Array:
	var result: Array[Node] = []
	_collect_nodes_in_group(root, group_name, result)
	return result


func _collect_nodes_in_group(node: Node, group_name: String, result: Array) -> void:
	if node.is_in_group(group_name):
		result.append(node)
	for child in node.get_children():
		_collect_nodes_in_group(child, group_name, result)
