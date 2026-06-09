extends Path2D

signal progress_changed(ratio: float)

var _mode: String = "loop"
var _speed: float = 0.0
var _direction: int = 1
var _progress: float = 0.0

var _waypoint_distances: Array = []
var _waypoint_ratios: Array = []
var _curve_length: float = 0.0
var _waypoint_count: int = 0

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	# Ensure Curve2D is initialized
	if not curve:
		curve = Curve2D.new()
	# Ensure PathFollow2D loop is disabled to prevent double-wrapping or clamping issues
	var path_follow = get_node_or_null("PathFollow2D")
	if path_follow:
		path_follow.loop = false

func load_waypoints(json_path: String) -> void:
	var file = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		push_error("Failed to open waypoints file: " + json_path)
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse JSON: " + json_path)
		return
		
	var data = json.get_data()
	if not data.has("waypoints"):
		push_error("JSON does not contain 'waypoints' key")
		return
		
	var pts = data["waypoints"]
	_waypoint_count = pts.size()
	if _waypoint_count < 2:
		push_error("At least 2 waypoints are required")
		return
		
	if not curve:
		curve = Curve2D.new()
	else:
		curve.clear_points()
		
	for pt in pts:
		curve.add_point(Vector2(pt[0], pt[1]))
		
	_waypoint_distances.clear()
	_waypoint_ratios.clear()
	
	var current_dist = 0.0
	_waypoint_distances.append(current_dist)
	_waypoint_ratios.append(0.0)
	
	var prev_pt = Vector2(pts[0][0], pts[0][1])
	for i in range(1, _waypoint_count):
		var curr_pt = Vector2(pts[i][0], pts[i][1])
		current_dist += prev_pt.distance_to(curr_pt)
		_waypoint_distances.append(current_dist)
		_waypoint_ratios.append(float(i) / (_waypoint_count - 1))
		prev_pt = curr_pt
		
	_curve_length = current_dist
	_progress = 0.0
	
	var path_follow = get_node_or_null("PathFollow2D")
	if path_follow:
		path_follow.progress = 0.0

func set_mode(mode: String) -> void:
	_mode = mode

func set_speed(speed: float) -> void:
	_speed = speed

func set_direction(direction: int) -> void:
	_direction = direction

func tick(delta: float) -> void:
	if _waypoint_count < 2 or _curve_length <= 0.0:
		return
		
	var distance_left = _speed * delta
	if distance_left <= 0.0:
		return
		
	var max_iters = 1000
	while distance_left > 0.00001 and max_iters > 0:
		max_iters -= 1
		
		if _direction == 1:
			var next_idx = -1
			var next_D = -1.0
			for i in range(_waypoint_count):
				if _waypoint_distances[i] > _progress + 1e-9:
					next_idx = i
					next_D = _waypoint_distances[i]
					break
					
			if next_idx != -1:
				var dist_to_next = next_D - _progress
				if distance_left >= dist_to_next:
					_progress = next_D
					distance_left -= dist_to_next
					emit_signal("progress_changed", _waypoint_ratios[next_idx])
				else:
					_progress += distance_left
					distance_left = 0.0
			else:
				if _mode == "loop":
					var dist_to_wrap = _curve_length - _progress
					if dist_to_wrap < 0.0:
						dist_to_wrap = 0.0
					if distance_left >= dist_to_wrap:
						_progress = 0.0
						distance_left -= dist_to_wrap
					else:
						_progress += distance_left
						distance_left = 0.0
				elif _mode == "pingpong":
					var dist_to_reverse = _curve_length - _progress
					if dist_to_reverse < 0.0:
						dist_to_reverse = 0.0
					if distance_left >= dist_to_reverse:
						_progress = _curve_length
						_direction = -1
						distance_left -= dist_to_reverse
					else:
						_progress += distance_left
						distance_left = 0.0
						
		else: # _direction == -1
			var next_idx = -1
			var next_D = -1.0
			for i in range(_waypoint_count - 1, -1, -1):
				if _waypoint_distances[i] < _progress - 1e-9:
					next_idx = i
					next_D = _waypoint_distances[i]
					break
					
			if next_idx != -1:
				var dist_to_next = _progress - next_D
				if distance_left >= dist_to_next:
					_progress = next_D
					distance_left -= dist_to_next
					emit_signal("progress_changed", _waypoint_ratios[next_idx])
				else:
					_progress -= distance_left
					distance_left = 0.0
			else:
				if _mode == "loop":
					var dist_to_wrap = _progress
					if dist_to_wrap < 0.0:
						dist_to_wrap = 0.0
					if distance_left >= dist_to_wrap:
						_progress = _curve_length
						distance_left -= dist_to_wrap
					else:
						_progress -= distance_left
						distance_left = 0.0
				elif _mode == "pingpong":
					var dist_to_reverse = _progress
					if dist_to_reverse < 0.0:
						dist_to_reverse = 0.0
					if distance_left >= dist_to_reverse:
						_progress = 0.0
						_direction = 1
						distance_left -= dist_to_reverse
					else:
						_progress -= distance_left
						distance_left = 0.0

	var path_follow = get_node_or_null("PathFollow2D")
	if path_follow:
		path_follow.progress = _progress
