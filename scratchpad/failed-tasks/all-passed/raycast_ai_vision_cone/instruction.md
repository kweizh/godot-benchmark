# AI Vision Cone — Acceptance Criteria

Project path: `/home/user/godot_project`

- `scripts/VisionCone.gd` exists, declares `class_name VisionCone` (extends `Node2D`), and exports:
  `cone_angle_deg: float`, `cone_range: float`, `ray_count: int`, `facing_dir: Vector2`, `target_group: StringName`, `collision_mask: int`.
- `VisionCone.is_point_in_cone(point: Vector2) -> bool` performs an angle + range check against the parent's world position.
  - With `facing_dir=(1,0)`, `cone_angle_deg=90`, `cone_range=200`, parent at origin: `is_point_in_cone(Vector2(50, 0))` is `true` and `is_point_in_cone(Vector2(-50, 0))` is `false`.
- `VisionCone.detect(world_2d: World2D) -> Node2D` casts `ray_count` rays evenly across the cone using `PhysicsRayQueryParameters2D` + `direct_space_state.intersect_ray`, honors `collision_mask`, and returns the closest visible node in `target_group` (or `null`).
  - Player at `(50, 0)` with clear line-of-sight → returns the player.
  - Player at `(300, 0)` (beyond range 200) → returns `null`.
  - Wall (StaticBody2D + RectangleShape2D) between enemy at `(0, 0)` and player at `(50, 0)` → returns `null`.
- The node defines signals `target_spotted(target: Node2D)` and `target_lost()`. Moving the player from non-visible to visible and invoking `detect()` results in `target_spotted` being emitted exactly once.
- An `Enemy` CharacterBody2D scene contains a `VisionCone` child.
- `tests/cone_test.tscn` contains static walls, the Enemy at the origin facing right, and a `player`-grouped Node2D.

Verification runs `godot --headless --path /home/user/godot_project --script res://tests/run_tests.gd`.
