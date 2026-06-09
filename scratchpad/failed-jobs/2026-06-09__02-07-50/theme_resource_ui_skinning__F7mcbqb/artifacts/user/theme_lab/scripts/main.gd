extends Control

var _current_mode: String = "light"


func _ready() -> void:
	apply_theme("light")


func apply_theme(mode: String) -> void:
	var theme := Theme.new()

	if mode == "light":
		_build_light_theme(theme)
	else:
		_build_dark_theme(theme)

	# Register type variations
	theme.set_type_variation("PrimaryButton", "Button")
	theme.set_type_variation("DangerButton", "Button")

	self.theme = theme
	_current_mode = mode


func get_current_mode() -> String:
	return _current_mode


func _build_light_theme(theme: Theme) -> void:
	# Button font_color
	theme.set_color("font_color", "Button", Color("#222222"))

	# Button styleboxes
	theme.set_stylebox("normal", "Button", _make_stylebox("#DDDDDD", 4))
	theme.set_stylebox("hover", "Button", _make_stylebox("#CCCCCC", 4))
	theme.set_stylebox("pressed", "Button", _make_stylebox("#AAAAAA", 4))

	# Label font_color
	theme.set_color("font_color", "Label", Color("#222222"))

	# Panel stylebox
	theme.set_stylebox("panel", "Panel", _make_stylebox("#FFFFFF", 0))

	# PrimaryButton styleboxes
	theme.set_stylebox("normal", "PrimaryButton", _make_stylebox("#3366FF", 8))
	theme.set_stylebox("hover", "PrimaryButton", _make_stylebox("#2255EE", 8))
	theme.set_stylebox("pressed", "PrimaryButton", _make_stylebox("#1144CC", 8))

	# DangerButton styleboxes
	theme.set_stylebox("normal", "DangerButton", _make_stylebox("#FF3333", 12))
	theme.set_stylebox("hover", "DangerButton", _make_stylebox("#EE2222", 12))
	theme.set_stylebox("pressed", "DangerButton", _make_stylebox("#CC1111", 12))


func _build_dark_theme(theme: Theme) -> void:
	# Button font_color
	theme.set_color("font_color", "Button", Color("#EEEEEE"))

	# Button styleboxes
	theme.set_stylebox("normal", "Button", _make_stylebox("#333333", 4))
	theme.set_stylebox("hover", "Button", _make_stylebox("#444444", 4))
	theme.set_stylebox("pressed", "Button", _make_stylebox("#222222", 4))

	# Label font_color
	theme.set_color("font_color", "Label", Color("#EEEEEE"))

	# Panel stylebox
	theme.set_stylebox("panel", "Panel", _make_stylebox("#111111", 0))

	# PrimaryButton styleboxes
	theme.set_stylebox("normal", "PrimaryButton", _make_stylebox("#6699FF", 8))
	theme.set_stylebox("hover", "PrimaryButton", _make_stylebox("#88AAFF", 8))
	theme.set_stylebox("pressed", "PrimaryButton", _make_stylebox("#5588EE", 8))

	# DangerButton styleboxes
	theme.set_stylebox("normal", "DangerButton", _make_stylebox("#FF6666", 12))
	theme.set_stylebox("hover", "DangerButton", _make_stylebox("#FF8888", 12))
	theme.set_stylebox("pressed", "DangerButton", _make_stylebox("#EE5555", 12))


func _make_stylebox(bg_color: String, corner_radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(bg_color)
	sb.set_corner_radius_all(corner_radius)
	return sb
