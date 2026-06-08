extends SceneTree

const VisionConeScript = preload("res://scripts/VisionCone.gd")

var results := {"assertions": {}, "errors": []}

func _initialize() -> void:
    _bootstrap.call_deferred()

func _bootstrap() -> void:
    await process_frame
    await physics_frame

    _test_is_point_in_cone_inside()
    _test_is_point_in_cone_outside_angle()
    await _test_detect_visible_in_range()
    await _test_detect_out_of_range()
    await _test_detect_blocked_by_wall()
    await _test_target_spotted_emitted_once()

    _save_results()
    quit()

func _record(test_name: String, ok: bool, info: Dictionary = {}) -> void:
    results.assertions[test_name] = {"passed": ok, "info": info}
    var status := "PASS" if ok else "FAIL"
    print("[%s] %s — %s" % [status, test_name, str(info)])

func _make_cone(parent_node: Node, pos: Vector2 = Vector2.ZERO) -> Array:
    var holder := Node2D.new()
    parent_node.add_child(holder)
    holder.global_position = pos
    var cone = VisionConeScript.new()
    cone.facing_dir = Vector2.RIGHT
    cone.cone_angle_deg = 90.0
    cone.cone_range = 200.0
    cone.ray_count = 7
    cone.target_group = &"player"
    cone.collision_mask = 1
    holder.add_child(cone)
    return [holder, cone]

func _make_player(parent_node: Node, pos: Vector2) -> StaticBody2D:
    var player := StaticBody2D.new()
    player.add_to_group("player")
    player.collision_layer = 1
    player.collision_mask = 1
    var col := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(8, 8)
    col.shape = shape
    player.add_child(col)
    parent_node.add_child(player)
    player.global_position = pos
    return player

func _make_wall(parent_node: Node, pos: Vector2, size: Vector2) -> StaticBody2D:
    var wall := StaticBody2D.new()
    wall.collision_layer = 1
    wall.collision_mask = 1
    var col := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = size
    col.shape = shape
    wall.add_child(col)
    parent_node.add_child(wall)
    wall.global_position = pos
    return wall

func _cleanup(node: Node) -> void:
    node.queue_free()
    await process_frame
    await physics_frame

func _test_is_point_in_cone_inside() -> void:
    var holder := Node2D.new()
    root.add_child(holder)
    holder.global_position = Vector2.ZERO
    var cone = VisionConeScript.new()
    cone.facing_dir = Vector2.RIGHT
    cone.cone_angle_deg = 90.0
    cone.cone_range = 200.0
    holder.add_child(cone)
    var got = cone.is_point_in_cone(Vector2(50, 0))
    _record("is_point_in_cone_inside", got == true, {"got": got})
    holder.queue_free()

func _test_is_point_in_cone_outside_angle() -> void:
    var holder := Node2D.new()
    root.add_child(holder)
    holder.global_position = Vector2.ZERO
    var cone = VisionConeScript.new()
    cone.facing_dir = Vector2.RIGHT
    cone.cone_angle_deg = 90.0
    cone.cone_range = 200.0
    holder.add_child(cone)
    var got = cone.is_point_in_cone(Vector2(-50, 0))
    _record("is_point_in_cone_outside_angle", got == false, {"got": got})
    holder.queue_free()

func _test_detect_visible_in_range() -> void:
    var container := Node2D.new()
    root.add_child(container)
    var pair = _make_cone(container, Vector2.ZERO)
    var cone = pair[1]
    var player = _make_player(container, Vector2(50, 0))
    await physics_frame
    await physics_frame
    var got = cone.detect(container.get_world_2d())
    _record("detect_visible_in_range", got == player, {"got_path": str(got), "expected_path": str(player)})
    await _cleanup(container)

func _test_detect_out_of_range() -> void:
    var container := Node2D.new()
    root.add_child(container)
    var pair = _make_cone(container, Vector2.ZERO)
    var cone = pair[1]
    var _player = _make_player(container, Vector2(300, 0))
    await physics_frame
    await physics_frame
    var got = cone.detect(container.get_world_2d())
    _record("detect_out_of_range", got == null, {"got_path": str(got)})
    await _cleanup(container)

func _test_detect_blocked_by_wall() -> void:
    var container := Node2D.new()
    root.add_child(container)
    var pair = _make_cone(container, Vector2.ZERO)
    var cone = pair[1]
    var _wall = _make_wall(container, Vector2(25, 0), Vector2(10, 200))
    var _player = _make_player(container, Vector2(50, 0))
    await physics_frame
    await physics_frame
    var got = cone.detect(container.get_world_2d())
    _record("detect_blocked_by_wall", got == null, {"got_path": str(got)})
    await _cleanup(container)

func _test_target_spotted_emitted_once() -> void:
    var container := Node2D.new()
    root.add_child(container)
    var pair = _make_cone(container, Vector2.ZERO)
    var cone = pair[1]
    var player = _make_player(container, Vector2(-50, 0))
    var counter := {"count": 0}
    cone.target_spotted.connect(func(_t): counter.count += 1)
    await physics_frame
    await physics_frame
    cone.detect(container.get_world_2d())
    player.global_position = Vector2(50, 0)
    await physics_frame
    await physics_frame
    cone.detect(container.get_world_2d())
    cone.detect(container.get_world_2d())
    var ok = counter.count == 1
    _record("target_spotted_emitted_once", ok, {"emit_count": counter.count})
    await _cleanup(container)

func _save_results() -> void:
    var path := "res://test_results.json"
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        push_error("Cannot open results file at %s" % path)
        return
    f.store_string(JSON.stringify(results, "  "))
    f.close()
