extends Control

@export var max_slots: int = 8

var _labels: Array[Label] = []


func _ready() -> void:
	for i in max_slots:
		var label := Label.new()
		label.name = "Slot%d" % i
		label.visible = false
		add_child(label)
		_labels.append(label)
	EventBus.inventory_changed.connect(_on_inventory_changed)


func _on_inventory_changed(snapshot: Dictionary) -> void:
	var keys: Array = snapshot.keys()
	for i in range(_labels.size()):
		if i < keys.size():
			var item_id: Variant = keys[i]
			var qty: Variant = snapshot[item_id]
			_labels[i].text = "%s x%d" % [item_id, qty]
			_labels[i].visible = true
		else:
			_labels[i].visible = false