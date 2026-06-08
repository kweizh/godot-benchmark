extends Control

signal play_pressed
signal settings_pressed
signal quit_pressed

@onready var play_button: Button = $VBoxContainer/Play
@onready var settings_button: Button = $VBoxContainer/Settings
@onready var quit_button: Button = $VBoxContainer/Quit

func _ready():
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	# Grab focus initially
	play_button.grab_focus()

func _on_play_pressed():
	play_pressed.emit()

func _on_settings_pressed():
	settings_pressed.emit()

func _on_quit_pressed():
	quit_pressed.emit()
	get_tree().quit()
