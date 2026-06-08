extends Node2D
class_name VisionCone

signal target_spotted(target: Node2D)
signal target_lost()

@export var cone_angle_deg: float = 90.0
@export var cone_range: float = 200.0
@export var ray_count: int = 7
@export var facing_dir: Vector2 = Vector2.RIGHT
@export var target_group: StringName = &"player"
@export var collision_mask: int = 1

var current_target: Node2D = null

func is_point_in_cone(point: Vector2) -> bool:
	var parent_pos: Vector2 = position
	var rot: float = rotation
	if is_inside_tree():
		parent_pos = global_position
		rot = global_rotation
		if get_parent() is Node2D:
			parent_pos = get_parent().global_position
	
	var to_point = point - parent_pos
	var dist = to_point.length()
	if dist > cone_range:
		return false
	if dist == 0.0:
		return true
	
	var global_facing = facing_dir.rotated(rot).normalized()
	var angle = global_facing.angle_to(to_point)
	var half_angle_rad = deg_to_rad(cone_angle_deg) / 2.0
	return abs(angle) <= half_angle_rad

func detect(world_2d: World2D) -> Node2D:
	if world_2d == null:
		return null
	var direct_space_state = world_2d.direct_space_state
	if direct_space_state == null:
		return null
	
	var parent_pos: Vector2 = position
	var rot: float = rotation
	if is_inside_tree():
		parent_pos = global_position
		rot = global_rotation
		if get_parent() is Node2D:
			parent_pos = get_parent().global_position
	
	var exclude_list: Array[RID] = []
	var parent = get_parent()
	if parent and parent.has_method("get_rid"):
		exclude_list.append(parent.get_rid())
	
	var global_facing = facing_dir.rotated(rot).normalized()
	var angles = []
	if ray_count <= 1:
		angles.push_back(0.0)
	else:
		var half_angle = cone_angle_deg / 2.0
		for i in range(ray_count):
			var t = float(i) / float(ray_count - 1)
			var angle_deg = -half_angle + t * cone_angle_deg
			angles.push_back(angle_deg)
	
	var closest_target: Node2D = null
	var min_distance: float = INF
	
	for angle_deg in angles:
		var ray_dir = global_facing.rotated(deg_to_rad(angle_deg)).normalized()
		var end_pos = parent_pos + ray_dir * cone_range
		var query = PhysicsRayQueryParameters2D.create(parent_pos, end_pos, collision_mask, exclude_list)
		var result = direct_space_state.intersect_ray(query)
		if not result.is_empty():
			var collider = result.collider
			if collider and collider.is_in_group(target_group):
				var dist = parent_pos.distance_to(collider.global_position)
				if dist < min_distance:
					min_distance = dist
					closest_target = collider
	
	if closest_target != current_target:
		if closest_target != null:
			target_spotted.emit(closest_target)
		else:
			target_lost.emit()
		current_target = closest_target
	
	return closest_target
