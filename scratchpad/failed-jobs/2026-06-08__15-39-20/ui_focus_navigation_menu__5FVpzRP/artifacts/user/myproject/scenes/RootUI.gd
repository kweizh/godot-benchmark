extends Control

func _ready():
	$MainMenu.visible = true
	$SettingsMenu.visible = false
	
	$MainMenu.settings_pressed.connect(_on_settings_pressed)
	$SettingsMenu.back_pressed.connect(_on_back_pressed)

func _on_settings_pressed():
	$MainMenu.visible = false
	$SettingsMenu.visible = true

func _on_back_pressed():
	$SettingsMenu.visible = false
	$MainMenu.visible = true
