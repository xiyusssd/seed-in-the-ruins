shader_type spatial;
render_mode cull_disabled;
uniform float wind_clock = 0.0;
uniform float gust = 0.5;
uniform vec4 leaf_tint : source_color = vec4(0.35,0.47,0.30,1.0);
uniform sampler2D leaf_surface : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
void vertex() {
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float phase=world.x*0.47+world.z*0.31;
 float tip=UV.y*UV.y;
 VERTEX.x+=sin(wind_clock*1.6+phase)*tip*(0.025+gust*0.035);
 VERTEX.y+=sin(wind_clock*2.1+phase*1.7)*tip*0.018;
}
void fragment() {
 float rib=1.0-smoothstep(0.015,0.06,abs(UV.x-0.5));
 float vein=pow(0.5+0.5*sin(UV.y*45.0+abs(UV.x-.5)*25.0),14.0);
 float tissue=dot(texture(leaf_surface,vec2(UV.x,1.0-UV.y)).rgb,vec3(.2126,.7152,.0722));
 ALBEDO=leaf_tint.rgb*COLOR.rgb*(0.88+UV.y*0.12+rib*0.09-vein*0.04)*mix(.76,1.3,clamp(tissue*2.0,0.0,1.0));
 // A damp waxy midrib catches the morning light; leaf edges remain matte.
 ROUGHNESS=mix(.82,.58,rib)*mix(.94,1.0,tissue);
 BACKLIGHT=ALBEDO*.32;
 SPECULAR=.34;
}
