extends Control

## Mirrors the max_slots value from Inventory so the Hotbar knows how many
## Label children to manage. Must match the Inventory node's setting.
@export var max_slots: int = 8

## Ordered list of slot Label nodes (populated in _ready from children).
var _slot_labels: Array[Label] = []


func _ready() -> void:
	# Collect every direct Label child into the ordered slot list.
	for child in get_children():
		if child is Label:
			_slot_labels.append(child)
			child.hide()

	EventBus.inventory_changed.connect(_on_inventory_changed)


## Receives a snapshot Dictionary { item_id -> quantity } from the bus
## and redraws all slot labels.
func _on_inventory_changed(snapshot: Dictionary) -> void:
	# Build a stable ordered list of entries so slot positions are consistent.
	var entries: Array = []
	for item_id in snapshot:
		entries.append([item_id, snapshot[item_id]])

	for i in range(_slot_labels.size()):
		var label: Label = _slot_labels[i]
		if i < entries.size():
			var item_id: StringName = entries[i][0]
			var qty: int           = entries[i][1]
			label.text = "%s x%d" % [item_id, qty]
			label.show()
		else:
			label.text = ""
			label.hide()
