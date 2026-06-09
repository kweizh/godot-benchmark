# Behavior Tree Enemy AI in Godot 4 GDScript

## Background
You are extending a Godot 4 project with a reusable, pure-GDScript Behavior Tree (BT) library implemented entirely with custom `Resource` classes, plus a concrete enemy AI tree built on top of it. The library must be self-contained (no external addons, no scenes for tree nodes themselves) and must be driveable by a plain `Dictionary` blackboard that holds the AI's perception and side-effect state. The library will be exercised by an external test driver that constructs scenarios, mutates the blackboard between ticks, and asserts the tree's return statuses and side effects on the blackboard.

## Requirements
- Implement the BT library as `Resource`-derived classes with the listed `class_name` identifiers.
- The BT node base type must define three integer status constants: `SUCCESS = 0`, `FAILURE = 1`, `RUNNING = 2`, and a virtual instance method `tick(blackboard: Dictionary) -> int`.
- Implement a composite node base concept holding an ordered list of children, plus the two listed composite kinds, the listed decorator, and the listed action base type.
- Implement five concrete action node types that read from and write to the blackboard with the exact semantics described below.
- Implement a factory class that builds the concrete enemy AI tree and returns its root.
- The implementation must be deterministic: identical blackboard inputs across ticks must produce identical outputs and identical mutations.
- Everything must run under Godot 4 in `--headless` mode without an editor session.

## Class and File Layout
- Project path: `/home/user/myproject`.
- The Godot project must declare a `project.godot` with `config_version=5` and any GDScript-only feature flags it needs. No scenes are required.
- Source files live directly under `res://` (subdirectories are allowed but the `class_name` identifiers listed below are what matters; tests resolve everything by `class_name`).
- Required `class_name` identifiers (each in its own `.gd` file extending `Resource` or a previously listed class):
  - `BTNode` (extends `Resource`)
  - `BTSelector` (extends `BTNode`)
  - `BTSequence` (extends `BTNode`)
  - `BTInverter` (extends `BTNode`)
  - `BTAction` (extends `BTNode`)
  - `IsHealthy` (extends `BTAction`)
  - `FleeAction` (extends `BTAction`)
  - `PatrolUntilSpotted` (extends `BTAction`)
  - `ChasePlayer` (extends `BTAction`)
  - `AttackIfInRange` (extends `BTAction`)
  - `BTFactory` (extends `RefCounted` or any plain script class)

## Status Constants and `tick` Signature
- The three status constants `SUCCESS = 0`, `FAILURE = 1`, `RUNNING = 2` must be class constants on `BTNode` and resolvable as `BTNode.SUCCESS`, `BTNode.FAILURE`, and `BTNode.RUNNING` from any other script.
- Every BT node class must implement (or inherit) an instance method with the exact signature `func tick(blackboard: Dictionary) -> int` that returns one of the three status constants.

## Composite, Decorator, and Action Semantics
- `BTSelector` holds an ordered list of child `BTNode` instances. Its `tick` iterates children in order: on a child returning `SUCCESS` it returns `SUCCESS` immediately; on `RUNNING` it returns `RUNNING` immediately; on `FAILURE` it continues to the next child. If every child returned `FAILURE`, the selector returns `FAILURE`.
- `BTSequence` holds an ordered list of child `BTNode` instances. Its `tick` iterates children in order: on a child returning `FAILURE` it returns `FAILURE` immediately; on `RUNNING` it returns `RUNNING` immediately; on `SUCCESS` it continues. If every child returned `SUCCESS`, the sequence returns `SUCCESS`.
- `BTInverter` wraps exactly one child `BTNode`. `SUCCESS` becomes `FAILURE`, `FAILURE` becomes `SUCCESS`, and `RUNNING` stays `RUNNING`.
- `BTAction` is the base for leaf action nodes; its default `tick` may return `FAILURE` and is meant to be overridden.
- Action semantics (all read and mutate the same `blackboard: Dictionary`):
  - `IsHealthy`: returns `SUCCESS` if `blackboard["health"] >= blackboard["healthy_threshold"]`, otherwise `FAILURE`. Does not mutate the blackboard.
  - `FleeAction`: sets `blackboard["action"] = "flee"` and returns `SUCCESS`.
  - `PatrolUntilSpotted`: if `blackboard["player_spotted"]` is truthy, returns `SUCCESS` without mutating any other key. Otherwise it sets `blackboard["action"] = "patrol"`, increments `blackboard["patrol_steps"]` by 1, and returns `RUNNING`.
  - `ChasePlayer`: sets `blackboard["action"] = "chase"`. If `blackboard["distance_to_player"] <= blackboard["attack_range"]`, returns `SUCCESS` without mutating distance. Otherwise it subtracts `blackboard["chase_speed"]` from `blackboard["distance_to_player"]` and returns `RUNNING`.
  - `AttackIfInRange`: if `blackboard["distance_to_player"] <= blackboard["attack_range"]`, it sets `blackboard["action"] = "attack"`, sets `blackboard["last_attack_damage"] = blackboard["attack_damage"]`, and returns `SUCCESS`. Otherwise returns `FAILURE` and does not mutate the blackboard.

## Enemy AI Tree Topology
- `BTFactory` must expose a static method `static func build_enemy_tree() -> BTNode` that returns a fully constructed root.
- Topology returned by `build_enemy_tree()`:
  - Root is a `BTSelector` with exactly two children, in this order:
    1. A `BTSequence` with exactly two children, in this order:
       - A `BTInverter` wrapping an `IsHealthy` action.
       - A `FleeAction`.
    2. A `BTSequence` with exactly three children, in this order:
       - A `PatrolUntilSpotted` action.
       - A `ChasePlayer` action.
       - An `AttackIfInRange` action.

## Implementation Hints
- Use `class_name` declarations so the test driver can resolve every BT node type globally without `preload` paths.
- Custom `Resource` classes use `extends Resource` and live in `.gd` files. Composites should store children in a typed `Array[BTNode]`.
- For the deterministic, stateless tree, the BT does not memoize the running child; each `tick` re-evaluates from the root using whatever state the caller leaves on the blackboard.
- Run Godot headlessly with `godot --headless --path /home/user/myproject ...`. A script that extends `SceneTree` can be invoked with `--script res://<file>.gd`.
- No scenes, no nodes, and no input handling are required; all logic flows through `tick(blackboard)`.

## Acceptance Criteria
- Project path: `/home/user/myproject`.
- The Godot project must boot under `godot --headless --path /home/user/myproject` without errors.
- A test driver script will be created by the verifier as `/home/user/myproject/zealt_bt_runner.gd`. It will be invoked exactly as `godot --headless --path /home/user/myproject --script res://zealt_bt_runner.gd`. The driver constructs its own blackboards, calls `BTFactory.build_enemy_tree()`, and ticks the resulting root.
- The driver prints exactly one line beginning with the literal prefix `BT_RESULTS:` followed by a JSON array of per-step records. Each record has the shape `{"label": string, "status": int, "blackboard": object}` where `status` is one of `0`, `1`, or `2` and `blackboard` is the post-tick state of the dictionary passed to `tick`.
- The verifier asserts the recorded `status` and `blackboard` values match the expected scenarios listed in `truth`.
- All `class_name` identifiers listed above must be present in the project's global class index after a headless boot (verifiable with a probe script).

