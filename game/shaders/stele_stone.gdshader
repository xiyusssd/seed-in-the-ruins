shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D stone_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D stone_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D stone_roughness : filter_linear_mipmap_anisotropic;
uniform sampler2D inscription_depth : filter_linear_mipmap_anisotropic;
uniform float age_offset = 0.0;
varying vec3 local_face;
varying vec3 local_position;
void vertex() { local_face=NORMAL;local_position=VERTEX; }
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float grain(vec2 p) {
	vec2 cell=floor(p), f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(hash(cell),hash(cell+vec2(1,0)),f.x),mix(hash(cell+vec2(0,1)),hash(cell+vec2(1,1)),f.x),f.y);
}
void fragment() {
	vec2 p=UV+vec2(age_offset,age_offset*.31);
	float broad=grain(p*7.0),fine=grain(p*41.0);
	float base=1.0-smoothstep(.10,.73,UV.y);
	float edge=smoothstep(.44,.61,abs(UV.x));
	float moisture=clamp(base*(.32+.68*broad)+edge*.28*broad,0.0,.85);
	float spots=smoothstep(.57,.72,broad)*(.25+fine*.45);
	vec3 stone=texture(stone_albedo,p*1.3).rgb*vec3(.82,.78,.67);
	stone*=.87+.13*fine;
	stone=mix(stone,stone*vec3(.59,.66,.50),moisture*.65+spots*.35);
	vec2 etch_uv=vec2((local_position.x+.52)/1.04,(1.77-local_position.y)/1.03);
	float intact_face=step(.9,local_face.z)*step(0.0,etch_uv.x)*step(etch_uv.x,1.0)*step(0.0,etch_uv.y)*step(etch_uv.y,1.0);
	float depth=texture(inscription_depth,etch_uv).r*intact_face;
	vec2 texel=1.0/vec2(textureSize(inscription_depth,0));
	float dx=texture(inscription_depth,etch_uv+vec2(texel.x,0)).r-texture(inscription_depth,etch_uv-vec2(texel.x,0)).r;
	float dy=texture(inscription_depth,etch_uv+vec2(0,texel.y)).r-texture(inscription_depth,etch_uv-vec2(0,texel.y)).r;
	// Shallow recesses have directional bevel lighting and surviving, uneven
	// depth. Stone grain remains visible through the worn interior of a stroke.
	vec3 etch_normal=normalize(vec3(dx*1.2,dy*1.2,1.0));
	vec3 grain_normal=texture(stone_normal,p*1.3).rgb*2.0-1.0;
	vec3 combined=normalize(vec3(grain_normal.xy*.20+etch_normal.xy*intact_face,1.0));
	ALBEDO=stone*COLOR.rgb*mix(1.0,.32,depth);
	ROUGHNESS=clamp(texture(stone_roughness,p*1.3).r*.25+.72,.85,1.0);
	NORMAL_MAP=combined*.5+.5;NORMAL_MAP_DEPTH=1.0;
	SPECULAR=.18;
}
