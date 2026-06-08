class_name Player
extends CharacterBody2D

const GRAVITY := 980.0


func _ready() -> void:
	add_to_group("player")


func _physics_process(delta: float) -> void:
	# Apply gravity when not on floor
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	move_and_slide()
