extends Node

## Global event bus for decoupled communication.
## Inventory, Pickups, and Hotbar all talk exclusively through these signals.

signal item_picked_up(item_id: StringName, quantity: int)
signal item_used(item_id: StringName)
signal inventory_changed(snapshot: Dictionary)
signal inventory_full()
