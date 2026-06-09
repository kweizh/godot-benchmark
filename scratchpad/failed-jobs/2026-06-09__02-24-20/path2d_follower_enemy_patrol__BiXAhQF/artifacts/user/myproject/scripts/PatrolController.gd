extends Path2D

signal progress_changed(ratio: float)

var _mode: String = "loop"
var _speed: float = 0.0
var _direction: int = 1  # +1 forward, -1 reverse
var _waypoint_count: int = 0


func _ready() -> void:
	set_process(false)


func _get_path_follow() -> PathFollow2D:
	return $PathFollow2D as PathFollow2D


func load_waypoints(json_path: String) -> void:
	var file = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open waypoints file: ", json_path)
		return

	var text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(text)
	if error != OK:
		push_error("Failed to parse JSON: ", json_path)
		return

	var data = json.get_data()
	if data == null or not data.has("waypoints"):
		push_error("Invalid waypoints JSON structure")
		return

	var waypoints: Array = data["waypoints"]
	_waypoint_count = waypoints.size()
	if _waypoint_count < 2:
		push_error("Need at least 2 waypoints")
		return

	curve.clear_points()
	for wp in waypoints:
		curve.add_point(Vector2(wp[0], wp[1]))

	_get_path_follow().progress = 0.0


func set_mode(mode: String) -> void:
	_mode = mode


func set_speed(speed: float) -> void:
	_speed = speed


func set_direction(direction: int) -> void:
	_direction = 1 if direction >= 0 else -1


func tick(delta: float) -> void:
	if _speed == 0.0 or _waypoint_count < 2:
		return

	var total_length: float = curve.get_baked_length()
	if total_length <= 0.0:
		return

	var travel: float = _speed * delta
	if travel <= 0.0:
		return

	if _mode == "loop":
		_tick_loop(travel, total_length)
	else:
		_tick_pingpong(travel, total_length)


func _tick_loop(travel: float, total_length: float) -> void:
	var pf := _get_path_follow()
	var start_progress: float = pf.progress
	var end_progress: float = start_progress + _direction * travel

	# Collect all boundary crossings in order
	var crossings: Array[float] = []

	var start_ratio: float = start_progress / total_length
	var end_ratio: float = end_progress / total_length

	# Use floor-based wrap counting that works for both directions
	var full_wraps_float: float = floor(end_ratio)
	var wrapped_end_ratio: float = end_ratio - full_wraps_float  # always in [0, 1)
	var abs_wraps: int = int(abs(full_wraps_float))

	if _direction > 0:
		# Moving forward: full_wraps_float >= 0
		if abs_wraps == 0:
			_collect_forward_crossings(start_ratio, end_ratio, crossings)
		else:
			_collect_forward_crossings(start_ratio, 1.0, crossings)
			for _w in range(abs_wraps):
				_collect_forward_crossings(0.0, 1.0, crossings)
			if wrapped_end_ratio > 0.0:
				_collect_forward_crossings(0.0, wrapped_end_ratio, crossings)
	else:
		# Moving backward: full_wraps_float <= 0
		if abs_wraps == 0:
			_collect_backward_crossings(start_ratio, end_ratio, crossings)
		else:
			_collect_backward_crossings(start_ratio, 0.0, crossings)
			for _w in range(abs_wraps):
				_collect_backward_crossings(1.0, 0.0, crossings)
			if wrapped_end_ratio < 1.0:
				_collect_backward_crossings(1.0, wrapped_end_ratio, crossings)

	# Apply final progress (wrapped)
	pf.progress = fposmod(end_progress, total_length)

	for c in crossings:
		progress_changed.emit(c)


func _collect_forward_crossings(from_ratio: float, to_ratio: float, crossings: Array[float]) -> void:
	for i in range(1, _waypoint_count):
		var threshold_ratio: float = float(i) / float(_waypoint_count - 1)
		if threshold_ratio > from_ratio and threshold_ratio <= to_ratio:
			crossings.append(threshold_ratio)


func _collect_backward_crossings(from_ratio: float, to_ratio: float, crossings: Array[float]) -> void:
	for i in range(_waypoint_count - 2, -1, -1):
		var threshold_ratio: float = float(i) / float(_waypoint_count - 1)
		if threshold_ratio < from_ratio and threshold_ratio >= to_ratio:
			crossings.append(threshold_ratio)


func _tick_pingpong(travel: float, total_length: float) -> void:
	var remaining: float = travel
	# Safety limit to prevent infinite loops
	var max_iterations: int = 10
	var iterations: int = 0

	while remaining > 0.0 and iterations < max_iterations:
		iterations += 1
		var pf := _get_path_follow()
		var current_progress: float = pf.progress

		if _direction > 0:
			var dist_to_end: float = total_length - current_progress
			if remaining <= dist_to_end:
				# Can complete within this segment without reversing
				var new_progress: float = current_progress + remaining
				pf.progress = new_progress
				_emit_pingpong_crossings(current_progress, new_progress, total_length)
				remaining = 0.0
			else:
				# Hit the end, consume what we can, then reverse
				pf.progress = total_length
				_emit_pingpong_crossings(current_progress, total_length, total_length)
				remaining -= dist_to_end
				_direction = -1
		else:
			var dist_to_start: float = current_progress
			if remaining <= dist_to_start:
				# Can complete within this segment without reversing
				var new_progress: float = current_progress - remaining
				pf.progress = new_progress
				_emit_pingpong_crossings(current_progress, new_progress, total_length)
				remaining = 0.0
			else:
				# Hit the start, consume what we can, then reverse
				pf.progress = 0.0
				_emit_pingpong_crossings(current_progress, 0.0, total_length)
				remaining -= dist_to_start
				_direction = 1


func _emit_pingpong_crossings(from_progress: float, to_progress: float, total_length: float) -> void:
	if _waypoint_count < 2:
		return

	var from_ratio: float = from_progress / total_length
	var to_ratio: float = to_progress / total_length

	if to_ratio > from_ratio:
		# Moving forward
		for i in range(1, _waypoint_count):
			var threshold_ratio: float = float(i) / float(_waypoint_count - 1)
			if threshold_ratio > from_ratio and threshold_ratio <= to_ratio:
				progress_changed.emit(threshold_ratio)
	else:
		# Moving backward
		for i in range(_waypoint_count - 2, -1, -1):
			var threshold_ratio: float = float(i) / float(_waypoint_count - 1)
			if threshold_ratio < from_ratio and threshold_ratio >= to_ratio:
				progress_changed.emit(threshold_ratio)
