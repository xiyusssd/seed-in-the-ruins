shader_type spatial;
uniform vec4 paint_color : source_color = vec4(0.31,0.43,0.41,1.0);
uniform vec4 rust_color : source_color = vec4(0.32,0.23,0.15,1.0);
uniform float wear = 0.30;
varying vec3 world_position;
float hash3(vec3 p){return fract(sin(dot(p,vec3(17.17,91.71,31.29)))*43758.5453);}
float grain(vec3 p){
 vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec3 p=world_position;
 float patches=grain(p*28.0)*.72+grain(p*7.0)*.28;
 float chip=smoothstep(.72-wear*.35,.87-wear*.18,patches);
 float pore=grain(p*130.0);
 float micro_fade=1.0-smoothstep(.004,.025,length(fwidth(p)));
 ALBEDO=mix(paint_color.rgb,rust_color.rgb,chip*.65)*(0.97+pore*.025*micro_fade);
 METALLIC=mix(0.38,0.08,chip);
 ROUGHNESS=0.56+chip*0.28;
 SPECULAR=0.45;
}
