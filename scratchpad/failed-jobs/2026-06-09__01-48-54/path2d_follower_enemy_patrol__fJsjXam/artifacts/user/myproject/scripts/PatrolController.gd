extends Path2D

signal progress_changed(ratio: float)

var _mode: String = "loop"
var _speed: float = 0.0
var _direction: int = 1
var _waypoint_count: int = 0

@onready var _path_follow: PathFollow2D = $PathFollow2D

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	if not _path_follow:
		_path_follow = get_node_or_null("PathFollow2D")

func load_waypoints(json_path: String) -> void:
	var file = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		return
	var text = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(text)
	if error == OK:
		var data = json.get_data()
		if data.has("waypoints"):
			var waypoints = data["waypoints"]
			_waypoint_count = waypoints.size()
			if not curve:
				curve = Curve2D.new()
			curve.clear_points()
			for wp in waypoints:
				curve.add_point(Vector2(wp[0], wp[1]))
			if not _path_follow:
				_path_follow = get_node_or_null("PathFollow2D")
			if _path_follow:
				_path_follow.progress = 0.0

func set_mode(mode: String) -> void:
	_mode = mode
	if not _path_follow:
		_path_follow = get_node_or_null("PathFollow2D")
	if _path_follow:
		if _mode == "loop":
			_path_follow.loop = true
		else:
			_path_follow.loop = false

func set_speed(speed: float) -> void:
	_speed = speed

func set_direction(direction: int) -> void:
	_direction = direction

func tick(delta: float) -> void:
	if not curve or _waypoint_count < 2:
		return
	if not _path_follow:
		_path_follow = get_node_or_null("PathFollow2D")
		if not _path_follow:
			return
		
	var length = curve.get_baked_length()
	if length <= 0.0:
		return
		
	var travel_dist = _speed * delta
	var start_progress = _path_follow.progress
	
	var crossings = []
	
	if _mode == "loop":
		if _direction > 0:
			var current = start_progress
			var remaining = travel_dist
			while remaining > 0:
				var next_p = current + remaining
				if next_p >= length:
					var part = length - current
					_record_crossings(current, length, 1, crossings, length)
					current = 0.0
					remaining -= part
				else:
					_record_crossings(current, next_p, 1, crossings, length)
					current = next_p
					remaining = 0
			var end_progress = start_progress + travel_dist
			_path_follow.progress = fmod(end_progress, length)
			if _path_follow.progress < 0:
				_path_follow.progress += length
		else:
			var current = start_progress
			var remaining = travel_dist
			while remaining > 0:
				var next_p = current - remaining
				if next_p <= 0:
					var part = current
					_record_crossings(current, 0, -1, crossings, length)
					current = length
					remaining -= part
				else:
					_record_crossings(current, next_p, -1, crossings, length)
					current = next_p
					remaining = 0
			var end_progress = start_progress - travel_dist
			_path_follow.progress = fmod(end_progress, length)
			if _path_follow.progress < 0:
				_path_follow.progress += length
	elif _mode == "pingpong":
		var current = start_progress
		var remaining = travel_dist
		while remaining > 0:
			if _direction > 0:
				var next_p = current + remaining
				if next_p > length:
					var part = length - current
					_record_crossings(current, length, 1, crossings, length)
					_direction = -1
					current = length
					remaining -= part
				else:
					_record_crossings(current, next_p, 1, crossings, length)
					current = next_p
					remaining = 0
			else:
				var next_p = current - remaining
				if next_p < 0:
					var part = current
					_record_crossings(current, 0, -1, crossings, length)
					_direction = 1
					current = 0
					remaining -= part
				else:
					_record_crossings(current, next_p, -1, crossings, length)
					current = next_p
					remaining = 0
		_path_follow.progress = current
		
	for c in crossings:
		progress_changed.emit(c)

func _record_crossings(start_p: float, end_p: float, dir: int, crossings: Array, length: float) -> void:
	if _waypoint_count < 2:
		return
		
	var seg_count = _waypoint_count - 1
	
	if dir > 0:
		var start_ratio = start_p / length
		var end_ratio = end_p / length
		
		for i in range(1, seg_count + 1):
			var ratio = float(i) / seg_count
			var is_start = is_equal_approx(ratio, start_ratio)
			var is_end = is_equal_approx(ratio, end_ratio)
			
			if (ratio > start_ratio and not is_start):
				if (ratio < end_ratio or is_end):
					crossings.append(ratio)
	else:
		var start_ratio = start_p / length
		var end_ratio = end_p / length
		
		for i in range(seg_count - 1, -1, -1):
			var ratio = float(i) / seg_count
			var is_start = is_equal_approx(ratio, start_ratio)
			var is_end = is_equal_approx(ratio, end_ratio)
			
			if (ratio < start_ratio and not is_start):
				if (ratio > end_ratio or is_end):
					crossings.append(ratio)
