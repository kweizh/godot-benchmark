# Decoupled Inventory via a Signal Event Bus (Godot 4)

Project path: `/home/user/myproject`

Implement a Godot 4 project that satisfies the following criteria:

- An autoloaded `EventBus` singleton is registered in `project.godot` and points at `res://autoloads/EventBus.gd`.
- `EventBus.gd` declares exactly these signals with these argument names:
  - `item_picked_up(item_id: StringName, quantity: int)`
  - `item_used(item_id: StringName)`
  - `inventory_changed(snapshot: Dictionary)`
  - `inventory_full()`
- `scripts/Inventory.gd` exposes `@export var max_slots: int = 8`, connects to the bus in `_ready`, keeps a `Dictionary` of `item_id -> quantity`, emits `inventory_changed(snapshot)` on every change, and emits `inventory_full` (and refuses to add) once it holds `max_slots` distinct entries.
- `scenes/Pickup.tscn` is an `Area2D` with `@export var item_id: StringName` and `@export var quantity: int`. When a body in group `"player"` enters it emits `EventBus.item_picked_up(item_id, quantity)` and `queue_free`s itself.
- `scenes/Hotbar.tscn` is a `Control` containing `max_slots` child `Label` nodes. It subscribes to `EventBus.inventory_changed` and renders each populated slot as `"<item_id> x<quantity>"`; empty slots are hidden.
- `scripts/Inventory.gd` and the Pickup script must never reference the `Inventory` or `Hotbar` class names — every interaction goes through `EventBus`.

The verifier runs a headless harness that emits signals on `EventBus` and inspects the resulting state.
