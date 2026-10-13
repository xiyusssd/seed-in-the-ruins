shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float strength = .08;
void fragment(){
	float edge=pow(max(0.0,1.0-abs(UV.x*2.0-1.0)),2.2);
	float end=smoothstep(0.0,.12,UV.y)*(1.0-smoothstep(.65,1.0,UV.y));
	float dust=.85+.15*sin(UV.y*33.0-TIME*.7+UV.x*7.0);
	ALBEDO=vec3(1.0,.85,.57);
	ALPHA=edge*end*dust*strength;
}
