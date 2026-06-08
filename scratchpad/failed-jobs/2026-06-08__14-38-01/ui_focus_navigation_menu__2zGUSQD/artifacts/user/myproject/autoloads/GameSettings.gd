extends Node

signal settings_changed

var volume: float = 1.0:
	set(value):
		volume = value
		settings_changed.emit()

var resolution_index: int = 0:
	set(value):
		resolution_index = value
		settings_changed.emit()

var fullscreen: bool = false:
	set(value):
		fullscreen = value
		settings_changed.emit()
