shader_type spatial;
uniform sampler2D albedo_texture : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D normal_texture : hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D roughness_texture : filter_linear_mipmap_anisotropic,repeat_enable;
uniform vec4 tint : source_color=vec4(.75,.73,.68,1);
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
float hash2(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise2(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash2(i),hash2(i+vec2(1,0)),f.x),mix(hash2(i+vec2(0,1)),hash2(i+vec2(1)),f.x),f.y);}
vec3 decode_normal(vec3 texel){
 vec2 xy=texel.rg*2.-1.;
 return vec3(xy,sqrt(max(1.-dot(xy,xy),.001)));
}
void fragment(){
 vec3 n=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0)).xyz);
 vec3 weights=pow(abs(n),vec3(4));weights/=max(dot(weights,vec3(1)),.001);
 vec3 p=world_position*.38;
 vec2 ux=vec2(p.z*sign(n.x),p.y),uy=vec2(p.x,p.z*sign(n.y)),uz=vec2(p.x*sign(n.z),p.y);
 vec3 base=texture(albedo_texture,ux).rgb*weights.x+texture(albedo_texture,uy).rgb*weights.y+texture(albedo_texture,uz).rgb*weights.z;
 float rough=texture(roughness_texture,ux).r*weights.x+texture(roughness_texture,uy).r*weights.y+texture(roughness_texture,uz).r*weights.z;
 vec3 nx=decode_normal(texture(normal_texture,ux).rgb),ny=decode_normal(texture(normal_texture,uy).rgb),nz=decode_normal(texture(normal_texture,uz).rgb);
 vec3 perturb=vec3(nx.z*sign(n.x),nx.y,nx.x*sign(n.x))*weights.x+vec3(ny.x,ny.z*sign(n.y),ny.y*sign(n.y))*weights.y+vec3(nz.x*sign(n.z),nz.y,nz.z*sign(n.z))*weights.z;
 // Reconstruct compressed two-channel normals and retain the geometric hemisphere.
 vec3 tangent_detail=perturb-n*dot(n,perturb);
 NORMAL=normalize((VIEW_MATRIX*vec4(normalize(n+tangent_detail*.32),0)).xyz);
 float patch=noise2(world_position.xz*.21+world_position.yy*.13);
 float trails=pow(noise2(vec2(world_position.x+world_position.z,world_position.y*.055)*2.7),4.);
 float wet=(1.-smoothstep(-.8,1.8,world_position.y))*(.35+.65*patch);
 float moss=(1.-smoothstep(.2,2.4,world_position.y))*smoothstep(.5,.82,patch)*(1.-abs(n.y)*.55);
 vec3 concrete=base*tint.rgb*(.91+.12*patch);
 concrete=mix(concrete,concrete*vec3(.61,.60,.49),trails*.23);
 concrete=mix(concrete,vec3(.12,.17,.11),moss*.34);
 ALBEDO=concrete*(1.-wet*.23)*COLOR.rgb;
 ROUGHNESS=clamp(rough*.8+.17-wet*.27,.45,.99);
 SPECULAR=.3;
}
