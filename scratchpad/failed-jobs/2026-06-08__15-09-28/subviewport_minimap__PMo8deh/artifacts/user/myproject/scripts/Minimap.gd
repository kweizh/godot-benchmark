extends SubViewportContainer

## SubViewport-based minimap that tracks a player and points-of-interest (POIs).
##
## Usage:
##   1. Assign world_root to the NodePath of the World Node2D.
##   2. Assign player_path to the NodePath of the CharacterBody2D player.
##   3. The minimap will auto-create markers for every node in group "poi"
##      and emit poi_added for each one.

@export var world_root: NodePath
@export var player_path: NodePath

signal poi_added(poi_index: int)

# Internal nodes
var _camera: Camera2D
var _player_marker: Node2D
var _poi_markers: Array[Node2D] = []

# Cached references resolved at runtime
var _player: Node2D
var _pois: Array[Node2D] = []

const MARKER_SIZE := 6.0


func _ready() -> void:
	# Locate the Camera2D that lives inside our SubViewport child.
	var subviewport: SubViewport = _get_subviewport()
	if subviewport == null:
		push_error("Minimap: no SubViewport child found on SubViewportContainer.")
		return

	_camera = subviewport.get_node_or_null("Camera2D")
	if _camera == null:
		push_error("Minimap: no Camera2D found inside the SubViewport.")
		return

	# Wait until the scene tree is fully ready before resolving NodePaths.
	call_deferred("_init_tracking")


func _init_tracking() -> void:
	# Resolve player reference
	if player_path != NodePath("") and has_node(player_path):
		_player = get_node(player_path)
	elif player_path != NodePath(""):
		push_warning("Minimap: player_path '%s' not found." % player_path)

	# Resolve world root and gather POIs
	var world: Node = null
	if world_root != NodePath("") and has_node(world_root):
		world = get_node(world_root)

	var tree := get_tree()
	var poi_nodes: Array = tree.get_nodes_in_group("poi")

	# Create a player marker
	_player_marker = _make_marker(Color.CYAN)
	add_child(_player_marker)

	# Create one marker per POI
	for i in poi_nodes.size():
		var poi := poi_nodes[i] as Node2D
		_pois.append(poi)
		var marker := _make_marker(Color.YELLOW)
		marker.position = poi.global_position
		_poi_markers.append(marker)
		add_child(marker)
		poi_added.emit(i)


func _process(_delta: float) -> void:
	if _player == null:
		return

	# Keep the camera centred on the player in world space.
	if _camera != null:
		_camera.global_position = _player.global_position

	# Sync player marker position to player world position.
	_player_marker.position = _player.global_position

	# Sync POI markers (static in world space, but keep them fresh).
	for i in _pois.size():
		_poi_markers[i].position = _pois[i].global_position


## Returns the marker Node2D for the POI at *index*, or null if out of range.
func get_marker_for_poi(index: int) -> Node2D:
	if index < 0 or index >= _poi_markers.size():
		return null
	return _poi_markers[index]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _get_subviewport() -> SubViewport:
	for child in get_children():
		if child is SubViewport:
			return child as SubViewport
	return null


func _make_marker(color: Color) -> Node2D:
	var marker := Node2D.new()
	# Attach a tiny colored rectangle as a visual indicator.
	var rect := ColorRect.new()
	rect.color = color
	rect.size = Vector2(MARKER_SIZE, MARKER_SIZE)
	rect.position = -rect.size / 2.0
	marker.add_child(rect)
	return marker
