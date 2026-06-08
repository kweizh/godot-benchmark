extends Node

@export var max_slots: int = 8

var _items: Dictionary = {}

func _ready() -> void:
	EventBus.item_picked_up.connect(_on_item_picked_up)
	EventBus.item_used.connect(_on_item_used)

func _on_item_picked_up(item_id: StringName, quantity: int) -> void:
	if _items.has(item_id):
		_items[item_id] += quantity
		EventBus.inventory_changed.emit(_items.duplicate())
	else:
		if _items.size() >= max_slots:
			EventBus.inventory_full.emit()
		else:
			_items[item_id] = quantity
			EventBus.inventory_changed.emit(_items.duplicate())

func _on_item_used(item_id: StringName) -> void:
	if _items.has(item_id):
		_items[item_id] -= 1
		if _items[item_id] <= 0:
			_items.erase(item_id)
		EventBus.inventory_changed.emit(_items.duplicate())
