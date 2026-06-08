extends Control

signal back_pressed

func _ready():
	$VBoxContainer/HSlider.value = GameSettings.volume
	$VBoxContainer/OptionButton.selected = GameSettings.resolution_index
	$VBoxContainer/CheckBox.button_pressed = GameSettings.fullscreen
	
	$VBoxContainer/HSlider.value_changed.connect(func(val): GameSettings.volume = val)
	$VBoxContainer/OptionButton.item_selected.connect(func(idx): GameSettings.resolution_index = idx)
	$VBoxContainer/CheckBox.toggled.connect(func(toggled): GameSettings.fullscreen = toggled)
	$VBoxContainer/Back.pressed.connect(func(): back_pressed.emit())

func _process(_delta):
	if Input.is_action_just_pressed("ui_back") and visible:
		back_pressed.emit()
		get_viewport().set_input_as_handled()
