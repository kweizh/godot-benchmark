extends Control

func _ready() -> void:
	$MainMenu.visible = true
	$SettingsMenu.visible = false

func _on_main_menu_settings_pressed() -> void:
	$MainMenu.visible = false
	$SettingsMenu.visible = true

func _on_settings_menu_back_pressed() -> void:
	$SettingsMenu.visible = false
	$MainMenu.visible = true

func _on_main_menu_quit_pressed() -> void:
	get_tree().quit()
