extends Control

signal play_pressed
signal settings_pressed
signal quit_pressed

@onready var play_button: Button = $CenterContainer/Panel/VBoxContainer/Play
@onready var settings_button: Button = $CenterContainer/Panel/VBoxContainer/Settings
@onready var quit_button: Button = $CenterContainer/Panel/VBoxContainer/Quit


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _on_play_pressed() -> void:
	play_pressed.emit()


func _on_settings_pressed() -> void:
	settings_pressed.emit()


func _on_quit_pressed() -> void:
	quit_pressed.emit()
