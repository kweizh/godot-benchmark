extends Control

signal play_pressed
signal settings_pressed
signal quit_pressed

func _ready():
	$VBoxContainer/Play.pressed.connect(func(): play_pressed.emit())
	$VBoxContainer/Settings.pressed.connect(func(): settings_pressed.emit())
	$VBoxContainer/Quit.pressed.connect(func(): quit_pressed.emit())
