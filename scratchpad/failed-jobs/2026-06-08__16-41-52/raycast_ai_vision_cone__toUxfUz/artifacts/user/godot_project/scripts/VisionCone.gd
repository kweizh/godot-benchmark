class_name VisionCone
extends Node2D

signal target_spotted(target: Node2D)
signal target_lost()

@export var cone_angle_deg: float = 90.0
@export var cone_range: float = 200.0
@export var ray_count: int = 7
@export var facing_dir: Vector2 = Vector2.RIGHT
@export var target_group: StringName = &"player"
@export var collision_mask: int = 1

var _last_seen_target: Node2D = null


func is_point_in_cone(point: Vector2) -> bool:
	var world_pos := global_position
	var to_point := point - world_pos
	var dist := to_point.length()
	if dist > cone_range:
		return false
	if dist < 0.0001:
		return true
	var dir := to_point.normalized()
	var facing := facing_dir.normalized()
	var dot := dir.dot(facing)
	var half_angle_rad := deg_to_rad(cone_angle_deg) / 2.0
	return dot >= cos(half_angle_rad)


func detect(world_2d: World2D) -> Node2D:
	if world_2d == null:
		_handle_detection(null)
		return null

	var space_state := world_2d.direct_space_state
	if space_state == null:
		_handle_detection(null)
		return null

	var world_pos := global_position
	var facing := facing_dir.normalized()
	var half_angle_rad := deg_to_rad(cone_angle_deg) / 2.0
	var angle_step := (cone_angle_deg / 180.0 * PI) / float(max(ray_count - 1, 1)) if ray_count > 1 else 0.0

	var closest_dist: float = cone_range
	var closest_target: Node2D = null

	for i in range(ray_count):
		var ray_angle: float
		if ray_count == 1:
			ray_angle = 0.0
		else:
			ray_angle = -half_angle_rad + angle_step * float(i)

		var ray_dir := facing.rotated(ray_angle)
		var ray_end := world_pos + ray_dir * cone_range

		var query := PhysicsRayQueryParameters2D.create(world_pos, ray_end, collision_mask)
		var result := space_state.intersect_ray(query)

		if not result.is_empty():
			var collider: Object = result.get("collider")
			if collider is Node2D and collider.is_in_group(target_group):
				var hit_pos: Vector2 = result.get("position", ray_end)
				var dist := world_pos.distance_to(hit_pos)
				if dist < closest_dist:
					closest_dist = dist
					closest_target = collider as Node2D

	_handle_detection(closest_target)
	return closest_target


func _handle_detection(target: Node2D) -> void:
	if target != null:
		if _last_seen_target == null or _last_seen_target != target:
			_last_seen_target = target
			target_spotted.emit(target)
	else:
		if _last_seen_target != null:
			_last_seen_target = null
			target_lost.emit()
