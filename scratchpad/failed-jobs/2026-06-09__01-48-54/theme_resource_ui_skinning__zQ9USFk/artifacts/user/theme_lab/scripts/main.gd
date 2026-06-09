extends Control

var _current_mode: String = "light"

func _ready() -> void:
	apply_theme("light")

func get_current_mode() -> String:
	return _current_mode

func apply_theme(mode: String) -> void:
	_current_mode = mode
	var t := Theme.new()
	
	t.set_type_variation("PrimaryButton", "Button")
	t.set_type_variation("DangerButton", "Button")
	
	if mode == "light":
		# Button
		t.set_color("font_color", "Button", Color("#222222"))
		t.set_stylebox("normal", "Button", _create_stylebox("#DDDDDD", 4))
		t.set_stylebox("hover", "Button", _create_stylebox("#CCCCCC", 4))
		t.set_stylebox("pressed", "Button", _create_stylebox("#AAAAAA", 4))
		
		# Label
		t.set_color("font_color", "Label", Color("#222222"))
		
		# Panel
		t.set_stylebox("panel", "Panel", _create_stylebox("#FFFFFF", 0))
		
		# PrimaryButton
		t.set_stylebox("normal", "PrimaryButton", _create_stylebox("#3366FF", 8))
		t.set_stylebox("hover", "PrimaryButton", _create_stylebox("#2255EE", 8))
		t.set_stylebox("pressed", "PrimaryButton", _create_stylebox("#1144CC", 8))
		
		# DangerButton
		t.set_stylebox("normal", "DangerButton", _create_stylebox("#FF3333", 12))
		t.set_stylebox("hover", "DangerButton", _create_stylebox("#EE2222", 12))
		t.set_stylebox("pressed", "DangerButton", _create_stylebox("#CC1111", 12))
		
	elif mode == "dark":
		# Button
		t.set_color("font_color", "Button", Color("#EEEEEE"))
		t.set_stylebox("normal", "Button", _create_stylebox("#333333", 4))
		t.set_stylebox("hover", "Button", _create_stylebox("#444444", 4))
		t.set_stylebox("pressed", "Button", _create_stylebox("#222222", 4))
		
		# Label
		t.set_color("font_color", "Label", Color("#EEEEEE"))
		
		# Panel
		t.set_stylebox("panel", "Panel", _create_stylebox("#111111", 0))
		
		# PrimaryButton
		t.set_stylebox("normal", "PrimaryButton", _create_stylebox("#6699FF", 8))
		t.set_stylebox("hover", "PrimaryButton", _create_stylebox("#88AAFF", 8))
		t.set_stylebox("pressed", "PrimaryButton", _create_stylebox("#5588EE", 8))
		
		# DangerButton
		t.set_stylebox("normal", "DangerButton", _create_stylebox("#FF6666", 12))
		t.set_stylebox("hover", "DangerButton", _create_stylebox("#FF8888", 12))
		t.set_stylebox("pressed", "DangerButton", _create_stylebox("#EE5555", 12))

	self.theme = t

func _create_stylebox(hex: String, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(hex)
	if radius > 0:
		sb.set_corner_radius_all(radius)
	return sb
