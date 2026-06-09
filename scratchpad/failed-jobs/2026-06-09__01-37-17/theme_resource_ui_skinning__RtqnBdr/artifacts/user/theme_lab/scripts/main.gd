extends Control

var _current_mode: String = "light"

func _ready() -> void:
	apply_theme("light")

func apply_theme(mode: String) -> void:
	_current_mode = mode
	var new_theme = Theme.new()
	
	# Register type variations
	new_theme.set_type_variation("PrimaryButton", "Button")
	new_theme.set_type_variation("DangerButton", "Button")
	
	if mode == "light":
		# Button
		new_theme.set_color("font_color", "Button", Color("#222222"))
		new_theme.set_stylebox("normal", "Button", _create_stylebox(Color("#DDDDDD"), 4))
		new_theme.set_stylebox("hover", "Button", _create_stylebox(Color("#CCCCCC"), 4))
		new_theme.set_stylebox("pressed", "Button", _create_stylebox(Color("#AAAAAA"), 4))
		
		# Label
		new_theme.set_color("font_color", "Label", Color("#222222"))
		
		# Panel
		new_theme.set_stylebox("panel", "Panel", _create_stylebox(Color("#FFFFFF"), 0))
		
		# PrimaryButton
		new_theme.set_stylebox("normal", "PrimaryButton", _create_stylebox(Color("#3366FF"), 8))
		new_theme.set_stylebox("hover", "PrimaryButton", _create_stylebox(Color("#2255EE"), 8))
		new_theme.set_stylebox("pressed", "PrimaryButton", _create_stylebox(Color("#1144CC"), 8))
		
		# DangerButton
		new_theme.set_stylebox("normal", "DangerButton", _create_stylebox(Color("#FF3333"), 12))
		new_theme.set_stylebox("hover", "DangerButton", _create_stylebox(Color("#EE2222"), 12))
		new_theme.set_stylebox("pressed", "DangerButton", _create_stylebox(Color("#CC1111"), 12))
		
	elif mode == "dark":
		# Button
		new_theme.set_color("font_color", "Button", Color("#EEEEEE"))
		new_theme.set_stylebox("normal", "Button", _create_stylebox(Color("#333333"), 4))
		new_theme.set_stylebox("hover", "Button", _create_stylebox(Color("#444444"), 4))
		new_theme.set_stylebox("pressed", "Button", _create_stylebox(Color("#222222"), 4))
		
		# Label
		new_theme.set_color("font_color", "Label", Color("#EEEEEE"))
		
		# Panel
		new_theme.set_stylebox("panel", "Panel", _create_stylebox(Color("#111111"), 0))
		
		# PrimaryButton
		new_theme.set_stylebox("normal", "PrimaryButton", _create_stylebox(Color("#6699FF"), 8))
		new_theme.set_stylebox("hover", "PrimaryButton", _create_stylebox(Color("#88AAFF"), 8))
		new_theme.set_stylebox("pressed", "PrimaryButton", _create_stylebox(Color("#5588EE"), 8))
		
		# DangerButton
		new_theme.set_stylebox("normal", "DangerButton", _create_stylebox(Color("#FF6666"), 12))
		new_theme.set_stylebox("hover", "DangerButton", _create_stylebox(Color("#FF8888"), 12))
		new_theme.set_stylebox("pressed", "DangerButton", _create_stylebox(Color("#EE5555"), 12))

	self.theme = new_theme

func get_current_mode() -> String:
	return _current_mode

func _create_stylebox(bg: Color, radius: int) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_right = radius
	sb.corner_radius_bottom_left = radius
	return sb
