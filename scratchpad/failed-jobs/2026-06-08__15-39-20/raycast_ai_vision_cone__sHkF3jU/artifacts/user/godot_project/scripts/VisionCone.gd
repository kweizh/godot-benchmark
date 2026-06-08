class_name VisionCone
extends Node2D

signal target_spotted(target: Node2D)
signal target_lost()

@export var cone_angle_deg: float = 90.0
@export var cone_range: float = 200.0
@export var ray_count: int = 10
@export var facing_dir: Vector2 = Vector2.RIGHT
@export var target_group: StringName = &"player"
@export var collision_mask: int = 1

var _current_target: Node2D = null

func is_point_in_cone(point: Vector2) -> bool:
	var parent = get_parent()
	var origin = parent.global_position if parent and parent is Node2D else global_position
	var to_point = point - origin
	if to_point.length() > cone_range:
		return false
	if to_point.length_squared() == 0:
		return true
	var angle_to_point = facing_dir.angle_to(to_point.normalized())
	if abs(rad_to_deg(angle_to_point)) <= cone_angle_deg / 2.0:
		return true
	return false

func detect(world_2d: World2D) -> Node2D:
	var parent = get_parent()
	var origin = parent.global_position if parent and parent is Node2D else global_position
	var space_state = world_2d.direct_space_state
	
	var closest_target: Node2D = null
	var closest_dist: float = cone_range + 1.0
	
	var start_angle = -deg_to_rad(cone_angle_deg) / 2.0
	var angle_step = deg_to_rad(cone_angle_deg) / max(1, ray_count - 1) if ray_count > 1 else 0.0
	
	for i in range(ray_count):
		var angle = start_angle + i * angle_step
		var ray_dir = facing_dir.rotated(angle)
		var end_pos = origin + ray_dir * cone_range
		
		var query = PhysicsRayQueryParameters2D.create(origin, end_pos, collision_mask)
		var result = space_state.intersect_ray(query)
		
		if result and result.collider is Node2D:
			var collider = result.collider
			if collider.is_in_group(target_group):
				var dist = origin.distance_to(result.position)
				if dist < closest_dist:
					closest_dist = dist
					closest_target = collider
					
	if closest_target != _current_target:
		if closest_target != null:
			target_spotted.emit(closest_target)
		else:
			target_lost.emit()
		_current_target = closest_target
		
	return closest_target
