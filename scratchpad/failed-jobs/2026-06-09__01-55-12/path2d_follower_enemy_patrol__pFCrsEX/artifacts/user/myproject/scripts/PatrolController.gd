@tool
extends Path2D

## PatrolController – drives an enemy along a Path2D built at runtime from a
## JSON waypoint file.  Progress is advanced exclusively through tick(delta) so
## that test runners can step the simulation deterministically.

signal progress_changed(ratio: float)

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------
var _mode: String        = "loop"   # "loop" | "pingpong"
var _speed: float        = 100.0   # pixels / second
var _direction: int      = 1       # +1 forward, -1 backward
var _waypoint_count: int = 0
var _path_follow: PathFollow2D      # cached – may be null until first access

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Only tick() must drive motion; disable automatic _process.
	set_process(false)
	set_physics_process(false)

	# Eagerly cache the child so later calls don't need to search.
	_path_follow = get_node_or_null("PathFollow2D")

	# Guarantee a Curve2D exists (editor may leave the property unset).
	if curve == null:
		curve = Curve2D.new()

# Lazy accessor: safe to call before the node enters the tree.
func _pf() -> PathFollow2D:
	if _path_follow == null:
		_path_follow = get_node_or_null("PathFollow2D")
	return _path_follow

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Load waypoints from a JSON file and rebuild the Path2D curve.
func load_waypoints(json_path: String) -> void:
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("PatrolController: cannot open '%s'" % json_path)
		return

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("PatrolController: invalid JSON in '%s'" % json_path)
		return
	var dict: Dictionary = parsed as Dictionary
	if not dict.has("waypoints"):
		push_error("PatrolController: missing 'waypoints' key in '%s'" % json_path)
		return

	var pts: Array = dict["waypoints"]
	if pts.size() < 2:
		push_error("PatrolController: need >= 2 waypoints, got %d" % pts.size())
		return

	# Rebuild as a pure polyline – no Bezier handles.
	if curve == null:
		curve = Curve2D.new()
	curve.clear_points()
	for pt in pts:
		curve.add_point(Vector2(float(pt[0]), float(pt[1])))

	_waypoint_count = pts.size()

	# Re-assign the curve so Path2D fires NOTIFICATION_PATH_CHANGED to all
	# children (including PathFollow2D), which forces it to refresh its cached
	# baked length.  Without this, PathFollow2D.progress_ratio stays at 0 when
	# the curve is built after the node has entered the scene tree.
	self.curve = curve

	# Reset follower to path start.
	var pf: PathFollow2D = _pf()
	if pf != null:
		pf.progress = 0.0

## Set patrol mode: "loop" or "pingpong".
func set_mode(mode: String) -> void:
	_mode = mode

## Set movement speed in pixels per second.
func set_speed(speed: float) -> void:
	_speed = speed

## Set movement direction: +1 (forward) or -1 (reverse).
func set_direction(direction: int) -> void:
	_direction = direction

## Advance the patrol by delta seconds.
## Emits progress_changed(ratio) for every waypoint boundary crossed, in order.
func tick(delta: float) -> void:
	if _waypoint_count < 2 or curve == null:
		return

	var total_len: float = curve.get_baked_length()
	if total_len <= 0.0:
		return

	var pf: PathFollow2D = _pf()
	if pf == null:
		return

	var travel: float = _speed * delta

	if _mode == "loop":
		_tick_loop(pf, travel, total_len)
	else:
		_tick_pingpong(pf, travel, total_len)

# ---------------------------------------------------------------------------
# Loop mode
# ---------------------------------------------------------------------------

func _tick_loop(pf: PathFollow2D, travel: float, total_len: float) -> void:
	var old_p: float = pf.progress
	var new_p: float = old_p + travel * float(_direction)

	_emit_crossings_loop(old_p, new_p, total_len)

	pf.progress = fposmod(new_p, total_len)

