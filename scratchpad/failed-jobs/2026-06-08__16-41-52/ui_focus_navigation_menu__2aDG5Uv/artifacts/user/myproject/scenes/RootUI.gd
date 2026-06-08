extends Control

@onready var main_menu: Control = $MainMenu
@onready var settings_menu: Control = $SettingsMenu


func _ready() -> void:
	main_menu.visible = true
	settings_menu.visible = false

	main_menu.settings_pressed.connect(_on_main_menu_settings_pressed)
	settings_menu.back_pressed.connect(_on_settings_menu_back_pressed)


func _on_main_menu_settings_pressed() -> void:
	main_menu.visible = false
	settings_menu.visible = true


func _on_settings_menu_back_pressed() -> void:
	settings_menu.visible = false
	main_menu.visible = true
