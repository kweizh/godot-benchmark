extends ColorRect

@export var time_scale: float = 1.0
@export var wave_amplitude: float = 0.02
@export var wave_frequency: float = 10.0
@export var tint_color: Color = Color(0.4, 0.7, 1.0, 0.5)

func _process(_delta: float) -> void:
	material.set_shader_parameter("time_scale", time_scale)
	material.set_shader_parameter("wave_amplitude", wave_amplitude)
	material.set_shader_parameter("wave_frequency", wave_frequency)
	material.set_shader_parameter("tint_color", tint_color)
