extends RefCounted
# Original scenery around the verified playable paths. Decorative meshes carry no collision.
var s: RefCounted
var root: Node3D
const RUST = Color("765540")
const SAND = Color("a79b80")
const SOIL = Color("615c46")
const LEAF = Color("748165")
const CoastalScenery = preload("res://scripts/coastal_scenery.gd")

func _init(shapes: RefCounted, parent: Node3D):
	s = shapes
	root = Node3D.new()
	root.name = "ChapterScenery"
	parent.add_child(root)

func box(p: Vector3, size: Vector3, c: Color):
	var n=s.detail(p,size,c,root)
	if c.a==1.0: n.material_override=s.weathered_material(c,c==RUST)
	if c==SOIL:n.material_override=s.surface_pbr("brown_mud_02",Color("c9c3a8"),.65)
	if c==RUST:n.material_override=s.surface_pbr("rusty_metal_sheet",Color("cfbaa3"),.55,.12)
	return n

func pipe(a: Vector3, b: Vector3, radius: float, color: Color):
	var n = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 16
	n.mesh = mesh
	n.material_override = s.surface_pbr("rusty_metal_sheet",color.lightened(.48),.55,.12)
	root.add_child(n)
	n.position = (a + b) / 2
	var axis = (b - a).normalized()
	if absf(axis.dot(Vector3.UP)) < 0.999:
		n.quaternion = Quaternion(Vector3.UP, axis)
	return n

func plant(p: Vector3, scale_value: float, kind: int):
	var n = s.plant(p, scale_value, kind, root)
	for collider in n.find_children("*", "StaticBody3D", true, false):
		collider.collision_layer = 0
		collider.collision_mask = 0
	return n

func sign_at(p: Vector3, text: String, color: Color):
	box(p, Vector3(2.7,0.85,0.12), color)
	var label = Label3D.new()
	label.font = load("res://assets/title_font.tres")
	label.text = text
	label.font_size = 40
	label.pixel_size = 0.007
	label.modulate = Color("e4dfcd")
	label.outline_size = 2
	root.add_child(label)
	label.position = p + Vector3(0,0,0.075)

func pump_station():
	root.set_meta("place", "旧泵站")
	# A grounded quay rather than a ring of identical temples.
	for side in [-1, 1]:
		for i in 7:
			var phase=i+(7 if side>0 else 0)
			var bank=irregular_island(Vector3(side*(11+i*1.1),-.95+.12*sin(i),-5+i*2.3),phase)
			bank.name="ErodedBreakwater%d"%phase
			bank.scale=Vector3(.28,.68,.36)
			bank.material_override=s.weathered_material(Color("777f76"))
			bank.rotation.y = side * 0.12
	box(Vector3(-3,1.0,-11.5), Vector3(7,4.5,4), SOIL)
	broken_wall(Vector3(-3,5.4,-10),6.5,8.4,.55)
	for x in [-6.1, 0.1]:
		box(Vector3(x,5.7,-8), Vector3(0.65,7.8,4), SAND.darkened(0.13))
	for side in [-1,1]:
		var roofing=box(Vector3(-3+side*2.5,9.5,-8),Vector3(1.6,.15,4.5),RUST)
		roofing.rotation.z=side*.06
	sign_at(Vector3(-3,8.3,-9.66), "ZONE 01 · 旧泵站", RUST)
	for x in [-5.0, -1.0]:
		pipe(Vector3(x,0,-9.3),Vector3(x,7.2,-9.3),0.33,RUST)
		pipe(Vector3(x,7.2,-9.3),Vector3(x,7.2,-6.4),0.33,RUST)
		for y in [2.0,4.3,6.3]:
			pipe(Vector3(x,y-0.07,-9.3),Vector3(x,y+0.07,-9.3),0.41,SAND)
	# Old tanks and a visible filter basin beside the water-channel destination.
	for x in [4.5,8.0]:
		pipe(Vector3(x,0.3,-6),Vector3(x,5.4,-6),1.25,Color("69715c"))
		pipe(Vector3(x,5.4,-6),Vector3(x,5.7,-6),1.35,RUST)
		box(Vector3(x,2.8,-4.71),Vector3(0.6,0.5,0.035),SAND)
	for z in [-0.9,2.9]:
		box(Vector3(1.5,1.3,z),Vector3(5.5,0.7,0.15),SAND)
	for x in [-1.2,4.2]:
		box(Vector3(x,1.3,1),Vector3(0.15,0.7,4),SAND)
	pipe(Vector3(-4.7,1.1,-8),Vector3(-4.7,1.1,0),0.2,RUST)
	box(Vector3(-7.6,3.2,3.7),Vector3(1.3,0.14,0.55),RUST)
	for x in [-8.1,-7.1]:
		box(Vector3(x,2.96,3.7),Vector3(0.09,0.5,0.4),RUST)

