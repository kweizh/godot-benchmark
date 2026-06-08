extends Control

func _ready() -> void:
	EventBus.inventory_changed.connect(_on_inventory_changed)

func _on_inventory_changed(snapshot: Dictionary) -> void:
	var keys = snapshot.keys()
	var labels = get_children()
	for i in range(labels.size()):
		var label = labels[i] as Label
		if not label: continue
		if i < keys.size():
			var item_id = keys[i]
			var quantity = snapshot[item_id]
			label.text = str(item_id) + " x" + str(quantity)
			label.show()
		else:
			label.hide()
