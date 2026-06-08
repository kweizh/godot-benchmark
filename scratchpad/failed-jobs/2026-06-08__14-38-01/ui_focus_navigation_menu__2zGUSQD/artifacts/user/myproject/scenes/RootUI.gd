extends Control

@onready var main_menu = $MainMenu
@onready var settings_menu = $SettingsMenu

func _ready():
	main_menu.visible = true
	settings_menu.visible = false
	
	# Connect signals
	main_menu.settings_pressed.connect(_on_settings_pressed)
	settings_menu.back_pressed.connect(_on_back_pressed)

func _on_settings_pressed():
	main_menu.visible = false
	settings_menu.visible = true
	# Grab focus on the first control of settings menu (volume slider)
	var volume_slider = settings_menu.get_node_or_null("VBoxContainer/VolumeSlider")
	if volume_slider:
		volume_slider.grab_focus()

func _on_back_pressed():
	settings_menu.visible = false
	main_menu.visible = true
	# Grab focus back on Settings button
	var settings_btn = main_menu.get_node_or_null("VBoxContainer/Settings")
	if settings_btn:
		settings_btn.grab_focus()
