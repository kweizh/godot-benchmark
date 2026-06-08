extends SubViewportContainer

@export var world_root: NodePath
@export var player_path: NodePath

signal poi_added(poi_index: int)

var player_marker: Node2D
var poi_markers: Array[Node2D] = []

@onready var sub_viewport = $SubViewport
@onready var camera = $SubViewport/Camera2D

var player_node: Node2D
var world_node: Node

func _ready():
	camera.make_current()
	if not world_root.is_empty():
		world_node = get_node_or_null(world_root)
	if not player_path.is_empty():
		player_node = get_node_or_null(player_path)
	
	# Create player marker
	player_marker = Node2D.new()
	player_marker.name = "PlayerMarker"
	sub_viewport.add_child(player_marker)
	
	if player_node and is_instance_valid(player_node):
		player_marker.global_position = player_node.global_position
		camera.global_position = player_node.global_position
	
	# Create POI markers
	var pois = get_tree().get_nodes_in_group("poi")
	for i in range(pois.size()):
		var marker = Node2D.new()
		marker.name = "POIMarker_" + str(i)
		sub_viewport.add_child(marker)
		poi_markers.append(marker)
		
		if is_instance_valid(pois[i]):
			marker.global_position = pois[i].global_position
			
		emit_signal("poi_added", i)

func _process(delta):
	if player_node and is_instance_valid(player_node):
		player_marker.global_position = player_node.global_position
		camera.global_position = player_node.global_position
	
	var pois = get_tree().get_nodes_in_group("poi")
	for i in range(min(pois.size(), poi_markers.size())):
		if is_instance_valid(pois[i]):
			poi_markers[i].global_position = pois[i].global_position

func get_marker_for_poi(index: int) -> Node2D:
	if index >= 0 and index < poi_markers.size():
		return poi_markers[index]
	return null
