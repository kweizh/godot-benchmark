extends Control

@export var max_slots: int = 8

var _labels: Array[Label] = []

func _ready() -> void:
	# Find all pre-existing Label children
	_labels.clear()
	for child in get_children():
		if child is Label:
			_labels.append(child)
	
	# If we don't have enough, or if we want to ensure exactly max_slots:
	while _labels.size() < max_slots:
		var new_label = Label.new()
		add_child(new_label)
		_labels.append(new_label)
	
	# Initially hide all labels
	for label in _labels:
		label.text = ""
		label.visible = false
	
	EventBus.inventory_changed.connect(_on_inventory_changed)

func _on_inventory_changed(snapshot: Dictionary) -> void:
	# Hide all labels first
	for label in _labels:
		label.text = ""
		label.visible = false
	
	# Render populated slots
	var index = 0
	for item_id in snapshot:
		if index >= max_slots:
			break
		var quantity = snapshot[item_id]
		var label = _labels[index]
		label.text = "%s x%d" % [item_id, quantity]
		label.visible = true
		index += 1
