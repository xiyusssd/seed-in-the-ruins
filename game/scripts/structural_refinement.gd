extends RefCounted
# Visible metre-scale load paths. No collision or puzzle state is added here.
var c: RefCounted
var s: RefCounted
var root: Node3D
var members: Array[Transform3D]=[]
var bolts: Array[Transform3D]=[]
var endpoints: Array=[]
var plates: Array[Transform3D]=[]
var stones: Array[Transform3D]=[]
var drains: Array[Transform3D]=[]
var steel: StandardMaterial3D

func _init(city: RefCounted):
	c=city;s=c.s;root=c.root
	steel=c.metal_material.duplicate();steel.albedo_color=Color("897b65")
	steel.roughness=.82;steel.metallic=.22

func member(a: Vector3,b: Vector3):
	var d=b-a
	members.append(Transform3D(Basis(Quaternion(Vector3.UP,d.normalized())).scaled_local(Vector3(1,d.length(),1)),(a+b)/2))
	endpoints.append([a,b])

func plate(p: Vector3,size_value: Vector3,normal=Vector3.BACK):
	var basis=Basis(Quaternion(Vector3.BACK,normal))
	plates.append(Transform3D(basis.scaled_local(size_value),p))
	for x in [-1,1]:
		for y in [-1,1]:
			var at=p+basis*Vector3(x*size_value.x*.3,y*size_value.y*.3,size_value.z*.5+.012)
			bolts.append(Transform3D(Basis(Quaternion(Vector3.UP,normal)),at))

func stone(p: Vector3,size_value: Vector3):
	stones.append(Transform3D(Basis.IDENTITY.scaled_local(size_value),p))

func build():
	match Journey.chapter:
		0:pump_masonry()
		1:greenhouse_trusses()
		2:orangery_bracing()
	var label=["PumpServiceMembers","RoofTrussMembers","OrangeryRoofMembers"][Journey.chapter]
	var frame=c.batch(label,i_section(),steel,members)
	if frame:frame.set_meta("member_endpoints",endpoints)
	c.batch("SteelConnectionPlates",s.bevel_box(Vector3.ONE),steel,plates)
	var bolt=CylinderMesh.new();bolt.height=.035;bolt.top_radius=.024;bolt.bottom_radius=.024;bolt.radial_segments=6
	c.batch("SteelFixingBolts",bolt,steel,bolts)
	var pipe=CylinderMesh.new();pipe.height=1;pipe.top_radius=.055;pipe.bottom_radius=.055;pipe.radial_segments=12
	c.batch("GreenhouseDownpipes",pipe,steel,drains)
	c.batch("DressedCopingStones",s.bevel_box(Vector3.ONE),c.paving_material,stones)
	root.set_meta("structural_refinement","1.12.0")

func greenhouse_trusses():
	# A triangulated tie truss at each existing roof frame; the vent bay remains open.
	for x in [-10,-7,-4,-1,2,5,8,11]:
		var left=Vector3(x,11.6,-3.8);var right=Vector3(x,11.6,7.4)
		var ridge=Vector3(x,13.4,1.8)
		member(left,right);member(left,ridge);member(ridge,right)
		for z in [-1.0,1.8,4.6]:
			var bottom=Vector3(x,11.6,z)
			var top=Vector3(x,13.4-absf(z-1.8)*.32142857,z)
			member(bottom,top)
		member(left,Vector3(x,12.5,-1.0));member(Vector3(x,11.6,-1.0),ridge)
		member(ridge,Vector3(x,11.6,4.6));member(Vector3(x,12.5,4.6),right)
		for joint in [left,right,ridge]:plate(joint,Vector3(.32,.34,.035),Vector3.RIGHT)
		for z in [-3.8,7.4]:
			plate(Vector3(x,1.41,z),Vector3(.42,.42,.06),Vector3.UP)
			stone(Vector3(x,1.38,z),Vector3(.52,.06,.52))
	# A real channel and end drain sit above the side walls, below the glazing.
	for x in [-10.16,11.16]:
		member(Vector3(x,11.49,-3.8),Vector3(x,11.49,7.4))
		drains.append(Transform3D(Basis.IDENTITY.scaled_local(Vector3(1,9.87,1)),Vector3(x,6.555,7.4)))

