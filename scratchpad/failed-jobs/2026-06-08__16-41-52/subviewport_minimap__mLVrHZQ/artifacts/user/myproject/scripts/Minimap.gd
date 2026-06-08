extends SubViewportContainer

@export var world_root: NodePath
@export var player_path: NodePath

signal poi_added(poi_index: int)

var _player_marker: Node2D
var _poi_markers: Array[Node2D] = []
var _setup_done := false


func _ready() -> void:
	call_deferred("_setup")


func _setup() -> void:
	if _setup_done:
		return
	_setup_done = true

	var world := get_node_or_null(world_root) as Node
	if not world:
		return

	# Create player marker
	_player_marker = Node2D.new()
	_player_marker.name = "PlayerMarker"
	var subviewport := _get_subviewport()
	if subviewport:
		subviewport.add_child(_player_marker)

	# Create POI markers
	var pois := get_tree().get_nodes_in_group("poi")
	for i in range(pois.size()):
		var poi := pois[i]
		var marker := Node2D.new()
		marker.name = "POIMarker%d" % i
		if subviewport:
			subviewport.add_child(marker)
		_poi_markers.append(marker)
		poi_added.emit(i)


func _process(_delta: float) -> void:
	_update_player_marker()
	_update_poi_markers()


func _update_player_marker() -> void:
	if not _player_marker:
		return
	var player := get_node_or_null(player_path) as Node2D
	if player:
		_player_marker.global_position = player.global_position


func _update_poi_markers() -> void:
	var pois := get_tree().get_nodes_in_group("poi")
	for i in range(min(_poi_markers.size(), pois.size())):
		var poi := pois[i] as Node2D
		if poi:
			_poi_markers[i].global_position = poi.global_position


func get_marker_for_poi(index: int) -> Node2D:
	if index >= 0 and index < _poi_markers.size():
		return _poi_markers[index]
	return null


func _get_subviewport() -> SubViewport:
	for child in get_children():
		if child is SubViewport:
			return child
	return null
