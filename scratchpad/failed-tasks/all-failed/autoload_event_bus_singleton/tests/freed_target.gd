extends Node

func _handler(_payload) -> void:
	# Intentionally empty; this script exists only so the harness can
	# subscribe a Callable to an Object instance and then free that
	# instance to verify Bus auto-prunes dead subscriptions.
	pass
