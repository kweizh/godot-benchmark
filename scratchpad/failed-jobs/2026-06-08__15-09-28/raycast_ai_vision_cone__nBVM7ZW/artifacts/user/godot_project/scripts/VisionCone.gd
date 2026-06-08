class_name VisionCone
extends Node2D

## Emitted when a target enters the vision cone and was not visible last frame.
signal target_spotted(target: Node2D)
## Emitted when the previously-visible target is no longer detected.
signal target_lost()

@export var cone_angle_deg: float = 90.0
@export var cone_range: float = 200.0
@export var ray_count: int = 7
@export var facing_dir: Vector2 = Vector2.RIGHT
@export var target_group: StringName = &"player"
@export var collision_mask: int = 1

## The node that was returned by the last detect() call (null if none).
var _last_detected: Node2D = null

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns true when *point* (world-space) lies inside the cone.
## The cone origin is the parent node's global_position.
func is_point_in_cone(point: Vector2) -> bool:
	var origin: Vector2 = _get_origin()
	var to_point: Vector2 = point - origin
	var dist: float = to_point.length()
	if dist > cone_range:
		return false
	if dist < 0.0001:
		# point is at origin, consider it inside
		return true
	var half_angle_rad: float = deg_to_rad(cone_angle_deg * 0.5)
	var dir_norm: Vector2 = facing_dir.normalized()
	var to_norm: Vector2 = to_point / dist
	var dot: float = dir_norm.dot(to_norm)
	# dot >= cos(half_angle) means the angle between them is <= half the cone angle
	return dot >= cos(half_angle_rad)

## Cast rays across the cone using the provided World2D.
## Returns the closest Node2D in *target_group* with clear line-of-sight, or null.
func detect(world_2d: World2D) -> Node2D:
	var space_state: PhysicsDirectSpaceState2D = world_2d.direct_space_state
	var origin: Vector2 = _get_origin()

	var dir_norm: Vector2 = facing_dir.normalized()
	var half_angle_rad: float = deg_to_rad(cone_angle_deg * 0.5)

	var best_node: Node2D = null
	var best_dist_sq: float = INF

	for i in range(ray_count):
		var t: float = 0.0 if ray_count == 1 else float(i) / float(ray_count - 1)
		var angle: float = lerp(-half_angle_rad, half_angle_rad, t)
		var ray_dir: Vector2 = dir_norm.rotated(angle)
		var ray_end: Vector2 = origin + ray_dir * cone_range

		var query := PhysicsRayQueryParameters2D.create(origin, ray_end, collision_mask)
		query.collide_with_bodies = true
		query.collide_with_areas = false

		var result: Dictionary = space_state.intersect_ray(query)
		if result.is_empty():
			continue

		var collider = result.get("collider")
		if collider == null:
			continue
		if not (collider is Node2D):
			continue
		if not collider.is_in_group(target_group):
			continue

		var hit_pos: Vector2 = result.get("position", collider.global_position)
		var dist_sq: float = origin.distance_squared_to(hit_pos)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_node = collider as Node2D

	# --- signal logic ---
	if best_node != null and best_node != _last_detected:
		_last_detected = best_node
		target_spotted.emit(best_node)
	elif best_node == null and _last_detected != null:
		_last_detected = null
		target_lost.emit()
	# If same target detected again, do nothing (no repeated target_spotted).

	return best_node

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _get_origin() -> Vector2:
	if get_parent() is Node2D:
		return (get_parent() as Node2D).global_position
	return global_position
