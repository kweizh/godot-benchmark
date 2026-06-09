extends Control

var _current_mode: String = "light"


func _ready() -> void:
	apply_theme("light")


func get_current_mode() -> String:
	return _current_mode


func apply_theme(mode: String) -> void:
	_current_mode = mode
	var theme := Theme.new()

	# Register type variations
	theme.set_type_variation("PrimaryButton", "Button")
	theme.set_type_variation("DangerButton", "Button")

	# --- Colors ---
	var is_dark := mode == "dark"
	var button_font_color := Color("#EEEEEE") if is_dark else Color("#222222")
	var label_font_color := Color("#EEEEEE") if is_dark else Color("#222222")

	theme.set_color("font_color", "Button", button_font_color)
	theme.set_color("font_color", "Label", label_font_color)

	# --- Button styles ---
	if is_dark:
		theme.set_stylebox("normal", "Button", _make_stylebox("#333333", 4))
		theme.set_stylebox("hover", "Button", _make_stylebox("#444444", 4))
		theme.set_stylebox("pressed", "Button", _make_stylebox("#222222", 4))
	else:
		theme.set_stylebox("normal", "Button", _make_stylebox("#DDDDDD", 4))
		theme.set_stylebox("hover", "Button", _make_stylebox("#CCCCCC", 4))
		theme.set_stylebox("pressed", "Button", _make_stylebox("#AAAAAA", 4))

	# --- Panel style ---
	theme.set_stylebox("panel", "Panel", _make_stylebox("#111111" if is_dark else "#FFFFFF", 0))

	# --- PrimaryButton variation ---
	if is_dark:
		theme.set_stylebox("normal", "PrimaryButton", _make_stylebox("#6699FF", 8))
		theme.set_stylebox("hover", "PrimaryButton", _make_stylebox("#88AAFF", 8))
		theme.set_stylebox("pressed", "PrimaryButton", _make_stylebox("#5588EE", 8))
	else:
		theme.set_stylebox("normal", "PrimaryButton", _make_stylebox("#3366FF", 8))
		theme.set_stylebox("hover", "PrimaryButton", _make_stylebox("#2255EE", 8))
		theme.set_stylebox("pressed", "PrimaryButton", _make_stylebox("#1144CC", 8))

	# --- DangerButton variation ---
	if is_dark:
		theme.set_stylebox("normal", "DangerButton", _make_stylebox("#FF6666", 12))
		theme.set_stylebox("hover", "DangerButton", _make_stylebox("#FF8888", 12))
		theme.set_stylebox("pressed", "DangerButton", _make_stylebox("#EE5555", 12))
	else:
		theme.set_stylebox("normal", "DangerButton", _make_stylebox("#FF3333", 12))
		theme.set_stylebox("hover", "DangerButton", _make_stylebox("#EE2222", 12))
		theme.set_stylebox("pressed", "DangerButton", _make_stylebox("#CC1111", 12))

	self.theme = theme


static func _make_stylebox(bg_hex: String, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(bg_hex)
	sb.set_corner_radius_all(radius)
	return sb
