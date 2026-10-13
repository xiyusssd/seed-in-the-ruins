shader_type spatial;
render_mode cull_disabled;
uniform vec4 leaf_tint : source_color = vec4(.36,.46,.28,1.0);
uniform bool petal=false;
uniform sampler2D leaf_surface : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
void fragment(){
 float centre=1.0-smoothstep(.0,.055,abs(UV.x-.5));
 float ribs=pow(.5+.5*cos(UV.y*62.0+abs(UV.x-.5)*32.0),16.0);
 float edge=smoothstep(.32,.5,abs(UV.x-.5));
 float mottling=sin(UV.y*17.0+sin(UV.x*13.0))*sin(UV.x*23.0+UV.y*9.0);
 vec3 pigment=leaf_tint.rgb*(.86+.14*sin(UV.y*3.14159265)+mottling*.035);
 pigment=mix(pigment,leaf_tint.rgb*vec3(1.1,1.08,.88),centre*.26+ribs*(petal?.035:.065));
 float tissue=dot(texture(leaf_surface,vec2(UV.x,1.0-UV.y)).rgb,vec3(.2126,.7152,.0722));
 ALBEDO=pigment*(1.0-edge*.1)*(petal?1.0:mix(.76,1.3,clamp(tissue*2.0,0.0,1.0)));
 ROUGHNESS=petal?.8:.86;SPECULAR=.24;
 BACKLIGHT=leaf_tint.rgb*(petal?.12:.18);
}
