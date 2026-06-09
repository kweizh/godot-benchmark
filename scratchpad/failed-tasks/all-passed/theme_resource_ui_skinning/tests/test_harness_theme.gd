extends Node

# Harness that loads the user's main scene, exercises apply_theme() across
# "light" and "dark" modes, and verifies every required theme item via the
# Control.get_theme_color / Control.get_theme_stylebox APIs.

const TOL := 1.5 / 255.0  # Allow ~1/255 per-channel rounding error.


func _ready() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		printerr("FAIL: could not load res://scenes/main.tscn")
		get_tree().quit(2)
		return

	var instance: Node = packed.instantiate()
	get_tree().root.add_child.call_deferred(instance)

	# Allow _ready to run on the instanced scene.
	await get_tree().process_frame
	await get_tree().process_frame

	# Locate required nodes.
	var root_node: Node = _find_node_by_name(instance, "Root")
	if root_node == null:
		printerr("FAIL: could not find node named 'Root' under the main scene")
		get_tree().quit(3)
		return

	if not (root_node is Control):
		printerr("FAIL: 'Root' must be a Control, got %s" % root_node.get_class())
		get_tree().quit(3)
		return

	var main_panel: Node = root_node.get_node_or_null("MainPanel")
	if main_panel == null or not (main_panel is Panel):
		printerr("FAIL: 'Root/MainPanel' missing or not a Panel")
		get_tree().quit(3)
		return

	var title_label: Node = main_panel.get_node_or_null("TitleLabel")
	if title_label == null or not (title_label is Label):
		printerr("FAIL: 'Root/MainPanel/TitleLabel' missing or not a Label")
		get_tree().quit(3)
		return

	var default_btn: Node = main_panel.get_node_or_null("DefaultButton")
	if default_btn == null or not (default_btn is Button):
		printerr("FAIL: 'Root/MainPanel/DefaultButton' missing or not a Button")
		get_tree().quit(3)
		return

	var primary_btn: Node = main_panel.get_node_or_null("PrimaryButton")
	if primary_btn == null or not (primary_btn is Button):
		printerr("FAIL: 'Root/MainPanel/PrimaryButton' missing or not a Button")
		get_tree().quit(3)
		return

	var danger_btn: Node = main_panel.get_node_or_null("DangerButton")
	if danger_btn == null or not (danger_btn is Button):
		printerr("FAIL: 'Root/MainPanel/DangerButton' missing or not a Button")
		get_tree().quit(3)
		return

	# Public API checks.
	if not root_node.has_method("apply_theme"):
		printerr("FAIL: Root must define method apply_theme(mode: String)")
		get_tree().quit(4)
		return
	if not root_node.has_method("get_current_mode"):
		printerr("FAIL: Root must define method get_current_mode() -> String")
		get_tree().quit(4)
		return

	# Initial state from _ready must be "light".
	var initial_mode: String = String(root_node.call("get_current_mode"))
	if initial_mode != "light":
		printerr("FAIL: get_current_mode() must return 'light' before any explicit call, got '%s'" % initial_mode)
		get_tree().quit(5)
		return

	var theme_obj = (root_node as Control).theme
	if theme_obj == null:
		printerr("FAIL: Root.theme is null; apply_theme('light') must have been invoked from _ready")
		get_tree().quit(6)
		return
	if not (theme_obj is Theme):
		printerr("FAIL: Root.theme is not a Theme resource; got %s" % str(theme_obj))
		get_tree().quit(6)
		return

	# Variation registration.
	var pv_base: String = (theme_obj as Theme).get_type_variation_base("PrimaryButton")
	if pv_base != "Button":
		printerr("FAIL: PrimaryButton variation base must be 'Button', got '%s'" % pv_base)
		get_tree().quit(7)
		return
	var dv_base: String = (theme_obj as Theme).get_type_variation_base("DangerButton")
	if dv_base != "Button":
		printerr("FAIL: DangerButton variation base must be 'Button', got '%s'" % dv_base)
		get_tree().quit(7)
		return

	# Force theme_type_variation on the relevant buttons (the spec allows this
	# to be set in code rather than baked into the scene file).
	if (primary_btn as Control).theme_type_variation != "PrimaryButton":
		(primary_btn as Control).theme_type_variation = "PrimaryButton"
	if (danger_btn as Control).theme_type_variation != "DangerButton":
		(danger_btn as Control).theme_type_variation = "DangerButton"
	await get_tree().process_frame

	# ---------------------------------------------------------------------
	# Light mode verification
	# ---------------------------------------------------------------------
	var light_checks := _light_checks()
	if not _run_checks("light", root_node, main_panel, title_label, default_btn, primary_btn, danger_btn, light_checks):
		return

	# ---------------------------------------------------------------------
	# Switch to dark mode and re-verify.
	# ---------------------------------------------------------------------
	root_node.call("apply_theme", "dark")
	await get_tree().process_frame
	await get_tree().process_frame

	var dark_mode: String = String(root_node.call("get_current_mode"))
	if dark_mode != "dark":
		printerr("FAIL: get_current_mode() expected 'dark' after apply_theme('dark'), got '%s'" % dark_mode)
		get_tree().quit(8)
		return

	var dark_checks := _dark_checks()
	if not _run_checks("dark", root_node, main_panel, title_label, default_btn, primary_btn, danger_btn, dark_checks):
		return

	# ---------------------------------------------------------------------
	# Switch back to light to confirm repeatability.
	# ---------------------------------------------------------------------
	root_node.call("apply_theme", "light")
	await get_tree().process_frame
	await get_tree().process_frame

	var light_again: String = String(root_node.call("get_current_mode"))
	if light_again != "light":
		printerr("FAIL: get_current_mode() expected 'light' after re-applying light, got '%s'" % light_again)
		get_tree().quit(9)
		return

	var smoke := [
		{"node": default_btn, "kind": "stylebox", "name": "normal", "type": "Button", "color": Color("#DDDDDD"), "radius": 4},
		{"node": primary_btn, "kind": "stylebox", "name": "normal", "type": "PrimaryButton", "color": Color("#3366FF"), "radius": 8},
		{"node": danger_btn, "kind": "stylebox", "name": "normal", "type": "DangerButton", "color": Color("#FF3333"), "radius": 12},
	]
	for spec in smoke:
		if not _check_stylebox(spec["node"], spec["name"], spec["type"], spec["color"], spec["radius"], "light (after toggle)"):
			get_tree().quit(10)
			return

	print("HARNESS_OK")
	get_tree().quit(0)


