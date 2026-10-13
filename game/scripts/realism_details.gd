extends RefCounted
# Metre-scale construction details; all additions are visual geometry.
var c: RefCounted
var s: RefCounted
var root: Node3D
var rng=RandomNumberGenerator.new()
var fixtures: Array[Transform3D]=[]
var grit: Array[Transform3D]=[]
var leaves: Array[Transform3D]=[]
func _init(city: RefCounted):
	c=city;s=c.s;root=c.root;rng.seed=11300+Journey.chapter
func build():
	if is_instance_valid(c.garden.rotor):
		for mesh in c.garden.rotor.find_children("*","MeshInstance3D",true,false):
			if mesh.get_meta("bridge_tread",false):mesh.material_override=c.metal_material
	if Journey.chapter==1:
		for mesh in c.garden.elevator.find_children("*","MeshInstance3D",true,false):
			if mesh.mesh.get_aabb().size.y>.2:mesh.material_override=c.metal_material
	match Journey.chapter:
		0:
			stone_pier(Vector3(-3,1.1,-7),2.15,6.6)
			arcade_joints()
		1:
			stone_pier(Vector3(6,3.25,0),1.7,7.0)
			greenhouse_drains()
		2:
			for x in [-8.3,8.3]:
				for z in [-8,-3.5,1,5.5]:
					for y in [10.72,10.89]:c.box(Vector3(x,y,z),Vector3(.96,.018,.96),c.dark_material).set_meta("cg_batch",true)
	grates()
	ground_contact()
	var fixing=CylinderMesh.new();fixing.height=.027;fixing.top_radius=.022;fixing.bottom_radius=.022;fixing.radial_segments=6
	c.batch("DrainFixings",fixing,c.metal_material,fixtures)
	c.batch("SoilContactGravel",c.botany.pebble_mesh,c.soil_material,grit,false)
	var leaf_mat=c.botany.leaves.duplicate();leaf_mat.set_shader_parameter("leaf_tint",Color("786949"))
	c.batch("FallenLeaves",c.reconstruction.leaf_mesh,leaf_mat,leaves,false)
	root.set_meta("realism_details","1.13.0")
func stone_pier(center: Vector3,radius: float,height: float):
	# Individual curved blocks sit over the original solid pier. Recessed mortar
	# gaps expose the original cylinder; staggered courses have varied joint widths.
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows=ceili(height/.38);var course=height/rows;var segments=24
	for row in rows:
		var y0=center.y-height/2+row*course+.008
		var y1=y0+course-.017
		for segment in segments:
			var start=(segment+(row%2)*.5)*TAU/segments+.0035
			var end=start+TAU/segments-.008
			var shade=rng.randf_range(.86,1.03)
			for i in 4:
				var a=lerpf(start,end,i/4.0);var b=lerpf(start,end,(i+1)/4.0)
				var r=radius+.012
				var pa=Vector3(cos(a)*r,0,sin(a)*r)+Vector3(center.x,0,center.z)
				var pb=Vector3(cos(b)*r,0,sin(b)*r)+Vector3(center.x,0,center.z)
				var normal=Vector3(cos((a+b)/2),0,sin((a+b)/2))
				var vertices=[Vector3(pa.x,y0,pa.z),Vector3(pb.x,y0,pb.z),Vector3(pb.x,y1,pb.z),Vector3(pa.x,y1,pa.z)]
				if (vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).dot(normal)>0:vertices.reverse()
				for index in [0,1,2,0,2,3]:
					st.set_normal(normal);st.set_color(Color(shade,shade,shade));st.set_uv(Vector2(vertices[index].x,vertices[index].y));st.add_vertex(vertices[index])
	st.index();st.generate_tangents()
	var node=MeshInstance3D.new();node.name="JointedStonePier";node.mesh=st.commit()
	node.material_override=c.paving_material;root.add_child(node)
	node.set_meta("courses",rows);node.set_meta("radius",radius)
