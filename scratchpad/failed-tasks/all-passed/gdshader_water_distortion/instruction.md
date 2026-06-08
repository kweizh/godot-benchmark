# Animated Water Distortion GDShader (canvas_item)

Author a Godot 4 `canvas_item` GDShader that animates a water-like UV distortion of the screen behind it, plus a `ColorRect` scene and a GDScript controller that exposes the shader uniforms.

Godot 4 (>= 4.3) is available as the headless binary `godot`.

## Acceptance Criteria

- Project path: `/home/user/water_shader`
- File layout (relative to the project root):
  - `project.godot`
  - `shaders/water_distortion.gdshader`
  - `scenes/Water.tscn` (with an attached GDScript controller)
- `shaders/water_distortion.gdshader`:
  - First non-comment, non-blank line is `shader_type canvas_item;`.
  - Declares the following uniforms:
    - `uniform float time_scale : hint_range(0.0, 4.0) = 1.0;`
    - `uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.02;`
    - `uniform float wave_frequency : hint_range(0.1, 50.0) = 10.0;`
    - `uniform vec4 tint_color : source_color = vec4(0.4, 0.7, 1.0, 0.5);`
    - `uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;`
  - Defines a `void fragment()` function that:
    - Samples `screen_texture` at `SCREEN_UV` offset by a `sin`/`cos` wave derived from `TIME * time_scale` and `UV * wave_frequency`, scaled by `wave_amplitude`.
    - Mixes the sampled color with `tint_color` using `tint_color.a` as the mix factor via `mix(...)`.
  - Compiles without errors when assigned to a `ShaderMaterial`.
- `scenes/Water.tscn`:
  - Root node is a `ColorRect` named `Water`.
  - Has a `ShaderMaterial` whose `shader` references `res://shaders/water_distortion.gdshader`.
  - An attached GDScript exports four variables (`time_scale: float`, `wave_amplitude: float`, `wave_frequency: float`, `tint_color: Color`) and, in `_process(delta)`, propagates each value to the material via `set_shader_parameter`.
- Runtime:
  - `godot --headless --path /home/user/water_shader --quit` exits with code 0 and produces no `SCRIPT ERROR`, `Parse Error`, `Cannot compile`, or `Failed to load` messages.
  - Setting any of the four exported variables on the `Water` node updates the corresponding shader parameter on its `ShaderMaterial` within the next processed frame.