func _run_checks(mode: String, root_node: Node, main_panel: Node, title_label: Node, default_btn: Node, primary_btn: Node, danger_btn: Node, checks: Array) -> bool:
	for c in checks:
		var target_name: String = c["target"]
		var target_node: Node = null
		match target_name:
			"DefaultButton":
				target_node = default_btn
			"PrimaryButton":
				target_node = primary_btn
			"DangerButton":
				target_node = danger_btn
			"TitleLabel":
				target_node = title_label
			"MainPanel":
				target_node = main_panel
			_:
				target_node = null
		if target_node == null:
			printerr("FAIL: unknown target '%s' in %s checks" % [target_name, mode])
			get_tree().quit(20)
			return false

		if c["kind"] == "color":
			if not _check_color(target_node, c["name"], c["type"], c["color"], mode):
				get_tree().quit(21)
				return false
		else:
			if not _check_stylebox(target_node, c["name"], c["type"], c["color"], c["radius"], mode):
				get_tree().quit(22)
				return false
	return true


func _check_color(node: Node, item_name: String, type_name: String, expected: Color, mode: String) -> bool:
	var got: Color = (node as Control).get_theme_color(item_name, type_name)
	if not _colors_close(got, expected):
		printerr("FAIL: [%s] %s.get_theme_color('%s','%s') = %s, expected %s" % [mode, node.name, item_name, type_name, str(got), str(expected)])
		return false
	return true


func _check_stylebox(node: Node, item_name: String, type_name: String, expected_color: Color, expected_radius: int, mode: String) -> bool:
	var sb: StyleBox = (node as Control).get_theme_stylebox(item_name, type_name)
	if sb == null:
		printerr("FAIL: [%s] %s.get_theme_stylebox('%s','%s') returned null" % [mode, node.name, item_name, type_name])
		return false
	if not (sb is StyleBoxFlat):
		printerr("FAIL: [%s] %s stylebox '%s' on type '%s' is not StyleBoxFlat (got %s)" % [mode, node.name, item_name, type_name, sb.get_class()])
		return false
	var flat: StyleBoxFlat = sb
	if not _colors_close(flat.bg_color, expected_color):
		printerr("FAIL: [%s] %s stylebox '%s' on type '%s' bg_color = %s, expected %s" % [mode, node.name, item_name, type_name, str(flat.bg_color), str(expected_color)])
		return false
	if expected_radius >= 0 and int(flat.corner_radius_top_left) != expected_radius:
		printerr("FAIL: [%s] %s stylebox '%s' on type '%s' corner_radius_top_left = %d, expected %d" % [mode, node.name, item_name, type_name, int(flat.corner_radius_top_left), expected_radius])
		return false
	return true


