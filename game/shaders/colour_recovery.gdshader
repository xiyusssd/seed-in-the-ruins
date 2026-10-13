shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float recovery : hint_range(0.0, 1.0) = 0.0;
void fragment() {
    vec4 scene = texture(screen_texture, SCREEN_UV);
    float grey = dot(scene.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 monochrome = vec3(clamp((grey - 0.5) * 1.08 + 0.5, 0.0, 1.0));
    // Gentle warm highlights and cool shade; saturation still follows the exact clue total.
    float lightness = smoothstep(0.15,0.8,grey);
    vec3 grade = mix(vec3(0.96,0.99,1.025),vec3(1.025,1.008,0.97),lightness);
    vec3 painted = clamp(scene.rgb * grade,vec3(0.0),vec3(1.0));
    vec3 restored = mix(monochrome, painted, recovery);
    // A restrained edge falloff gives the first-person frame depth without flashing.
    vec2 centered = SCREEN_UV * 2.0 - 1.0;
    float vignette = 1.0 - dot(centered, centered) * 0.035 * (1.0 - recovery * 0.5);
    COLOR = vec4(restored * vignette, scene.a);
}