func arcade_joints():
	var mortar=StandardMaterial3D.new();mortar.albedo_color=Color("777268");mortar.roughness=.98
	for x in [-7.6,-3,1.6]:
		for side in [-1,1]:
			for row in 11:
				c.box(Vector3(x+side*2.0,1.75+row*.43,-5.026),Vector3(.44,.009,.009),mortar).set_meta("cg_batch",true)
		for i in range(1,18):
			var angle=PI*i/18
			var a=Vector3(x+cos(angle)*1.787,6.275+sin(angle)*1.787,-5.026)
			var b=Vector3(x+cos(angle)*2.236,6.275+sin(angle)*2.236,-5.026)
			var seam=c.box((a+b)/2,Vector3(.009,a.distance_to(b),.009),mortar)
			seam.quaternion=Quaternion(Vector3.UP,(b-a).normalized());seam.set_meta("cg_batch",true)
func greenhouse_drains():
	for x in [-10.16,11.16]:
		# Open gutter: base and two raised lips, attached to the existing drain.
		for dx in [-.10,.10]:c.box(Vector3(x+dx,11.55,1.8),Vector3(.023,.16,11.2),c.metal_material).set_meta("cg_batch",true)
		c.box(Vector3(x,11.48,1.8),Vector3(.20,.023,11.2),c.metal_material).set_meta("cg_batch",true)
		for y in [2.1,4.3,6.5,8.7,10.9]:
			var clamp=c.box(Vector3(x,y,7.4),Vector3(.16,.06,.16),c.metal_material);clamp.set_meta("cg_batch",true)
			fixtures.append(Transform3D(Basis(Quaternion(Vector3.UP,Vector3.BACK)),Vector3(x,y,7.494)))
		# A quarter circle, not an unconnected straight pipe, discharges onto quay.
		for i in 10:
			var a=i*PI/20;var b=(i+1)*PI/20
			var pa=Vector3(x,1.62-.28*sin(a),7.68-.28*cos(a))
			var pb=Vector3(x,1.62-.28*sin(b),7.68-.28*cos(b))
			var pipe=CylinderMesh.new();pipe.height=pa.distance_to(pb)+.008;pipe.top_radius=.057;pipe.bottom_radius=.057;pipe.radial_segments=12
			var n=MeshInstance3D.new();n.name="DrainElbow";n.mesh=pipe;n.material_override=c.metal_material
			n.position=(pa+pb)/2;n.quaternion=Quaternion(Vector3.UP,(pb-pa).normalized());root.add_child(n)
func grates():
	for x in [-9.1,10.1]:
		var z=7.8;var y=c.quay_height(x,z)+.024
		c.box(Vector3(x,y,z),Vector3(.42,.018,.66),c.dark_material).set_meta("cg_batch",true)
		for i in 9:c.box(Vector3(x,y+.014,z-.28+i*.07),Vector3(.38,.018,.023),c.metal_material).set_meta("cg_batch",true)
		for side in [-1,1]:c.box(Vector3(x+side*.22,y+.012,z),Vector3(.032,.04,.70),c.metal_material).set_meta("cg_batch",true)
func ground_contact():
	# Contact detail stays beside nursery pots and bed rims, away from readouts.
	var centers=[Vector3(-8.8,1.35,6),Vector3(10.2,1.35,4.3)]
	if Journey.chapter==2:centers=[Vector3(-6.45,6,.7),Vector3(6.45,6,.7)]
	for center in centers:
		for i in 32:
			var p=center+Vector3(rng.randf_range(-.35,.35),.034,rng.randf_range(-.55,.55))
			var size=rng.randf_range(.022,.075)
			grit.append(Transform3D(Basis.from_euler(Vector3(0,rng.randf()*TAU,.1)).scaled_local(Vector3(size,size*.45,size)),p))
		for i in 12:
			var p=center+Vector3(rng.randf_range(-.45,.45),.029,rng.randf_range(-.65,.65))
			leaves.append(Transform3D(Basis.from_euler(Vector3(-PI/2,rng.randf()*TAU,.12)).scaled_local(Vector3(.11,.17,.11)),p))
