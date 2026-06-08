extends Node


const SHADER_PATH := "res://shaders/water_distortion.gdshader"
const SCENE_PATH := "res://scenes/Water.tscn"
const EPS := 0.0001


func _fail(code: int, msg: String) -> void:
	printerr("FAIL: ", msg)
	get_tree().quit(code)


func _approx_eq(a: float, b: float) -> bool:
	return absf(a - b) <= EPS


func _ready() -> void:
	# 1. Load the shader resource.
	var shader: Shader = load(SHADER_PATH)
	if shader == null:
		_fail(2, "Could not load shader at %s" % SHADER_PATH)
		return
	if not (shader is Shader):
		_fail(3, "Resource at %s is not a Shader (got %s)" % [SHADER_PATH, str(shader)])
		return

	# 2. Assign the shader to a ShaderMaterial; this triggers compilation.
	var mat := ShaderMaterial.new()
	mat.shader = shader
	await get_tree().process_frame

	# 3. Instantiate scenes/Water.tscn and inspect its root.
	var packed: PackedScene = load(SCENE_PATH)
	if packed == null:
		_fail(4, "Could not load scene %s" % SCENE_PATH)
		return

	var root: Node = packed.instantiate()
	if root == null:
		_fail(5, "Failed to instantiate %s" % SCENE_PATH)
		return

	get_tree().root.add_child(root)
	await get_tree().process_frame

	if not (root is ColorRect):
		_fail(6, "Root of Water.tscn must be ColorRect, got %s" % root.get_class())
		return

	var scene_mat: Material = (root as ColorRect).material
	if scene_mat == null or not (scene_mat is ShaderMaterial):
		_fail(7, "Water.tscn root must have a ShaderMaterial assigned (got %s)" % str(scene_mat))
		return

	var scene_shader_mat: ShaderMaterial = scene_mat as ShaderMaterial
	if scene_shader_mat.shader == null:
		_fail(8, "ShaderMaterial in Water.tscn is missing its shader resource")
		return

	var sh_path := scene_shader_mat.shader.resource_path
	if sh_path != SHADER_PATH:
		_fail(9, "Expected ShaderMaterial.shader to point at %s, got %s" % [SHADER_PATH, sh_path])
		return

	# 4. Verify the controller propagates exported uniforms to the material.
	# wave_amplitude
	root.set("wave_amplitude", 0.075)
	await get_tree().process_frame
	await get_tree().process_frame
	var amp = scene_shader_mat.get_shader_parameter("wave_amplitude")
	if amp == null or not _approx_eq(float(amp), 0.075):
		_fail(10, "Expected material.wave_amplitude=0.075 after exporting; got %s" % str(amp))
		return

	# time_scale
	root.set("time_scale", 2.5)
	await get_tree().process_frame
	await get_tree().process_frame
	var ts = scene_shader_mat.get_shader_parameter("time_scale")
	if ts == null or not _approx_eq(float(ts), 2.5):
		_fail(11, "Expected material.time_scale=2.5 after exporting; got %s" % str(ts))
		return

	# wave_frequency
	root.set("wave_frequency", 25.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var freq = scene_shader_mat.get_shader_parameter("wave_frequency")
	if freq == null or not _approx_eq(float(freq), 25.0):
		_fail(12, "Expected material.wave_frequency=25.0 after exporting; got %s" % str(freq))
		return

	# tint_color
	root.set("tint_color", Color(0.1, 0.2, 0.3, 0.8))
	await get_tree().process_frame
	await get_tree().process_frame
	var tc = scene_shader_mat.get_shader_parameter("tint_color")
	if tc == null:
		_fail(13, "Expected material.tint_color to be set; got null")
		return
	var got_color: Color
	if tc is Color:
		got_color = tc
	elif tc is Vector4:
		got_color = Color(tc.x, tc.y, tc.z, tc.w)
	else:
		_fail(14, "Expected material.tint_color to be Color or Vector4; got %s" % str(tc))
		return
	if not (
		_approx_eq(got_color.r, 0.1)
		and _approx_eq(got_color.g, 0.2)
		and _approx_eq(got_color.b, 0.3)
		and _approx_eq(got_color.a, 0.8)
	):
		_fail(15, "Expected tint_color=(0.1,0.2,0.3,0.8), got %s" % str(got_color))
		return

	print("HARNESS_OK")
	get_tree().quit(0)
