extends SceneTree

func _init() -> void:
	print("=== Starting validation ===")

	# Load RootUI scene
	var root_ui_packed: PackedScene = load("res://scenes/RootUI.tscn")
	if root_ui_packed == null:
		printerr("FAIL: Could not load RootUI.tscn")
		quit(1)
		return

	var root_ui: Node = root_ui_packed.instantiate()
	root.add_child(root_ui)

	await process_frame

	# Check MainMenu is visible, SettingsMenu is hidden
	var main_menu: Control = root_ui.get_node("MainMenu")
	var settings_menu: Control = root_ui.get_node("SettingsMenu")

	if not main_menu.visible:
		printerr("FAIL: MainMenu is not visible on _ready")
		quit(1)
		return
	if settings_menu.visible:
		printerr("FAIL: SettingsMenu is visible on _ready")
		quit(1)
		return

	print("PASS: MainMenu visible, SettingsMenu hidden on _ready")

	# Test settings visibility toggle via ui_back
	settings_menu.visible = true
	main_menu.visible = false
	await process_frame

	var ev := InputEventAction.new()
	ev.action = "ui_back"
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame

	if settings_menu.visible:
		printerr("FAIL: SettingsMenu still visible after ui_back")
		quit(1)
		return
	if not main_menu.visible:
		printerr("FAIL: MainMenu not visible after ui_back")
		quit(1)
		return

	print("PASS: ui_back hides SettingsMenu and shows MainMenu")

	# Test HSlider -> GameSettings.volume and signal
	settings_menu.visible = true
	main_menu.visible = false
	await process_frame

	var signal_fired := false
	GameSettings.settings_changed.connect(func(): signal_fired = true)

	var h_slider: HSlider = settings_menu.get_node("CenterContainer/Panel/VBoxContainer/VolumeSlider")
	h_slider.value = 0.42
	await process_frame

	if not is_equal_approx(GameSettings.volume, 0.42):
		printerr("FAIL: GameSettings.volume is %f, expected 0.42" % GameSettings.volume)
		quit(1)
		return

	if not signal_fired:
		printerr("FAIL: settings_changed signal was not emitted")
		quit(1)
		return

	print("PASS: GameSettings.volume = %f and settings_changed emitted" % GameSettings.volume)

	# Test that settings are read back in _ready
	settings_menu.queue_free()
	await process_frame

	var settings_packed: PackedScene = load("res://scenes/SettingsMenu.tscn")
	var new_settings: Control = settings_packed.instantiate()
	new_settings.name = "SettingsMenu"
	root_ui.add_child(new_settings)
	await process_frame

	var new_slider: HSlider = new_settings.get_node("CenterContainer/Panel/VBoxContainer/VolumeSlider")
	if not is_equal_approx(new_slider.value, GameSettings.volume):
		printerr("FAIL: New SettingsMenu slider value is %f, expected %f" % [new_slider.value, GameSettings.volume])
		quit(1)
		return

	print("PASS: SettingsMenu _ready reads GameSettings values into controls")

	# Check MainMenu scene structure (independent instantiation)
	var main_menu_packed: PackedScene = load("res://scenes/MainMenu.tscn")
	var main_menu_instance: Node = main_menu_packed.instantiate()
	var vbox: VBoxContainer = main_menu_instance.get_node("CenterContainer/Panel/VBoxContainer")
	if vbox == null:
		printerr("FAIL: MainMenu has no VBoxContainer")
		quit(1)
		return

	var buttons := vbox.get_children()
	var expected_texts := ["Play", "Settings", "Quit"]
	if buttons.size() != 3:
		printerr("FAIL: VBoxContainer has %d children, expected 3" % buttons.size())
		quit(1)
		return

	for i in 3:
		if not (buttons[i] is Button):
			printerr("FAIL: Child %d is not a Button" % i)
			quit(1)
			return
		if buttons[i].text != expected_texts[i]:
			printerr("FAIL: Button %d text is '%s', expected '%s'" % [i, buttons[i].text, expected_texts[i]])
			quit(1)
			return

	print("PASS: MainMenu VBoxContainer has 3 buttons: Play, Settings, Quit")

	# Check focus neighbors (wrap-around)
	var play_btn: Button = buttons[0]
	var settings_btn: Button = buttons[1]
	var quit_btn: Button = buttons[2]

	if play_btn.focus_neighbor_top != quit_btn.get_path():
		printerr("FAIL: Play focus_neighbor_top is wrong")
		quit(1)
		return
	if play_btn.focus_neighbor_bottom != settings_btn.get_path():
		printerr("FAIL: Play focus_neighbor_bottom is wrong")
		quit(1)
		return

	if settings_btn.focus_neighbor_top != play_btn.get_path():
		printerr("FAIL: Settings focus_neighbor_top is wrong")
		quit(1)
		return
	if settings_btn.focus_neighbor_bottom != quit_btn.get_path():
		printerr("FAIL: Settings focus_neighbor_bottom is wrong")
		quit(1)
		return

	if quit_btn.focus_neighbor_top != settings_btn.get_path():
		printerr("FAIL: Quit focus_neighbor_top is wrong")
		quit(1)
		return
	if quit_btn.focus_neighbor_bottom != play_btn.get_path():
		printerr("FAIL: Quit focus_neighbor_bottom is wrong")
		quit(1)
		return

	print("PASS: Focus neighbors form wrap-around: Play -> Settings -> Quit -> Play")

	# Check SettingsMenu structure has required controls
	var settings_packed2: PackedScene = load("res://scenes/SettingsMenu.tscn")
	var settings_instance: Node = settings_packed2.instantiate()

	var result := _find_controls(settings_instance)
	if not result.has_slider:
		printerr("FAIL: SettingsMenu has no HSlider")
		quit(1)
		return
	if not result.has_option:
		printerr("FAIL: SettingsMenu has no OptionButton with 3 items")
		quit(1)
		return
	if not result.has_checkbox:
		printerr("FAIL: SettingsMenu has no CheckBox")
		quit(1)
		return
	if not result.has_back:
		printerr("FAIL: SettingsMenu has no Back button")
		quit(1)
		return

	print("PASS: SettingsMenu has HSlider, OptionButton(3 items), CheckBox, and Back button")
	print("=== ALL CHECKS PASSED ===")
	quit(0)


func _find_controls(node: Node) -> Dictionary:
	var r := {"has_slider": false, "has_option": false, "has_checkbox": false, "has_back": false}
	_find_recursive(node, r)
	return r


func _find_recursive(node: Node, result: Dictionary) -> void:
	if node is HSlider:
		result.has_slider = true
	if node is OptionButton:
		if node.item_count == 3:
			result.has_option = true
	if node is CheckBox:
		result.has_checkbox = true
	if node is Button and node.text == "Back":
		result.has_back = true
	for child in node.get_children():
		_find_recursive(child, result)
