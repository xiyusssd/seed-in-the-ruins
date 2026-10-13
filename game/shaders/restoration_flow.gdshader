shader_type spatial;
render_mode cull_disabled, shadows_disabled;
uniform vec4 water_tint : source_color = vec4(.48,.76,.73,.65);
void fragment(){
	float ribbons=.5+.5*sin(UV.x*46.0+sin(UV.y*19.0-TIME*5.0)*1.8);
	float ripple=.5+.5*sin(UV.y*64.0-TIME*12.0);
	ALBEDO=water_tint.rgb*(.78+.22*ribbons);
	ROUGHNESS=.16; SPECULAR=.65;
	ALPHA=water_tint.a*(.45+.3*ribbons+.25*ripple);
}
