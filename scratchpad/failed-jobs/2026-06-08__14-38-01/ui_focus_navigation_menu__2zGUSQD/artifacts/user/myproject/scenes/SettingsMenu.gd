extends Control

signal back_pressed

@onready var volume_slider: HSlider = $VBoxContainer/VolumeSlider
@onready var resolution_option: OptionButton = $VBoxContainer/ResolutionOption
@onready var fullscreen_check: CheckBox = $VBoxContainer/FullscreenCheck
@onready var back_button: Button = $VBoxContainer/BackButton

# Access the autoload node dynamically to support all execution environments (including -s/--script)
@onready var game_settings = get_node("/root/GameSettings")

func _ready():
	# Load existing settings from GameSettings autoload
	volume_slider.value = game_settings.volume
	
	# OptionButton needs exactly 3 items
	resolution_option.clear()
	resolution_option.add_item("1280x720")
	resolution_option.add_item("1920x1080")
	resolution_option.add_item("2560x1440")
	resolution_option.selected = game_settings.resolution_index
	
	fullscreen_check.button_pressed = game_settings.fullscreen
	
	# Connect signals to update GameSettings autoload
	volume_slider.value_changed.connect(_on_volume_changed)
	resolution_option.item_selected.connect(_on_resolution_selected)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	back_button.pressed.connect(_on_back_pressed)

func _process(_delta):
	if visible and Input.is_action_just_pressed("ui_back"):
		_on_back_pressed()

func _on_volume_changed(val: float):
	game_settings.volume = val

func _on_resolution_selected(index: int):
	game_settings.resolution_index = index

func _on_fullscreen_toggled(pressed: bool):
	game_settings.fullscreen = pressed

func _on_back_pressed():
	# Hide ourselves and show MainMenu
	visible = false
	var main_menu = get_parent().get_node_or_null("MainMenu")
	if main_menu:
		main_menu.visible = true
		var settings_btn = main_menu.get_node_or_null("VBoxContainer/Settings")
		if settings_btn:
			settings_btn.grab_focus()
	back_pressed.emit()
