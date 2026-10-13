shader_type spatial;
uniform vec4 base_tint : source_color = vec4(0.56,0.53,0.45,1.0);
uniform bool metal_surface = false;
varying vec3 surface_position;
float hash3(vec3 p){return fract(sin(dot(p,vec3(17.17,91.71,31.29)))*43758.5453);}
float grain(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){surface_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec3 p=surface_position;
 float pores=grain(p*24.0),stains=grain(p*1.7),chips=smoothstep(.67,.9,grain(p*9.0));
 float runoff=pow(.5+.5*sin(p.x*26.0+p.z*19.0+grain(p*.65)*8.0),18.0)*(.3+.7*stains);
 float dust=smoothstep(.25,.75,grain(p*.55));
 vec3 rust=base_tint.rgb*vec3(.92,.62,.43);
 vec3 surface=base_tint.rgb*(.80+pores*.19-stains*.09);
 surface=mix(surface,rust,(metal_surface ? .44:.10)*chips);
 surface*=1.0-runoff*(metal_surface ? .13:.09);
 ALBEDO=mix(surface,base_tint.rgb*vec3(1.05,1.015,.91),dust*.16);
 // Perturb view-space normals from a world-space height field, without requiring
 // mesh UVs/tangents or reading the screen. Fade distant pores to avoid shimmer.
 float height=(pores*.65+chips*.35)*mix(.002,.008,1.0-smoothstep(8.0,24.0,length(VERTEX)));
 vec3 dx=dFdx(VERTEX),dy=dFdy(VERTEX),n=normalize(NORMAL);
 vec3 rx=cross(dy,n),ry=cross(n,dx);
 float det=dot(dx,rx);
 vec3 gradient=sign(det)*(dFdx(height)*rx+dFdy(height)*ry);
 NORMAL=normalize(max(abs(det),0.000001)*n-gradient);
 ROUGHNESS=metal_surface ? .72+chips*.18 : .93;
 METALLIC=metal_surface ? .26*(1.0-chips*.75) : 0.0;
 SPECULAR=.32;
}
