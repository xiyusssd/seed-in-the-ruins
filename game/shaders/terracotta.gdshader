shader_type spatial;
float hash2(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise2(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash2(i),hash2(i+vec2(1,0)),f.x),mix(hash2(i+vec2(0,1)),hash2(i+vec2(1)),f.x),f.y);}
void fragment(){
 float grain=noise2(UV*vec2(45,65));float stains=noise2(UV*vec2(3,9));
 vec3 clay=mix(vec3(.26,.13,.085),vec3(.48,.27,.17),grain*.5+.4);
 float dust=smoothstep(.6,.9,UV.y)*(1.-stains*.4);
 ALBEDO=mix(clay,vec3(.49,.43,.32),dust*.4)*COLOR.rgb;
 ROUGHNESS=.86;SPECULAR=.24;
}
