shader_type canvas_item;
render_mode unshaded;
uniform sampler2D previous_frame : source_color, filter_linear;
uniform vec2 viewport_size = vec2(1280.0,800.0);
uniform vec2 image_size = vec2(1584.0,992.0);
uniform float elapsed = 0.0;
uniform float transition_elapsed = 0.0;
uniform float previous_time = 0.0;
uniform float direction = 1.0;
uniform float previous_direction = 1.0;
uniform bool has_previous = false;
uniform bool compact = false;
uniform int page = 0;
uniform int previous_page = -1;
vec2 camera_uv(vec2 uv, float seconds, float side) {
	float source_aspect = image_size.x / image_size.y;
	float view_aspect = viewport_size.x / viewport_size.y;
	vec2 fit = vec2(min(view_aspect/source_aspect,1.0),min(source_aspect/view_aspect,1.0));
	// Monotonic easing approaches a stop; no loop jump or accumulating drift.
	float travel = 1.0-exp(-max(seconds,0.0)/24.0);
	vec2 framed = (uv-0.5)*fit/(1.025+travel*0.045);
	return framed+0.5+vec2(side*travel*0.006,-travel*0.003);
}
vec3 atmosphere(vec3 base,vec2 uv,vec2 source_uv,float seconds,int chapter) {
	// Light-only overlays: building edges and character silhouettes stay rigid.
	float fog = sin(uv.x*8.0+seconds*.08)+sin(uv.y*11.0-uv.x*5.0-seconds*.055);
	float mist = (fog*.25+.5)*(1.0-smoothstep(.64,.92,uv.y))*.021;
	base=mix(base,vec3(.55,.65,.65),mist);
	if(chapter==1) {
		vec2 lens=(source_uv-vec2(.66,.365))/vec2(.044,.067);
		float glow=exp(-dot(lens,lens)*2.8)*(.5+.5*sin(seconds*1.15));
		base+=vec3(.006,.019,.015)*glow;
	}
	for(int i=0;i<8;i++) {
		float seed=float(i);
		float life=fract(seed*.137+seconds*.019);
		vec2 mote=vec2(.54+fract(seed*.173+seconds*.002)*.42,.91-life*.74);
		float distance=length((uv-mote)*viewport_size);
		float opacity=sin(life*3.14159)*sin(life*3.14159);
		float light=(1.0-smoothstep(.3,1.4,distance))*opacity*(chapter==2?.16:.065);
		base+=vec3(.95,.78,.49)*light;
	}
	return base;
}
void fragment() {
	vec2 current_uv=camera_uv(UV,elapsed,direction);
	vec3 current=atmosphere(texture(TEXTURE,current_uv).rgb,UV,current_uv,elapsed,page);
	vec2 previous_uv=camera_uv(UV,previous_time+elapsed,previous_direction);
	vec3 previous=atmosphere(texture(previous_frame,previous_uv).rgb,UV,previous_uv,previous_time+elapsed,previous_page);
	float dissolve = has_previous ? smoothstep(0.0,1.25,transition_elapsed) : 1.0;
	vec3 scene = mix(previous,current,dissolve);
	float left = 1.0-smoothstep(compact?0.30:0.23,compact?0.95:0.66,UV.x);
	float bottom = smoothstep(0.75,1.0,UV.y)*0.44;
	float top = (1.0-smoothstep(0.0,0.18,UV.y))*0.23;
	float shade = clamp(left*(compact?0.80:0.77)+bottom+top,0.0,0.90);
	scene = mix(scene,vec3(0.018,0.032,0.037),shade);
	float vignette = smoothstep(0.35,0.85,length(UV-0.5))*0.10;
	COLOR = vec4(scene*(1.0-vignette),1.0);
}
