shader_type spatial;
uniform float chapter = 0.0;
varying vec3 water_position;
varying float swell_height;
void vertex() {
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float a=dot(p.xz,vec2(.21,.085))+TIME*.46;
 float b=dot(p.xz,vec2(-.12,.29))-TIME*.37;
 float c=dot(p.xz,vec2(.49,.34))+TIME*.64;
 float d=dot(p.xz,vec2(-.68,.19))-TIME*.51;
 float wave=sin(a)*.065+sin(b)*.038+sin(c)*.014+sin(d)*.010;
 VERTEX.y+=wave;
 vec2 slope=cos(a)*vec2(.21,.085)*.065+cos(b)*vec2(-.12,.29)*.038+cos(c)*vec2(.49,.34)*.014+cos(d)*vec2(-.68,.19)*.010;
 NORMAL=normalize(vec3(-slope.x,1.0,-slope.y));
 water_position=p;swell_height=wave;
}
float hash2(vec2 p){
 vec3 q=fract(vec3(p.xyx)*.1031);
 q+=dot(q,q.yzx+33.33);
 return fract((q.x+q.y)*q.z);
}
float noise2(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash2(i),hash2(i+vec2(1,0)),f.x),mix(hash2(i+vec2(0,1)),hash2(i+vec2(1)),f.x),f.y);}
float bank_foam(vec2 p,vec2 center,float radius) {
 float distance_to_bank=length(p-center)-radius;
 float wash=sin(TIME*.57+atan(p.y-center.y,p.x-center.x)*3.0)*.15;
 return 1.0-smoothstep(.05,.48,abs(distance_to_bank+wash));
}
float coast_distance(vec2 p,vec2 center) {
 vec2 q=p-center;
 float angle=atan(-center.x,-center.y)+3.14159265;
 float c=cos(angle),s=sin(angle);
 vec2 local=vec2(c*q.x-s*q.y,s*q.x+c*q.y)/vec2(1.0,.72);
 float theta=atan(local.y,local.x);
 // Match the continuous soil shelf at its tidal ring, avoiding floating foam.
 float edge=8.3+.38*sin(theta*3.0+.3)+.27*sin(theta*7.0-1.2)+.16*sin(theta*11.0+.8);
 return length(local)-edge*.985;
}
void fragment() {
 vec2 p=water_position.xz;
 float distance_fade=1.0-smoothstep(30.0,110.0,length(VERTEX));
 // Wind advects two irregular ripple scales; derivatives fade subpixel detail.
 vec2 wind=vec2(.11,.035)*TIME;
 vec2 warp=vec2(noise2(p*.17+wind*.2),noise2(p*.19-wind*.15))*.7;
 float footprint=max(length(dFdx(p)),length(dFdy(p)));
 float micro_fade=1.-smoothstep(.10,.45,footprint);
 float h0=noise2((p+warp+wind)*1.6);
 float hx=noise2((p+warp+wind+vec2(.035,0))*1.6);
 float hz=noise2((p+warp+wind+vec2(0,.035))*1.6);
 vec2 ripple_position=p+warp*2.4;
 vec2 ripple_slope=cos(dot(ripple_position,vec2(3.1,1.8))+TIME*1.05)*vec2(.028,.016);
 ripple_slope+=cos(dot(ripple_position,vec2(-1.6,4.2))-TIME*.81)*vec2(-.015,.038);
 vec2 small_normal=(vec2(hx-h0,hz-h0)*.38+ripple_slope)*distance_fade*micro_fade;
 NORMAL_MAP=normalize(vec3(small_normal,1.0))*.5+.5;
 NORMAL_MAP_DEPTH=.32;
 float ripple=h0*2.-1.;
 float fresnel=pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),4.0);
 vec3 deep=vec3(.015,.040,.055);
 vec3 shallow=vec3(.044,.105,.091);
 float slow=.5+.5*sin(p.x*.11+p.y*.17+TIME*.09);
 vec3 water=mix(deep,shallow,slow*.46);
 water=mix(water,vec3(.13,.19,.23),fresnel*.20);
 vec2 center=chapter<.5?vec2(-3,-7):(chapter<1.5?vec2(6,0):vec2(0,-10));
 float foam=bank_foam(p,center,2.65);
 float shore=min(min(coast_distance(p,vec2(-25,-6)),coast_distance(p,vec2(26,-13))),min(coast_distance(p,vec2(-28,17)),coast_distance(p,vec2(17,29))));
 float shallows=1.0-smoothstep(.1,2.4,max(shore,0.0));
 water=mix(water,vec3(.05,.12,.10),shallows*.55);
 // Authored shore masks; these do not simulate physical water depth.
 float wash=.12+sin(TIME*.65+noise2(p*.18)*4.0)*.19;
 float tidal_foam=1.0-smoothstep(.035,.22,abs(shore-wash));
 foam=max(foam,tidal_foam);
 float broken=smoothstep(.25,.76,noise2(p*5.7+wind*1.4))*(.55+.45*noise2(p*38.0+wind*4.0));
 float crests=smoothstep(.18,.25,swell_height)*(.5+.5*ripple)*distance_fade;
 ALBEDO=mix(water,vec3(.66,.73,.65),foam*broken*.40+crests*.06);
 ROUGHNESS=mix(.10,.46,foam);METALLIC=0.0;SPECULAR=.55;
}
