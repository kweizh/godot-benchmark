extends Node


func _ready() -> void:
	# 1. Action must be defined in project settings.
	if not InputMap.has_action("attack"):
		printerr("FAIL: `attack` action is not registered in InputMap")
		get_tree().quit(2)
		return

	# 2. There must be at least one InputEventKey bound to keycode J (74).
	var events := InputMap.action_get_events("attack")
	var has_j := false
	for e in events:
		if e is InputEventKey:
			var keycode: int = int((e as InputEventKey).physical_keycode)
			if keycode == 0:
				keycode = int((e as InputEventKey).keycode)
			if keycode == KEY_J or keycode == 74:
				has_j = true
				break
	if not has_j:
		printerr("FAIL: `attack` action has no InputEventKey bound to J (74)")
		get_tree().quit(3)
		return

	# 3. Pressing the action programmatically must be observable.
	Input.action_press("attack")
	await get_tree().process_frame
	if not Input.is_action_pressed("attack"):
		printerr("FAIL: Input.is_action_pressed(\"attack\") returned false after action_press")
		get_tree().quit(4)
		return
	Input.action_release("attack")
	await get_tree().process_frame

	print("ACTION_OK")
	get_tree().quit(0)
