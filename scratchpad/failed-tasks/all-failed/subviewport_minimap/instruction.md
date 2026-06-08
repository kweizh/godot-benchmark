# SubViewport Minimap

Build a SubViewport-based minimap that tracks the player and POIs in a Godot 4 project located at `/home/user/myproject`.

## Acceptance Criteria

- Project path: `/home/user/myproject`. The project must load with `godot --headless --path /home/user/myproject` without errors.
- `scenes/Minimap.tscn` exists. Its root is a `SubViewportContainer` containing a child `SubViewport`.
- The `SubViewport` has `size == Vector2i(256, 256)` and `transparent_bg == true`.
- The `SubViewport` contains a `Camera2D` whose `zoom == Vector2(0.1, 0.1)` and is current within that SubViewport.
- `scenes/World.tscn` exists. Its root is a `Node2D` named `World`, containing a `CharacterBody2D` named `Player` and at least three `Node2D` children added to the group `poi`.
- `scripts/Minimap.gd` is attached to the Minimap scene root and declares:
  - `@export var world_root: NodePath`
  - `@export var player_path: NodePath`
  - `signal poi_added(poi_index: int)`
  - `func get_marker_for_poi(index: int) -> Node2D`
- When the Minimap is added to a tree alongside the World and the export paths are wired up:
  - One POI marker is created per node in group `poi`, and `poi_added` is emitted exactly that many times.
  - After setting the Player's `global_position` to `(123, -45)` and waiting one process frame, the player marker's position equals `(123, -45)` within `0.01`.
  - `get_marker_for_poi(0)` returns a non-null `Node2D` whose position equals the first POI's world position within `0.01`.
