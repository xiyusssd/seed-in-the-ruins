shader_type spatial;
// Reuse the original CC0 rock scan and mud maps in world metres.
uniform sampler2D rock_surface : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_arm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_surface : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
vec3 rock_sample(vec3 p, vec3 w) {
 return texture(rock_surface,p.yz*.18).rgb*w.x+texture(rock_surface,p.xz*.18).rgb*w.y+texture(rock_surface,p.xy*.18).rgb*w.z;
}
void fragment() {
 vec3 n=normalize(world_normal);
 vec3 weights=pow(abs(n),vec3(4.0));weights/=max(dot(weights,vec3(1)),.001);
 vec3 stone=rock_sample(world_position,weights)*vec3(.66,.74,.72);
 vec3 soil=texture(soil_surface,world_position.xz*.15).rgb*vec3(.47,.62,.44);
 float shelf=smoothstep(.56,.88,n.y);
 float stratum=.93+.07*sin(world_position.y*1.8+world_position.x*.13+world_position.z*.06);
 float wet=1.0-smoothstep(-1.1,2.6,world_position.y);
 ALBEDO=mix(stone,soil,shelf*.62)*stratum*mix(1.0,.68,wet);
 float rough=texture(rock_arm,world_position.xz*.18).g;
 ROUGHNESS=clamp(rough*.65+.25-wet*.12,.48,.96);
 METALLIC=0.0;SPECULAR=.3;
}
