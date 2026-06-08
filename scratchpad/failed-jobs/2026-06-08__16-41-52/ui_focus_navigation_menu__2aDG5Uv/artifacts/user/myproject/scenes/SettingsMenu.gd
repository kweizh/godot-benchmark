extends Control

signal back_pressed

@onready var volume_slider: HSlider = $CenterContainer/Panel/VBoxContainer/VolumeSlider
@onready var resolution_option: OptionButton = $CenterContainer/Panel/VBoxContainer/ResolutionOption
@onready var fullscreen_check: CheckBox = $CenterContainer/Panel/VBoxContainer/FullscreenCheck
@onready var back_button: Button = $CenterContainer/Panel/VBoxContainer/BackButton


func _ready() -> void:
	set_process_input(true)

	var gs: Node = get_node("/root/GameSettings")

	# Read existing settings from the autoload and apply to controls
	volume_slider.value = gs.volume
	resolution_option.selected = gs.resolution_index
	fullscreen_check.button_pressed = gs.fullscreen

	# Wire control changes -> GameSettings
	volume_slider.value_changed.connect(_on_volume_changed)
	resolution_option.item_selected.connect(_on_resolution_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	back_button.pressed.connect(_on_back_pressed)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_back"):
		_on_back_pressed()


func _on_volume_changed(value: float) -> void:
	var gs: Node = get_node("/root/GameSettings")
	gs.set_volume(value)


func _on_resolution_changed(index: int) -> void:
	var gs: Node = get_node("/root/GameSettings")
	gs.set_resolution_index(index)


func _on_fullscreen_toggled(button_pressed: bool) -> void:
	var gs: Node = get_node("/root/GameSettings")
	gs.set_fullscreen(button_pressed)


func _on_back_pressed() -> void:
	back_pressed.emit()
