extends Node

signal settings_changed

var volume: float = 1.0
var resolution_index: int = 0
var fullscreen: bool = false

func set_volume(value: float) -> void:
	volume = value
	emit_signal("settings_changed")

func set_resolution_index(value: int) -> void:
	resolution_index = value
	emit_signal("settings_changed")

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	emit_signal("settings_changed")
