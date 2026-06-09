class_name AStarGridPathfinder
extends RefCounted

var _grid: AStarGrid2D

func _init() -> void:
	_grid = AStarGrid2D.new()
	_grid.cell_size = Vector2(1, 1)
	_grid.update()


func load_level(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("AStarGridPathfinder: could not open file: " + path)
		return
	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(json_text)
	if err != OK:
		push_error("AStarGridPathfinder: JSON parse error in " + path)
		return
	var data: Dictionary = json.get_data()

	# Configure grid size.
	var size: Array = data["size"]
	var width: int = int(size[0])
	var height: int = int(size[1])
	_grid.region = Rect2i(0, 0, width, height)
	_grid.cell_size = Vector2(1, 1)
	_grid.update()

	# Mark solid cells.
	var solids: Array = data["solid"]
	for entry in solids:
		var x: int = int(entry[0])
		var y: int = int(entry[1])
		_grid.set_point_solid(Vector2i(x, y), true)

	# Apply per-cell weight scales.
	var weights: Array = data["weights"]
	for entry in weights:
		var x: int = int(entry[0])
		var y: int = int(entry[1])
		var w: float = float(entry[2])
		_grid.set_point_weight_scale(Vector2i(x, y), w)


func set_solid(x: int, y: int, value: bool) -> void:
	_grid.set_point_solid(Vector2i(x, y), value)


func set_weight(x: int, y: int, w: float) -> void:
	_grid.set_point_weight_scale(Vector2i(x, y), w)


func set_diagonal_mode(mode: int) -> void:
	_grid.diagonal_mode = mode as AStarGrid2D.DiagonalMode


func set_heuristic(mode: int) -> void:
	_grid.default_compute_heuristic = mode as AStarGrid2D.Heuristic
	_grid.default_estimate_heuristic = mode as AStarGrid2D.Heuristic


func find_path(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	return _grid.get_point_path(from, to)
