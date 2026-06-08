class_name VisionCone
extends Node2D

@export var cone_angle_deg: float = 90.0
@export var cone_range: float = 200.0
@export var ray_count: int = 7
@export var facing_dir: Vector2 = Vector2.RIGHT
@export var target_group: StringName = &"player"
@export var collision_mask: int = 1

signal target_spotted(target: Node2D)
signal target_lost()

var _current_target: Node2D = null


func is_point_in_cone(point: Vector2) -> bool:
	var origin: Vector2 = get_parent().global_position
	var to_point: Vector2 = point - origin
	var distance: float = to_point.length()

	# Range check
	if distance > cone_range:
		return false

	# Degenerate case: point is exactly at the origin
	if to_point == Vector2.ZERO:
		return true

	# Angle check: is the direction to the point within half the cone angle?
	var angle_to_point: float = facing_dir.angle_to(to_point)
	var half_angle: float = deg_to_rad(cone_angle_deg / 2.0)

	return absf(angle_to_point) <= half_angle


func detect(world_2d: World2D) -> Node2D:
	var space_state: PhysicsDirectSpaceState2D = world_2d.direct_space_state
	var origin: Vector2 = get_parent().global_position
	var half_angle: float = deg_to_rad(cone_angle_deg / 2.0)
	var base_angle: float = facing_dir.angle()

	var closest_target: Node2D = null
	var closest_distance: float = INF

	for i in range(ray_count):
		var angle: float
		if ray_count == 1:
			angle = base_angle
		else:
			angle = base_angle + half_angle * (2.0 * float(i) / float(ray_count - 1) - 1.0)

		var end_point: Vector2 = origin + Vector2(cos(angle), sin(angle)) * cone_range

		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			origin, end_point, collision_mask
		)
		var result: Dictionary = space_state.intersect_ray(query)

		if result:
			var collider: Node2D = result["collider"]
			if collider.is_in_group(target_group):
				var dist: float = origin.distance_to(result["position"])
				if dist < closest_distance:
					closest_distance = dist
					closest_target = collider

	# Signal emission logic
	if closest_target != null:
		if _current_target != closest_target:
			if _current_target != null:
				target_lost.emit()
			_current_target = closest_target
			target_spotted.emit(closest_target)
	else:
		if _current_target != null:
			target_lost.emit()
			_current_target = null

	return closest_target