extends Control

var _current_mode: String = "light"


func _ready() -> void:
	apply_theme("light")


func get_current_mode() -> String:
	return _current_mode


func apply_theme(mode: String) -> void:
	_current_mode = mode
	var t := Theme.new()

	if mode == "dark":
		_build_dark_theme(t)
	else:
		_build_light_theme(t)

	self.theme = t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_flat(color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	return sb


func _build_light_theme(t: Theme) -> void:
	# Register type variations so PrimaryButton and DangerButton inherit Button
	t.set_type_variation("PrimaryButton", "Button")
	t.set_type_variation("DangerButton", "Button")

	# Button
	t.set_color("font_color", "Button", Color("#222222"))
	t.set_stylebox("normal",  "Button", _make_flat(Color("#DDDDDD"), 4))
	t.set_stylebox("hover",   "Button", _make_flat(Color("#CCCCCC"), 4))
	t.set_stylebox("pressed", "Button", _make_flat(Color("#AAAAAA"), 4))

	# Label
	t.set_color("font_color", "Label", Color("#222222"))

	# Panel
	t.set_stylebox("panel", "Panel", _make_flat(Color("#FFFFFF"), 0))

	# PrimaryButton
	t.set_stylebox("normal",  "PrimaryButton", _make_flat(Color("#3366FF"), 8))
	t.set_stylebox("hover",   "PrimaryButton", _make_flat(Color("#2255EE"), 8))
	t.set_stylebox("pressed", "PrimaryButton", _make_flat(Color("#1144CC"), 8))

	# DangerButton
	t.set_stylebox("normal",  "DangerButton", _make_flat(Color("#FF3333"), 12))
	t.set_stylebox("hover",   "DangerButton", _make_flat(Color("#EE2222"), 12))
	t.set_stylebox("pressed", "DangerButton", _make_flat(Color("#CC1111"), 12))


func _build_dark_theme(t: Theme) -> void:
	# Register type variations so PrimaryButton and DangerButton inherit Button
	t.set_type_variation("PrimaryButton", "Button")
	t.set_type_variation("DangerButton", "Button")

	# Button
	t.set_color("font_color", "Button", Color("#EEEEEE"))
	t.set_stylebox("normal",  "Button", _make_flat(Color("#333333"), 4))
	t.set_stylebox("hover",   "Button", _make_flat(Color("#444444"), 4))
	t.set_stylebox("pressed", "Button", _make_flat(Color("#222222"), 4))

	# Label
	t.set_color("font_color", "Label", Color("#EEEEEE"))

	# Panel
	t.set_stylebox("panel", "Panel", _make_flat(Color("#111111"), 0))

	# PrimaryButton
	t.set_stylebox("normal",  "PrimaryButton", _make_flat(Color("#6699FF"), 8))
	t.set_stylebox("hover",   "PrimaryButton", _make_flat(Color("#88AAFF"), 8))
	t.set_stylebox("pressed", "PrimaryButton", _make_flat(Color("#5588EE"), 8))

	# DangerButton
	t.set_stylebox("normal",  "DangerButton", _make_flat(Color("#FF6666"), 12))
	t.set_stylebox("hover",   "DangerButton", _make_flat(Color("#FF8888"), 12))
	t.set_stylebox("pressed", "DangerButton", _make_flat(Color("#EE5555"), 12))
