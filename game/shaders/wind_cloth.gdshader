shader_type spatial;
render_mode cull_disabled;
uniform vec4 cloth_tint : source_color = vec4(.61,.48,.30,1.0);
uniform float wind_clock = 0.0;
uniform float gust = 0.5;
void vertex(){
 float free_edge=UV.y*UV.y;
 VERTEX.y+=free_edge*(sin(wind_clock*2.2+VERTEX.x*5.0)*.07+gust*.17);
 VERTEX.x+=free_edge*sin(wind_clock*1.6+UV.y*4.0)*gust*.035;
}
void fragment(){
 float edge=.85+.10*sin(UV.x*37.0)+.04*sin(UV.x*73.0);
 float weave=.95+.025*sin(UV.x*340.0)*sin(UV.y*410.0);
 ALBEDO=cloth_tint.rgb*weave*(.86+.13*UV.y);
 ROUGHNESS=1.0;
 ALPHA=1.0-smoothstep(edge-.015,edge+.015,UV.y);
}