func greenhouse():
	root.set_meta("place", "废弃温室")
	# A steel-and-glass enclosure with a high broken roof: ample headroom over the lift.
	var metal = Color("646858")
	for x in range(-10,12,3):
		for z in [-3.8,7.4]:
			pipe(Vector3(x,0,z),Vector3(x,11.6,z),0.09,metal)
		pipe(Vector3(x,11.6,-3.8),Vector3(x,13.4,1.8),0.08,metal)
		pipe(Vector3(x,13.4,1.8),Vector3(x,11.6,7.4),0.08,metal)
	for z in [-3.8,7.4]:
		for y in [3.2,7.3,11.6]:
			pipe(Vector3(-10,y,z),Vector3(11,y,z),0.075,metal)
	pipe(Vector3(-10,13.4,1.8),Vector3(11,13.4,1.8),0.09,metal)
	for x in [-10,8]:
		pipe(Vector3(x,.8,-3.8),Vector3(x+3,7.3,-3.8),.045,RUST)
		pipe(Vector3(x,7.3,7.4),Vector3(x+3,.8,7.4),.045,RUST)
	broken_wall(Vector3(-11.7,2.0,2.0),2.8,4.0,.35)
	for x in [-8.0,-4.0,0.0,4.0,8.0]:
		box(Vector3(x,1.0,-6),Vector3(2.8,1.2,2.2),SAND)
		box(Vector3(x,1.64,-6),Vector3(2.55,0.09,1.95),SOIL)
		for j in 3: plant(Vector3(x-0.7+j*0.7,1.7,-6),0.7,j%2)
	sign_at(Vector3(-6,5.9,7.32), "ZONE 02 · 日光温室", metal)
	# Old lighting racks, empty planter benches and sealed vent fins.
	for x in [-7,-4,0,3]:
		box(Vector3(x,10.7,-2.4),Vector3(1.4,0.16,0.3),RUST)
		pipe(Vector3(x,10.7,-2.4),Vector3(x,11.8,-2.4),0.025,metal)
	for i in 5:
		box(Vector3(-9.8,6.4+i*0.27,1.5),Vector3(0.12,0.14,2.6),RUST)

func regrowth_garden():
	root.set_meta("place", "回生花园")
	var botany=CoastalScenery.new(s,root)
	# Each habitat is a different raised bed, with visible soil and root systems.
	for i in 3:
		var center = [Vector3(-5,6,0),Vector3(5,6,0),Vector3(0,6,-5)][i]
		for side in [-1,1]:
			var p = center + Vector3(side*1.28,0.12,0)
			box(p,Vector3(0.45,0.24,2.75),SAND)
			box(p+Vector3(0,0.13,0),Vector3(0.38,0.045,2.5),SOIL)
			for j in 4: plant(p+Vector3(0,0.15,-0.92+j*0.61),0.38+(j%2)*0.16,i)
			botany.meadow(p+Vector3(0,.15,0),Vector2(.32,2.4),root,42)
			for j in 4:
				pipe(center+Vector3(side*1.3,-0.1,-1+j*0.65),center+Vector3(side*1.0,-2.4,-0.8+j*0.55),0.035,SOIL)
	# Small distant islands are reclaimed by trees, rather than more copies of the pavilion.
	for i in 7:
		var a = float(i) * TAU / 7
		var p = Vector3(cos(a)*17,-0.3,sin(a)*17-4)
		irregular_island(p,i)
		for j in 2: botany.tree(p+Vector3(-.9+j*1.8,.9,.4*sin(j*2)),.55+j*.12,root,i+j)
	# A mature landmark beside the final seed, its branching silhouette readable from below.
	var base = Vector3(2.2,8.5,-10.7)
	botany.tree(base,1.2,root,3)
	sign_at(Vector3(0,9.2,-12.1), "留给后来者", SOIL)

func broken_wall(p: Vector3,width: float,height: float,depth: float):
	for i in 3:
		var h=height*[.83,.62,.97][i]
		var center=p+Vector3((i-1)*width/3,-height/2+h/2,0)
		box(center,Vector3(width/3-.12,h,depth),SAND)
		for j in 2:
			s.rust_rod(center+Vector3(-.22+j*.4,h/2-.1,0),center+Vector3(-.1+j*.4,h/2+.52,.08),.024,root)
		var chip=box(center+Vector3(width/6-.11,h*.25,depth*.52),Vector3(.17,.28,.05),SOIL)
		chip.rotation.z=.28*i

func irregular_island(p: Vector3,phase: int):
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for band in 3:
		for i in 32:
			var points=[];var uv=[]
			for pair in [Vector2(i,band),Vector2(i+1,band),Vector2(i+1,band+1),Vector2(i,band+1)]:
				var a=pair.x*TAU/32
				var radius=[0.01,2.2,3.9,5.1][int(pair.y)]*(1+.11*sin(a*5+phase)+.09*sin(a*3-phase))
				var y=[.86,.79,-1.3,-2.8][int(pair.y)]+.07*sin(a*4+phase)
				points.append(Vector3(cos(a)*radius,y,sin(a)*radius*.87));uv.append(Vector2(cos(a)*radius,sin(a)*radius))
			var normal=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
			if normal.y<0:normal=-normal
			s.add_face(st,points,normal,uv)
	st.index();st.generate_normals();st.generate_tangents()
	var n=MeshInstance3D.new();n.name="ReclaimedRockIsland%d"%phase;n.mesh=st.commit()
	n.material_override=s.surface_pbr("brown_mud_02",Color("727b58"),.65);n.position=p;root.add_child(n)
	return n
