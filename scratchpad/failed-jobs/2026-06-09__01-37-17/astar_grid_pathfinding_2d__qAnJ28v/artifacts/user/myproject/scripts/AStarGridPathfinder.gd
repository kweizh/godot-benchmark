class_name AStarGridPathfinder
extends RefCounted

var _grid: AStarGrid2D

func _init() -> void:
	_grid = AStarGrid2D.new()
	_grid.cell_size = Vector2(1, 1)
	_grid.offset = Vector2(0, 0)

func load_level(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open file: " + path)
		return
	
	var json_string = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("Failed to parse JSON: " + json.get_error_message())
		return
		
	var data = json.data
	if not data is Dictionary:
		push_error("JSON data is not a Dictionary")
		return
		
	var size = data.get("size", [0, 0])
	var width = int(size[0])
	var height = int(size[1])
	
	_grid.region = Rect2i(0, 0, width, height)
	_grid.update()
	
	var solids = data.get("solid", [])
	for cell in solids:
		if cell is Array and cell.size() >= 2:
			var cx = int(cell[0])
			var cy = int(cell[1])
			if _grid.is_in_bounds(cx, cy):
				_grid.set_point_solid(Vector2i(cx, cy), true)
			
	var weights = data.get("weights", [])
	for entry in weights:
		if entry is Array and entry.size() >= 3:
			var wx = int(entry[0])
			var wy = int(entry[1])
			if _grid.is_in_bounds(wx, wy):
				_grid.set_point_weight_scale(Vector2i(wx, wy), float(entry[2]))

func set_solid(x: int, y: int, value: bool) -> void:
	if _grid.is_in_bounds(x, y):
		_grid.set_point_solid(Vector2i(x, y), value)

func set_weight(x: int, y: int, w: float) -> void:
	if _grid.is_in_bounds(x, y):
		_grid.set_point_weight_scale(Vector2i(x, y), w)

func set_diagonal_mode(mode: int) -> void:
	_grid.diagonal_mode = mode as AStarGrid2D.DiagonalMode

func set_heuristic(mode: int) -> void:
	_grid.default_compute_heuristic = mode as AStarGrid2D.Heuristic
	_grid.default_estimate_heuristic = mode as AStarGrid2D.Heuristic

func find_path(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	if not _grid.is_in_boundsv(from) or not _grid.is_in_boundsv(to):
		return PackedVector2Array()
	return _grid.get_point_path(from, to)
