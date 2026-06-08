shader_type canvas_item;

uniform float time_scale : hint_range(0.0, 4.0) = 1.0;
uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.02;
uniform float wave_frequency : hint_range(0.1, 50.0) = 10.0;
uniform vec4 tint_color : source_color = vec4(0.4, 0.7, 1.0, 0.5);
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

void fragment() {
    vec2 wave_uv_offset;
    wave_uv_offset.x = sin(TIME * time_scale + UV.y * wave_frequency);
    wave_uv_offset.y = cos(TIME * time_scale + UV.x * wave_frequency);
    vec2 distorted_uv = SCREEN_UV + wave_uv_offset * wave_amplitude;
    vec4 sampled_color = texture(screen_texture, distorted_uv);
    COLOR = mix(sampled_color, tint_color, tint_color.a);
}
