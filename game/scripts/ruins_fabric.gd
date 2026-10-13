extends Node3D
# Metre-scale construction scars and fasteners, instanced without blocking paths.
var garden: Node3D
var chips=[]
var steel=[]
func _init(world):garden=world
func _ready():
	name="ConstructionFabric"
	var rng=RandomNumberGenerator.new();rng.seed=18021+Journey.chapter
	for id in garden.nodes:
		var p:Vector3=garden.nodes[id]
		if id in ["stair_top","entry_step","summit_step"]:continue
		for side in [-1,1]:
			for i in 8:
				var offset=Vector3(side*(1.28+rng.randf_range(-.10,.10)),-.20,-.82+i*.23)
				var scale_value=Vector3(rng.randf_range(.07,.17),rng.randf_range(.06,.13),rng.randf_range(.08,.18))
				chips.append(Transform3D(Basis.from_euler(Vector3(rng.randf()*.6,rng.randf()*TAU,.12)).scaled(scale_value),p+offset))
			for i in 3:
				steel.append(Transform3D(Basis.IDENTITY.scaled(Vector3(.03,.24,.03)),p+Vector3(side*1.32,-.12,-.6+i*.48)))
	if Journey.chapter==0:
		for x in [4.5,8.0]:
			for y in [1.8,3.7,5.48]:
				for i in 24:
					var a=i*TAU/24
					var p=Vector3(x+cos(a)*1.275,y,-6+sin(a)*1.275)
					steel.append(Transform3D(Basis(Vector3.UP,-a).scaled(Vector3(.07,.085,.035)),p))
			for i in 4:
				var a=i*PI/2
				steel.append(Transform3D(Basis(Vector3.UP,-a).scaled(Vector3(.055,4.7,.055)),Vector3(x+cos(a)*1.28,2.8,-6+sin(a)*1.28)))
		# Small masonry fragments sit outside the pump doorway, never on its floor.
		for i in 35:
			var p=Vector3(-6.5+rng.randf_range(-.7,.3),4.94,-10.4+rng.randf_range(-.5,1.5))
			chips.append(Transform3D(Basis.from_euler(Vector3(.2,rng.randf()*TAU,.18)).scaled(Vector3(.26,.1,.18)),p))
	elif Journey.chapter==1:
		for x in range(-10,12,3):
			for z in [-3.8,7.4]:
				for y in [3.2,7.3,11.6]:
					for offset in [-.13,.13]:steel.append(Transform3D(Basis.IDENTITY.scaled(Vector3(.07,.07,.04)),Vector3(x+offset,y,z+.095)))
	else:
		for id in ["west","east","north"]:
			var p:Vector3=garden.nodes[id]
			for side in [-1,1]:
				for i in 5:steel.append(Transform3D(Basis.IDENTITY.scaled(Vector3(.04,.05,.04)),p+Vector3(side*1.3,.36,-.9+i*.45)))
	batch("SpalledAggregate",chip_mesh(),garden.s.weathered_material(Color("858174")),chips)
	var bolt=BoxMesh.new();bolt.size=Vector3.ONE
	batch("RustFasteners",bolt,garden.s.surface_pbr("rusty_metal_sheet",Color("b9a089"),1.5,.25),steel)
func batch(label: String,mesh: Mesh,material: Material,transforms: Array):
	var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=transforms.size()
	for i in transforms.size():mm.set_instance_transform(i,transforms[i])
	var node=MultiMeshInstance3D.new();node.name=label;node.multimesh=mm;node.material_override=material;add_child(node)
func chip_mesh() -> ArrayMesh:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points=[Vector3(-.5,-.4,-.5),Vector3(.45,-.5,-.4),Vector3(.5,-.35,.4),Vector3(-.38,-.5,.5),Vector3(-.4,.45,-.28),Vector3(.27,.5,-.4),Vector3(.36,.26,.5),Vector3(-.5,.35,.26)]
	for indices in [[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7],[4,5,6,7],[3,2,1,0]]:
		var face=[]
		for i in indices:face.append(points[i])
		var normal=(face[2]-face[0]).cross(face[1]-face[0]).normalized()
		garden.s.add_face(st,face,normal)
	return st.commit()
