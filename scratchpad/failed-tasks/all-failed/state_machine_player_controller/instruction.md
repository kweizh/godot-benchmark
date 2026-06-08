# Finite State Machine Player Controller (Godot 4)

Build a Godot 4 (headless `godot`, >= 4.3) project at `/home/user/state_machine_player` that implements a finite state machine player controller for a 2D platformer.

## Acceptance Criteria

- Project root: `/home/user/state_machine_player` with a valid `project.godot`.
- Required files (relative to project root):
  - `scripts/states/State.gd`
  - `scripts/states/IdleState.gd`
  - `scripts/states/RunState.gd`
  - `scripts/states/JumpState.gd`
  - `scripts/states/FallState.gd`
  - `scripts/states/AttackState.gd`
  - `scripts/StateMachine.gd`
  - `scripts/Player.gd`
  - `scenes/Player.tscn`
- `class_name` declarations:
  - `State` extends `Node`.
  - `StateMachine` extends `Node` and declares `signal state_changed`.
  - Each concrete state (`IdleState`, `RunState`, `JumpState`, `FallState`, `AttackState`) extends `State`.
- `Player.tscn` root is a `CharacterBody2D` with a `StateMachine` child whose own children are named exactly `Idle`, `Run`, `Jump`, `Fall`, `Attack`.
- `project.godot` defines an `attack` input action under `[input]`, bound to the `J` key (keycode 74).
- `StateMachine.state_changed(prev: StringName, next: StringName)` is emitted on every transition; transition requests to unknown names are ignored.
- Transition rules (observable via headless harness using `Input.action_press`/`Input.action_release` and stepped physics frames):
  - `Idle <-> Run` on horizontal input (`ui_left` / `ui_right`).
  - Grounded -> `Jump` on `ui_accept` while `is_on_floor()`.
  - `Jump` -> `Fall` once `velocity.y > 0`.
  - `Fall` -> `Idle` once back on the floor.
  - Any grounded state -> `Attack` on the `attack` action.
  - `Attack` -> `Idle` between 0.3 s and 0.6 s later.
- Project loads cleanly: `godot --headless --path /home/user/state_machine_player --quit` exits 0 with no `SCRIPT ERROR`, `Parse Error`, or `Failed to load` lines.
