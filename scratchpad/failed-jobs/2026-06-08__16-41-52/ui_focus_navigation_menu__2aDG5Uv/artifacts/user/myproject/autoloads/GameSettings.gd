extends Node

## Autoload that stores game settings and signals changes.

signal settings_changed

var volume: float = 1.0
var resolution_index: int = 0
var fullscreen: bool = false


func set_volume(value: float) -> void:
	volume = value
	settings_changed.emit()


func set_resolution_index(value: int) -> void:
	resolution_index = value
	settings_changed.emit()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	settings_changed.emit()
