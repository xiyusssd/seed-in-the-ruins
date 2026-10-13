shader_type spatial;
uniform vec4 bark_tint : source_color = vec4(0.30,0.25,0.19,1.0);
varying vec3 bark_position;
void vertex(){bark_position=VERTEX;}
void fragment(){
 vec3 p=bark_position;
 float grooves=pow(.5+.5*sin(p.x*80.0+p.z*67.0+sin(p.y*4.0)*2.0),5.0);
 float grain=.5+.5*sin(p.y*41.0+sin(p.x*53.0+p.z*31.0)*3.0);
 ALBEDO=bark_tint.rgb*(.78+grain*.16-grooves*.22);
 ROUGHNESS=.97;SPECULAR=.22;
}
