shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float wind_clock=0.0;
uniform float gust=.5;
uniform float root_height=0.0;
void vertex(){
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float crown=smoothstep(root_height+1.0,root_height+3.0,p.y);
 VERTEX.x+=(sin(wind_clock*.8+p.z*.6)*.025+sin(wind_clock*2.1+p.x*2.0)*.008)*gust*crown;
}
void fragment(){
 ALBEDO=texture(albedo_texture,UV).rgb;
 NORMAL_MAP=texture(normal_texture,UV).rgb;
 NORMAL_MAP_DEPTH=.35;
 ROUGHNESS=.88;SPECULAR=.24;BACKLIGHT=ALBEDO*.22;
}
