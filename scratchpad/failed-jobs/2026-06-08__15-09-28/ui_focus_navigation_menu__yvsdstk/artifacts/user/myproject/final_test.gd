extends SceneTree

# Simulates the verifier's expected behavior
var step := 0
var ru: Node
var gs: Node
var sm3: Node
var sig_count := 0

func _initialize() -> void:
	gs = get_root().get_node("GameSettings")
	
	# T1: Input map
	var ok_esc := false
	var ok_joy := false
	for ev in InputMap.action_get_events("ui_back"):
		if ev is InputEventKey and ev.keycode == KEY_ESCAPE: ok_esc = true
		if ev is InputEventJoypadButton and ev.button_index == 1: ok_joy = true
	assert(ok_esc, "T1a FAIL")
	assert(ok_joy, "T1b FAIL")
	print("T1 PASS: ui_back has Escape and JoypadButton(1)")
	
	# T2: GameSettings autoload
	assert(gs != null, "T2 FAIL: no GameSettings")
	assert(gs.has_signal("settings_changed"), "T2 FAIL: no signal")
	print("T2 PASS: GameSettings autoload OK")
	
	# T3: MainMenu structure
	var mm_s = load("res://scenes/MainMenu.tscn").instantiate()
	var vbox = mm_s.get_node("VBoxContainer")
	var btns: Array = []
	for c in vbox.get_children():
		if c is Button: btns.append(c)
	assert(btns.size() == 3, "T3 FAIL: button count " + str(btns.size()))
	assert(btns[0].text == "Play", "T3 FAIL: btn0=" + btns[0].text)
	assert(btns[1].text == "Settings", "T3 FAIL: btn1=" + btns[1].text)
	assert(btns[2].text == "Quit", "T3 FAIL: btn2=" + btns[2].text)
	# Focus neighbors (resolve from button)
	assert(btns[0].get_node(btns[0].focus_neighbor_bottom) == btns[1], "T3 FAIL: Play.bottom!=Settings")
	assert(btns[1].get_node(btns[1].focus_neighbor_bottom) == btns[2], "T3 FAIL: Settings.bottom!=Quit")
	assert(btns[2].get_node(btns[2].focus_neighbor_bottom) == btns[0], "T3 FAIL: Quit.bottom!=Play")
	assert(btns[0].get_node(btns[0].focus_neighbor_top) == btns[2], "T3 FAIL: Play.top!=Quit")
	assert(btns[1].get_node(btns[1].focus_neighbor_top) == btns[0], "T3 FAIL: Settings.top!=Play")
	assert(btns[2].get_node(btns[2].focus_neighbor_top) == btns[1], "T3 FAIL: Quit.top!=Settings")
	print("T3 PASS: MainMenu buttons and focus neighbors OK")
	
	# T4: SettingsMenu structure (just check it loads; signals checked later after _ready)
	var sm_s = load("res://scenes/SettingsMenu.tscn").instantiate()
	var slider = _find(sm_s, "HSlider")
	var option = _find(sm_s, "OptionButton")
	var cbox = _find(sm_s, "CheckBox")
	var backbtn = _find_back(sm_s)
	assert(slider != null, "T4 FAIL: no HSlider")
	assert(option != null, "T4 FAIL: no OptionButton")
	assert(option.item_count == 3, "T4 FAIL: items=" + str(option.item_count))
	assert(cbox != null, "T4 FAIL: no CheckBox")
	assert(backbtn != null, "T4 FAIL: no Back button")
	print("T4 PASS: SettingsMenu structure OK")
	
	# Load RootUI for frame-based tests
	ru = load("res://scenes/RootUI.tscn").instantiate()
	get_root().add_child(ru)
	
	# Set up GameSettings for T8
	gs.volume = 0.7
	gs.resolution_index = 2
	gs.fullscreen = true
	sm3 = load("res://scenes/SettingsMenu.tscn").instantiate()
	get_root().add_child(sm3)

func _process(_delta: float) -> bool:
	step += 1
	
	if step == 1:
		# _ready has now run on ru and sm3
		var mm = ru.get_node("MainMenu")
		var sm = ru.get_node("SettingsMenu")
		
		# T5: RootUI visibility
		assert(mm.visible == true, "T5 FAIL: MainMenu not visible")
		assert(sm.visible == false, "T5 FAIL: SettingsMenu visible")
		print("T5 PASS: RootUI _ready visibility OK")
		
		# T6 setup: make SettingsMenu visible, press ui_back
		sm.visible = true
		mm.visible = false
		Input.action_press("ui_back")
		
		# T7 setup: connect signal and set slider value
		gs.volume = 1.0  # reset
		gs.settings_changed.connect(func(): sig_count += 1)
		var slider = _find(sm, "HSlider")
		slider.value = 0.42
		# Check T7 immediately (connection is non-deferred after _ready)
		assert(gs.volume == 0.42, "T7 FAIL: gs.volume=" + str(gs.volume))
		assert(sig_count >= 1, "T7 FAIL: sig_count=" + str(sig_count))
		print("T7 PASS: HSlider->GameSettings.volume=0.42, settings_changed emitted")
		
		return false
	
	elif step == 2:
		Input.action_release("ui_back")
		var mm = ru.get_node("MainMenu")
		var sm = ru.get_node("SettingsMenu")
		assert(sm.visible == false, "T6 FAIL: SettingsMenu still visible after ui_back")
		assert(mm.visible == true, "T6 FAIL: MainMenu not visible after ui_back")
		print("T6 PASS: ui_back hides SettingsMenu, shows MainMenu")
		
		# T8: sm3 _ready read from GameSettings (gs.volume=0.7, res=2, fullscreen=true)
		var sl3: HSlider = _find(sm3, "HSlider")
		var op3: OptionButton = _find(sm3, "OptionButton")
		var cb3: CheckBox = _find(sm3, "CheckBox")
		assert(sl3.value == 0.7, "T8 FAIL: slider=" + str(sl3.value))
		assert(op3.selected == 2, "T8 FAIL: option=" + str(op3.selected))
		assert(cb3.button_pressed == true, "T8 FAIL: checkbox=" + str(cb3.button_pressed))
		print("T8 PASS: SettingsMenu _ready reads GameSettings values")
		
		print("=== ALL TESTS PASSED ===")
		quit(0)
	
	return false

func _find(n: Node, t: String) -> Node:
	if n.get_class() == t: return n
	for c in n.get_children():
		var r = _find(c, t)
		if r: return r
	return null

func _find_back(n: Node) -> Button:
	if n is Button and n.text == "Back": return n
	for c in n.get_children():
		var r = _find_back(c)
		if r: return r
	return null
