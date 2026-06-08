extends Area2D

## A pickup item that emits EventBus.item_picked_up when a player body enters.
## Fully decoupled — never references Inventory or Hotbar class names.

@export var item_id: StringName = &""
@export var quantity: int = 1


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	EventBus.item_picked_up.emit(item_id, quantity)
	queue_free()