func _colors_close(a: Color, b: Color) -> bool:
	return abs(a.r - b.r) <= TOL and abs(a.g - b.g) <= TOL and abs(a.b - b.b) <= TOL


func _find_node_by_name(root: Node, target: String) -> Node:
	if root.name == target:
		return root
	for child in root.get_children():
		var r := _find_node_by_name(child, target)
		if r != null:
			return r
	return null


func _light_checks() -> Array:
	return [
		{"target": "DefaultButton", "kind": "color", "name": "font_color", "type": "Button", "color": Color("#222222")},
		{"target": "DefaultButton", "kind": "stylebox", "name": "normal", "type": "Button", "color": Color("#DDDDDD"), "radius": 4},
		{"target": "DefaultButton", "kind": "stylebox", "name": "hover", "type": "Button", "color": Color("#CCCCCC"), "radius": 4},
		{"target": "DefaultButton", "kind": "stylebox", "name": "pressed", "type": "Button", "color": Color("#AAAAAA"), "radius": 4},
		{"target": "TitleLabel", "kind": "color", "name": "font_color", "type": "Label", "color": Color("#222222")},
		{"target": "MainPanel", "kind": "stylebox", "name": "panel", "type": "Panel", "color": Color("#FFFFFF"), "radius": -1},
		{"target": "PrimaryButton", "kind": "stylebox", "name": "normal", "type": "PrimaryButton", "color": Color("#3366FF"), "radius": 8},
		{"target": "PrimaryButton", "kind": "stylebox", "name": "hover", "type": "PrimaryButton", "color": Color("#2255EE"), "radius": 8},
		{"target": "PrimaryButton", "kind": "stylebox", "name": "pressed", "type": "PrimaryButton", "color": Color("#1144CC"), "radius": 8},
		{"target": "DangerButton", "kind": "stylebox", "name": "normal", "type": "DangerButton", "color": Color("#FF3333"), "radius": 12},
		{"target": "DangerButton", "kind": "stylebox", "name": "hover", "type": "DangerButton", "color": Color("#EE2222"), "radius": 12},
		{"target": "DangerButton", "kind": "stylebox", "name": "pressed", "type": "DangerButton", "color": Color("#CC1111"), "radius": 12},
	]


func _dark_checks() -> Array:
	return [
		{"target": "DefaultButton", "kind": "color", "name": "font_color", "type": "Button", "color": Color("#EEEEEE")},
		{"target": "DefaultButton", "kind": "stylebox", "name": "normal", "type": "Button", "color": Color("#333333"), "radius": 4},
		{"target": "DefaultButton", "kind": "stylebox", "name": "hover", "type": "Button", "color": Color("#444444"), "radius": 4},
		{"target": "DefaultButton", "kind": "stylebox", "name": "pressed", "type": "Button", "color": Color("#222222"), "radius": 4},
		{"target": "TitleLabel", "kind": "color", "name": "font_color", "type": "Label", "color": Color("#EEEEEE")},
		{"target": "MainPanel", "kind": "stylebox", "name": "panel", "type": "Panel", "color": Color("#111111"), "radius": -1},
		{"target": "PrimaryButton", "kind": "stylebox", "name": "normal", "type": "PrimaryButton", "color": Color("#6699FF"), "radius": 8},
		{"target": "PrimaryButton", "kind": "stylebox", "name": "hover", "type": "PrimaryButton", "color": Color("#88AAFF"), "radius": 8},
		{"target": "PrimaryButton", "kind": "stylebox", "name": "pressed", "type": "PrimaryButton", "color": Color("#5588EE"), "radius": 8},
		{"target": "DangerButton", "kind": "stylebox", "name": "normal", "type": "DangerButton", "color": Color("#FF6666"), "radius": 12},
		{"target": "DangerButton", "kind": "stylebox", "name": "hover", "type": "DangerButton", "color": Color("#FF8888"), "radius": 12},
		{"target": "DangerButton", "kind": "stylebox", "name": "pressed", "type": "DangerButton", "color": Color("#EE5555"), "radius": 12},
	]
