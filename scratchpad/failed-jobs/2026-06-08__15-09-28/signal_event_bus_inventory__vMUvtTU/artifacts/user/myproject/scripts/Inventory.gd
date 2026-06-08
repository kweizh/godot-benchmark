extends Node

## Maximum number of distinct item types this inventory can hold.
@export var max_slots: int = 8

## Internal storage: maps item_id (StringName) -> quantity (int).
var _items: Dictionary = {}


func _ready() -> void:
	# Connect to the event bus — inventory reacts to pickup and use events
	# without being directly referenced by Pickup or any other scene.
	EventBus.item_picked_up.connect(_on_item_picked_up)
	EventBus.item_used.connect(_on_item_used)


## Called when EventBus emits item_picked_up.
## Refuses to add a brand-new item type when the inventory is already full.
func _on_item_picked_up(item_id: StringName, quantity: int) -> void:
	if not _items.has(item_id):
		# Would occupy a new slot — check capacity first.
		if _items.size() >= max_slots:
			EventBus.inventory_full.emit()
			return
		_items[item_id] = 0

	_items[item_id] += quantity
	EventBus.inventory_changed.emit(_items.duplicate())


## Called when EventBus emits item_used.
## Decrements quantity by 1; removes the entry when it reaches zero.
func _on_item_used(item_id: StringName) -> void:
	if not _items.has(item_id):
		return

	_items[item_id] -= 1
	if _items[item_id] <= 0:
		_items.erase(item_id)

	EventBus.inventory_changed.emit(_items.duplicate())
