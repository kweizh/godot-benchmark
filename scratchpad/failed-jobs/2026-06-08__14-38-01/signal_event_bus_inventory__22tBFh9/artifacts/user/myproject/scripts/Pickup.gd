extends Area2D

@export var item_id: StringName
@export var quantity: int = 1

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		EventBus.item_picked_up.emit(item_id, quantity)
		queue_free()
