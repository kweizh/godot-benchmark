class_name AStarGridPathfinder
extends RefCounted

var _grid: AStarGrid2D
var _size: Vector2i


func load_level(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("AStarGridPathfinder: Cannot open level file: " + path)
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("AStarGridPathfinder: JSON parse error: ", json.get_error_message())
		return

	var data = json.get_data()
	if not data is Dictionary:
		push_error("AStarGridPathfinder: Expected a JSON object at top level")
		return

	var size_arr = data.get("size", [8, 8])
	var w: int = size_arr[0]
	var h: int = size_arr[1]
	_size = Vector2i(w, h)

	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(Vector2i.ZERO, _size)
	_grid.cell_size = Vector2(1, 1)
	_grid.update()

	# Mark solid cells
	var solid_arr: Array = data.get("solid", [])
	for cell in solid_arr:
		var x: int = cell[0]
		var y: int = cell[1]
		_grid.set_point_solid(Vector2i(x, y), true)

	# Apply weight scales
	var weights_arr: Array = data.get("weights", [])
	for entry in weights_arr:
		var x: int = entry[0]
		var y: int = entry[1]
		var weight: float = entry[2]
		_grid.set_point_weight_scale(Vector2i(x, y), weight)


func set_solid(x: int, y: int, value: bool) -> void:
	_grid.set_point_solid(Vector2i(x, y), value)


func set_weight(x: int, y: int, w: float) -> void:
	_grid.set_point_weight_scale(Vector2i(x, y), w)


func set_diagonal_mode(mode: int) -> void:
	_grid.diagonal_mode = mode


func set_heuristic(mode: int) -> void:
	_grid.default_compute_heuristic = mode
	_grid.default_estimate_heuristic = mode


func find_path(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	return _grid.get_point_path(from, to)
