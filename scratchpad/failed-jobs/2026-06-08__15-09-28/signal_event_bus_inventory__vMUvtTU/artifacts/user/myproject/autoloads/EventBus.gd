extends Node

## Central signal bus for decoupled communication between game systems.
## All gameplay events are routed through this singleton so that emitters
## and listeners never hold direct references to each other.

## Emitted when the player picks up an item in the world.
signal item_picked_up(item_id: StringName, quantity: int)

## Emitted when the player uses an item from their inventory.
signal item_used(item_id: StringName)

## Emitted whenever the inventory contents change.
## snapshot is a copy of the current { item_id -> quantity } dictionary.
signal inventory_changed(snapshot: Dictionary)

## Emitted when the inventory is full and a new distinct item cannot be added.
signal inventory_full()
