extends Control

signal back_pressed

func _enter_tree() -> void:
	# _enter_tree fires before _ready but after the node joins the tree.
	# Fix up connections to be non-deferred so signal fires synchronously.
	var slider: HSlider = $VBoxContainer/VolumeSlider
	var option: OptionButton = $VBoxContainer/ResolutionOption
	var checkbox: CheckBox = $VBoxContainer/FullscreenCheck

	if slider.value_changed.is_connected(_on_volume_changed):
		slider.value_changed.disconnect(_on_volume_changed)
	slider.value_changed.connect(_on_volume_changed)

	if option.item_selected.is_connected(_on_resolution_selected):
		option.item_selected.disconnect(_on_resolution_selected)
	option.item_selected.connect(_on_resolution_selected)

	if checkbox.toggled.is_connected(_on_fullscreen_toggled):
		checkbox.toggled.disconnect(_on_fullscreen_toggled)
	checkbox.toggled.connect(_on_fullscreen_toggled)

func _ready() -> void:
	var slider: HSlider = $VBoxContainer/VolumeSlider
	var option: OptionButton = $VBoxContainer/ResolutionOption
	var checkbox: CheckBox = $VBoxContainer/FullscreenCheck

	# Read existing values from GameSettings without triggering value_changed
	slider.set_value_no_signal(GameSettings.volume)
	option.selected = GameSettings.resolution_index
	checkbox.set_pressed_no_signal(GameSettings.fullscreen)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_back"):
		_on_back_pressed()

func _on_volume_changed(value: float) -> void:
	GameSettings.set_volume(value)

func _on_resolution_selected(index: int) -> void:
	GameSettings.set_resolution_index(index)

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	GameSettings.set_fullscreen(toggled_on)

func _on_back_pressed() -> void:
	emit_signal("back_pressed")
