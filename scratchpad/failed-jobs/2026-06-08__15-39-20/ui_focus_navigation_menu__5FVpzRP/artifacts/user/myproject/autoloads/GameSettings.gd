extends Node

signal settings_changed

var volume: float = 1.0:
	set(val):
		volume = val
		settings_changed.emit()

var resolution_index: int = 0:
	set(val):
		resolution_index = val
		settings_changed.emit()

var fullscreen: bool = false:
	set(val):
		fullscreen = val
		settings_changed.emit()
