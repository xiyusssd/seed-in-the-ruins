shader_type sky;
// Grade the original HDR panorama in linear light. Both background and the
// irradiance cubemap see the same overcast coastal morning, without a flat fill.
uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_enable;
uniform float energy = .43;
uniform float recovery = 1.0;
void sky() {
 vec3 source = textureLod(panorama, SKY_COORDS, 0.0).rgb;
 float luminance = dot(source, vec3(.2126, .7152, .0722));
 vec3 clouds = mix(vec3(luminance), source, .26 + .08 * recovery);
 clouds *= vec3(.93, .98, 1.04);
 COLOR = clouds * energy;
}
