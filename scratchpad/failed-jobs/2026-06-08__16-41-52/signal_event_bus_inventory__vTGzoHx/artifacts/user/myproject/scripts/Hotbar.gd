extends Control

## Hotbar UI that renders inventory contents.
## Subscribes to EventBus.inventory_changed.
## Fully decoupled — never references Inventory or Pickup class names.

const MAX_SLOTS: int = 8


func _ready() -> void:
	EventBus.inventory_changed.connect(_on_inventory_changed)
	# Hide all labels initially.
	for i in range(MAX_SLOTS):
		var label: Label = _get_slot_label(i)
		if label:
			label.hide()


func _on_inventory_changed(snapshot: Dictionary) -> void:
	var keys: Array = snapshot.keys()
	for i in range(MAX_SLOTS):
		var label: Label = _get_slot_label(i)
		if not label:
			continue
		if i < keys.size():
			var item_id: StringName = keys[i]
			var qty: int = snapshot[item_id]
			label.text = str(item_id) + " x" + str(qty)
			label.show()
		else:
			label.hide()


func _get_slot_label(index: int) -> Label:
	# Child nodes are named "Slot0", "Slot1", etc.
	return get_node_or_null("Slot%d" % index) as Label
