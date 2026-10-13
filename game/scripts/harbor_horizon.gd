extends RefCounted
# Real open-window harbour shells, tied to submerged rock foundations.
var s: RefCounted
var root: Node3D
var stone: Material
var steel: Material
var boxes: Array[Transform3D]=[]
var rods: Array[Transform3D]=[]

func _init(shapes: RefCounted,parent: Node3D):
	s=shapes;root=parent
	stone=s.generated_surface("concrete",Color("a6ada8"),.35)
	steel=s.surface_pbr("rusty_metal_sheet",Color("827b68"),.45,.12)

func box(p: Vector3,size_value: Vector3):
	boxes.append(Transform3D(Basis.IDENTITY.scaled_local(size_value),p))

func rod(a: Vector3,b: Vector3,radius=.04):
	var d=b-a
	rods.append(Transform3D(Basis(Quaternion(Vector3.UP,d.normalized())).scaled_local(Vector3(radius,d.length(),radius)),(a+b)/2))

func batch(label: String,mesh: Mesh,mat: Material,transforms: Array[Transform3D],parent: Node3D):
	var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=transforms.size()
	for i in transforms.size():mm.set_instance_transform(i,transforms[i])
	var n=MultiMeshInstance3D.new();n.name=label;n.multimesh=mm;n.material_override=mat;parent.add_child(n)

func foundation(parent: Node3D):
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in 3:
		for j in 48:
			var points=[]
			for pair in [Vector2(ring,j),Vector2(ring,j+1),Vector2(ring+1,j+1),Vector2(ring+1,j)]:
				var a=pair.y*TAU/48;var r=[.01,5.4,7.8,9.5][int(pair.x)]
				var y=[1.2,1.05,-1.8,-3.8][int(pair.x)]
				r*=1+.07*sin(a*5)+.06*sin(a*3+.7)
				points.append(Vector3(cos(a)*r,y+.08*sin(a*7),sin(a)*r*.76))
			var norm=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
			if norm.y<0:norm=-norm
			s.add_face(st,points,norm,points.map(func(p):return Vector2(p.x,p.z)*.2))
	st.index();st.generate_tangents()
	var n=MeshInstance3D.new();n.name="SubmergedHarbourRock";n.mesh=st.commit()
	n.material_override=s.surface_pbr("brown_mud_02",Color("777c70"),.3);parent.add_child(n)

func build():
	for i in 5:
		boxes.clear();rods.clear()
		var theta=i*TAU/5+.2;var radius=48.0+(i%3)*8.0
		var ruin=Node3D.new();ruin.name="DistantFactory%d"%i;root.add_child(ruin)
		ruin.position=Vector3(cos(theta)*radius,-1.7,sin(theta)*radius);ruin.rotation.y=theta+.4
		foundation(ruin)
		var floors=2+i%3;var roof=1.2+floors*2.6
		box(Vector3(0,1.05,0),Vector3(7.8,.3,5.4))
		# Piers and horizontal lintels leave window holes through all four walls.
		for side in [-1,1]:
			for row in floors:
				var y=1.2+row*2.6
				for col in 5:box(Vector3(-3.6+col*1.8,y+1.3,side*2.4),Vector3(.34,2.6,.38))
				box(Vector3(0,y+.32,side*2.4),Vector3(7.5,.64,.4))
				box(Vector3(0,y+2.43,side*2.4),Vector3(7.5,.34,.4))
				for col in 4:
					var x=-2.7+col*1.8
					if (row+col+i)%4==0:continue
					rod(Vector3(x,y+.65,side*2.4),Vector3(x,y+2.26,side*2.4),.026)
				for col in 4:box(Vector3(side*3.6,y+1.3,-2.4+col*1.6),Vector3(.38,2.6,.34))
				for h in [.32,2.43]:box(Vector3(side*3.6,y+h,0),Vector3(.4,.44,5.0))
		for row in floors:
			box(Vector3(-1.1,1.2+row*2.6,0),Vector3(5.1,.18,4.7))
		# Broken roof trusses and purlins cast actual silhouette shadows.
		for x in [-3.6,-1.8,0,1.8,3.6]:
			rod(Vector3(x,roof,-2.5),Vector3(x,roof+1.5,0),.07)
			if x!=1.8:rod(Vector3(x,roof+1.5,0),Vector3(x,roof,2.5),.07)
			rod(Vector3(x,roof,-2.5),Vector3(x,roof,2.5),.045)
		for z in [-2.5,-1.25,0,1.25]:rod(Vector3(-3.8,roof+1.5-absf(z)*.6,z),Vector3(3.8,roof+1.5-absf(z)*.6,z),.035)
		batch("OpenWindowMasonry",s.bevel_box(Vector3.ONE),stone,boxes,ruin)
		var cylinder=CylinderMesh.new();cylinder.height=1;cylinder.top_radius=1;cylinder.bottom_radius=1;cylinder.radial_segments=8
		batch("BrokenRoofSteelwork",cylinder,steel,rods,ruin)
		ruin.set_meta("open_window_bays",floors*14)
		ruin.set_meta("foundation_bottom",-5.5)
