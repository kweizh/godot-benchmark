class_name AStarGridPathfinder
extends RefCounted

var _grid: AStarGrid2D

func _init() -> void:
    _grid = AStarGrid2D.new()
    _grid.cell_size = Vector2(1, 1)

func load_level(path: String) -> void:
    var file = FileAccess.open(path, FileAccess.READ)
    if not file:
        return
    var json_text = file.get_as_text()
    file.close()
    
    var json = JSON.new()
    var error = json.parse(json_text)
    if error != OK:
        return
        
    var data = json.get_data()
    
    var size_arr = data.get("size", [0, 0])
    _grid.region = Rect2i(0, 0, int(size_arr[0]), int(size_arr[1]))
    
    _grid.update()
    
    var solid_arr = data.get("solid", [])
    for s in solid_arr:
        set_solid(int(s[0]), int(s[1]), true)
        
    var weights_arr = data.get("weights", [])
    for w in weights_arr:
        set_weight(int(w[0]), int(w[1]), float(w[2]))

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