## Emit boundary crossings for an unwrapped movement from old_p to new_p.
func _emit_crossings_loop(old_p: float, new_p: float, total_len: float) -> void:
	if _direction >= 0:
		# Forward: crossings in (old_p, new_p] on the unwrapped line.
		var loop_start: int = int(old_p / total_len)
		var loop_end: int   = int(new_p / total_len)

		for loop_idx in range(loop_start, loop_end + 1):
			var base: float = float(loop_idx) * total_len
			for i in range(_waypoint_count):
				# In any loop beyond the first, waypoint 0 (ratio=0) sits at the
				# same absolute position as waypoint (count-1) of the previous
				# loop (ratio=1.0), which was already emitted.  Skip it to avoid
				# a duplicate crossing signal at the wrap boundary.
				if i == 0 and loop_idx > loop_start:
					continue
				var thresh: float = base + _waypoint_px(i, total_len)
				if thresh > old_p + 1e-9 and thresh <= new_p + 1e-9:
					emit_signal("progress_changed", _waypoint_ratio(i))
	else:
		# Backward: crossings in [new_p, old_p) in decreasing order.
		var loop_start: int = int(old_p / total_len)
		var loop_min: int = floori(new_p / total_len)

		for loop_idx in range(loop_start, loop_min - 1, -1):
			var base: float = float(loop_idx) * total_len
			for i in range(_waypoint_count - 1, -1, -1):
				# Symmetric: in any loop below the starting loop, waypoint
				# (count-1) (ratio=1.0) at base+total_len-ε duplicates the
				# ratio=0.0 crossing emitted by waypoint 0 of the loop above.
				if i == _waypoint_count - 1 and loop_idx < loop_start:
					continue
				var thresh: float = base + _waypoint_px(i, total_len)
				if thresh < old_p - 1e-9 and thresh >= new_p - 1e-9:
					emit_signal("progress_changed", _waypoint_ratio(i))

# ---------------------------------------------------------------------------
# Pingpong mode
# ---------------------------------------------------------------------------

func _tick_pingpong(pf: PathFollow2D, travel: float, total_len: float) -> void:
	var remaining: float = travel
	var pos: float = pf.progress

	while remaining > 1e-9:
		if _direction >= 0:
			var dist_to_end: float = total_len - pos
			if remaining <= dist_to_end + 1e-9:
				# Normal forward step – won't hit the end wall.
				var new_pos: float = minf(pos + remaining, total_len)
				_emit_crossings_segment(pos, new_pos, total_len)
				pos = new_pos
				remaining = 0.0
			else:
				# Hit the far end; emit up to it, consume distance, reverse.
				_emit_crossings_segment(pos, total_len, total_len)
				remaining -= dist_to_end
				pos = total_len
				_direction = -1
		else:
			var dist_to_start: float = pos
			if remaining <= dist_to_start + 1e-9:
				var new_pos: float = maxf(pos - remaining, 0.0)
				_emit_crossings_segment(pos, new_pos, total_len)
				pos = new_pos
				remaining = 0.0
			else:
				# Hit the near end; emit down to 0, consume distance, reverse.
				_emit_crossings_segment(pos, 0.0, total_len)
				remaining -= dist_to_start
				pos = 0.0
				_direction = 1

	pf.progress = pos

# ---------------------------------------------------------------------------
# Helpers shared by both modes
# ---------------------------------------------------------------------------

## Pixel progress of waypoint i along the baked curve length.
func _waypoint_px(i: int, total_len: float) -> float:
	return (float(i) / float(_waypoint_count - 1)) * total_len

## Normalised ratio for waypoint i.
func _waypoint_ratio(i: int) -> float:
	return float(i) / float(_waypoint_count - 1)

## Emit progress_changed for every waypoint threshold in the segment [a, b]
## (where a and b are absolute progress values in pixels).  Emits in traversal
## order: ascending when a < b, descending when a > b.
## Excludes the starting point a (not re-emitted) but includes the endpoint b.
func _emit_crossings_segment(a: float, b: float, total_len: float) -> void:
	if _waypoint_count < 2:
		return
	if a < b:
		for i in range(_waypoint_count):
			var thresh: float = _waypoint_px(i, total_len)
			if thresh > a + 1e-9 and thresh <= b + 1e-9:
				emit_signal("progress_changed", _waypoint_ratio(i))
	elif a > b:
		for i in range(_waypoint_count - 1, -1, -1):
			var thresh: float = _waypoint_px(i, total_len)
			if thresh < a - 1e-9 and thresh >= b - 1e-9:
				emit_signal("progress_changed", _waypoint_ratio(i))
