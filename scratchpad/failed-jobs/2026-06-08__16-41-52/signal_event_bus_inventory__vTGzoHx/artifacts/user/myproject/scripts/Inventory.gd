extends Node

## Inventory system — fully decoupled.
## Listens to EventBus.item_picked_up and EventBus.item_used.
## Emits EventBus.inventory_changed on every mutation.
## Emits EventBus.inventory_full when at capacity and a new item is refused.

@export var max_slots: int = 8

var _items: Dictionary = {}  # item_id (StringName) -> quantity (int)


func _ready() -> void:
	EventBus.item_picked_up.connect(_on_item_picked_up)
	EventBus.item_used.connect(_on_item_used)


func _on_item_picked_up(item_id: StringName, quantity: int) -> void:
	if item_id in _items:
		_items[item_id] += quantity
	else:
		if _items.size() >= max_slots:
			EventBus.inventory_full.emit()
			return
		_items[item_id] = quantity
	EventBus.inventory_changed.emit(_snapshot())


func _on_item_used(item_id: StringName) -> void:
	if not item_id in _items:
		return
	_items[item_id] -= 1
	if _items[item_id] <= 0:
		_items.erase(item_id)
	EventBus.inventory_changed.emit(_snapshot())


func _snapshot() -> Dictionary:
	# Return a copy so callers can't mutate internal state.
	return _items.duplicate()
