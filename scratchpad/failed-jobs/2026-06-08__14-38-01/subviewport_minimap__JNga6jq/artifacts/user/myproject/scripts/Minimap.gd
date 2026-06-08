extends SubViewportContainer

@export var world_root: NodePath:
	set(value):
		world_root = value
		if is_inside_tree():
			_try_initialize()

@export var player_path: NodePath:
	set(value):
		player_path = value
		if is_inside_tree():
			_try_initialize()

signal poi_added(poi_index: int)

var _initialized = false
var _player_node: Node2D = null
var _player_marker: Node2D = null
var _poi_markers: Array[Node2D] = []
var _poi_nodes: Array[Node2D] = []

@onready var subviewport: SubViewport = $SubViewport
@onready var camera: Camera2D = $SubViewport/Camera2D

func _ready() -> void:
	_try_initialize()

func _process(_delta: float) -> void:
	if not _initialized:
		_try_initialize()
	
	# Update player marker position
	if _player_node and is_instance_valid(_player_node) and _player_marker:
		_player_marker.position = _player_node.global_position
		# Camera should center on player
		if camera:
			camera.position = _player_node.global_position
			
	# Update POI markers positions
	for i in range(_poi_markers.size()):
		var marker = _poi_markers[i]
		var poi = _poi_nodes[i]
		if marker and is_instance_valid(marker) and poi and is_instance_valid(poi):
			marker.position = poi.global_position

func _try_initialize() -> void:
	if _initialized:
		return
	
	# We need both world_root and player_path to be set and valid nodes
	if world_root.is_empty() or player_path.is_empty():
		return
		
	var wr = get_node_or_null(world_root)
	var pl = get_node_or_null(player_path)
	
	if not wr or not pl:
		return # Not ready yet
		
	_player_node = pl as Node2D
	if not _player_node:
		return
		
	_initialized = true
	
	# Ensure SubViewport and Camera2D exist or get them
	if not subviewport:
		subviewport = get_node_or_null("SubViewport")
	if not camera:
		camera = get_node_or_null("SubViewport/Camera2D")
		
	# Create player marker
	_player_marker = Node2D.new()
	_player_marker.name = "PlayerMarker"
	_player_marker.position = _player_node.global_position
	subviewport.add_child(_player_marker)
	
	if camera:
		camera.position = _player_node.global_position
	
	# Add visual representation
	var visual = ColorRect.new()
	visual.size = Vector2(10, 10)
	visual.position = -visual.size / 2
	visual.color = Color.BLUE
	_player_marker.add_child(visual)
	
	# Find POIs
	var pois = get_tree().get_nodes_in_group("poi")
	for i in range(pois.size()):
		var poi = pois[i] as Node2D
		if poi:
			_poi_nodes.append(poi)
			var marker = Node2D.new()
			marker.name = "PoiMarker_" + str(i)
			marker.position = poi.global_position
			subviewport.add_child(marker)
			
			var p_visual = ColorRect.new()
			p_visual.size = Vector2(8, 8)
			p_visual.position = -p_visual.size / 2
			p_visual.color = Color.RED
			marker.add_child(p_visual)
			
			_poi_markers.append(marker)
			poi_added.emit(i)

func get_marker_for_poi(index: int) -> Node2D:
	if index >= 0 and index < _poi_markers.size():
		return _poi_markers[index]
	return null
