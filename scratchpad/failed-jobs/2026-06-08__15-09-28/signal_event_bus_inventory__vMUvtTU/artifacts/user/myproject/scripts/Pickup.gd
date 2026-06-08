extends Area2D

## The identifier of the item this pickup represents.
@export var item_id: StringName = &""

## How many units of the item are granted on pickup.
@export var quantity: int = 1


func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Fires the bus event and removes this node when a player body overlaps.
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		EventBus.item_picked_up.emit(item_id, quantity)
		queue_free()
