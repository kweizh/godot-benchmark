extends Control

signal play_pressed
signal settings_pressed
signal quit_pressed

func _ready() -> void:
	$VBoxContainer/PlayButton.grab_focus()

func _on_play_pressed() -> void:
	emit_signal("play_pressed")

func _on_settings_pressed() -> void:
	emit_signal("settings_pressed")

func _on_quit_pressed() -> void:
	emit_signal("quit_pressed")
