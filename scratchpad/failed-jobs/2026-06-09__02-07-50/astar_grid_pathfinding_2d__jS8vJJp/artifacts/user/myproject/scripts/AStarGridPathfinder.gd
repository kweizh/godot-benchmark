class_name AStarGridPathfinder
extends RefCounted

var _grid: AStarGrid2D


func _init() -> void:
	_grid = AStarGrid2D.new()
	_grid.cell_size = Vector2(1, 1)


func load_level(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("AStarGridPathfinder: Failed to open level file: " + path)
		return
	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(json_text)
	if err != OK:
		push_error("AStarGridPathfinder: Failed to parse JSON from: " + path)
		return

	var data: Dictionary = json.data

	# Configure grid region from size
	var width: int = data["size"][0]
	var height: int = data["size"][1]
	_grid.region = Rect2i(0, 0, width, height)
	_grid.update()

	# Mark solid (non-traversable) cells
	var solid_cells: Array = data["solid"]
	for cell in solid_cells:
		_grid.set_point_solid(Vector2i(int(cell[0]), int(cell[1])), true)

	# Apply per-cell weight scales
	var weights: Array = data["weights"]
	for entry in weights:
		_grid.set_point_weight_scale(Vector2i(int(entry[0]), int(entry[1])), float(entry[2]))


func set_solid(x: int, y: int, value: bool) -> void:
	_grid.set_point_solid(Vector2i(x, y), value)


func set_weight(x: int, y: int, w: float) -> void:
	_grid.set_point_weight_scale(Vector2i(x, y), w)


func set_diagonal_mode(mode: int) -> void:
	match mode:
		0:
			_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
		1:
			_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		2:
			_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
		3:
			_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES


func set_heuristic(mode: int) -> void:
	match mode:
		0:
			_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
			_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
		1:
			_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
			_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		2:
			_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
			_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		3:
			_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_CHEBYSHEV
			_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_CHEBYSHEV


func find_path(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	return _grid.get_point_path(from, to)