func orangery_bracing():
	# Existing arch piers carry posts, knee braces and continuous longitudinal ties.
	for x in [-8.3,8.3]:
		member(Vector3(x,13,-8),Vector3(x,13,5.5))
		for z in [-8,-3.5,1,5.5]:
			var base=Vector3(x,10.65,z);var top=Vector3(x,13,z)
			member(base,top)
			member(base+Vector3(0,.45,0),top+Vector3(-signf(x)*1.15,.152,0))
			member(base+Vector3(0,.45,0),top+Vector3(0,0,.85 if z<5 else -.85))
			plate(base,Vector3(.45,.45,.07),Vector3.UP)
			plate(top,Vector3(.34,.28,.05))
			stone(Vector3(x,10.55,z),Vector3(.98,.16,.98))
	for z in [-8,-3.5,1,5.5]:
		member(Vector3(-8.3,13,z),Vector3(0,14.1,z))
		member(Vector3(0,14.1,z),Vector3(8.3,13,z))
		member(Vector3(-8.3,12.76,z),Vector3(8.3,12.76,z))
		member(Vector3(0,12.76,z),Vector3(0,14.1,z))
		plate(Vector3(0,14.1,z),Vector3(.3,.34,.05))
	member(Vector3(0,14.1,-8),Vector3(0,14.1,5.5))
	# Jointed stone bed rims stay outside the central walking/interaction area.
	for center in [Vector3(-5,6,0),Vector3(5,6,0),Vector3(0,6,-5)]:
		for side in [-1,1]:
			for j in 7:
				stone(center+Vector3(side*1.28,.29,-1.15+j*.38),Vector3(.48,.085,.36))
			for z in [-1.37,1.37]:stone(center+Vector3(side*1.28,.18,z),Vector3(.46,.26,.10))

func pump_masonry():
	# Cut-stone springers and cornice blocks express the arcade's actual thickness.
	for x in [-7.6,-3,1.6]:
		for side in [-1,1]:
			var jamb=x+side*2.02
			stone(Vector3(jamb,1.46,-5.4),Vector3(.65,.22,.95))
			stone(Vector3(jamb,6.28,-5.4),Vector3(.62,.20,.91))
		for j in 9:stone(Vector3(x-1.9+j*.48,8.73,-5.4),Vector3(.46,.20,.92))
	# Straps fasten the existing exposed pipe runs to the pump wall.
	for x in [-5,-1]:
		for y in [2,4.3,6.3]:plate(Vector3(x,y,-9.48),Vector3(.76,.16,.045))
	member(Vector3(-6.3,9.45,-9.8),Vector3(.3,9.45,-9.8))

func i_section() -> ArrayMesh:
	# Twelve-point outline, extruded on local Y: open web recesses with capped ends.
	var outline=[Vector2(-.09,-.07),Vector2(.09,-.07),Vector2(.09,-.049),Vector2(.013,-.049),Vector2(.013,.049),Vector2(.09,.049),Vector2(.09,.07),Vector2(-.09,.07),Vector2(-.09,.049),Vector2(-.013,.049),Vector2(-.013,-.049),Vector2(-.09,-.049)]
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var a:Vector2=outline[i];var b:Vector2=outline[(i+1)%outline.size()]
		var normal=Vector3(b.y-a.y,0,a.x-b.x).normalized()
		s.add_face(st,[Vector3(a.x,-.5,a.y),Vector3(b.x,-.5,b.y),Vector3(b.x,.5,b.y),Vector3(a.x,.5,a.y)],normal,[Vector2(0,0),Vector2(a.distance_to(b),0),Vector2(a.distance_to(b),1),Vector2(0,1)])
	var polygon=PackedVector2Array(outline);var indices=Geometry2D.triangulate_polygon(polygon)
	for side in [-1,1]:
		for j in range(0,indices.size(),3):
			var pts=[];var uv=[]
			for k in 3:
				var p:Vector2=outline[indices[j+k]];pts.append(Vector3(p.x,side*.5,p.y));uv.append(p)
			s.add_face(st,pts,Vector3(0,side,0),uv)
	st.index();st.generate_tangents();return st.commit()
