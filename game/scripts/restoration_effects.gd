extends Node3D
# Persistent physical results of repair, restored from the existing puzzle save.
var garden: Node3D
var groups: Dictionary={}
var amounts: Dictionary={}
var growing: Array=[]
var lights: Array=[]
var reservoir: MeshInstance3D
var flow_material: ShaderMaterial
var botany: RefCounted
var shapes: RefCounted
func _init(world):garden=world;name="RestorationEffects"
func build():
	shapes=load("res://scripts/garden_shapes.gd").new(self)
	botany=load("res://scripts/coastal_scenery.gd").new(shapes,self)
	flow_material=ShaderMaterial.new();flow_material.shader=preload("res://shaders/restoration_flow.gdshader")
	for task in Puzzles.TASKS[Journey.chapter]:
		var group=Node3D.new();group.name=task;add_child(group);groups[task]=group;amounts[task]=0.0
	match Journey.chapter:
		0:water_results()
		1:sun_results()
		2:garden_results()
	if garden.wind_field:
		for n in find_children("*","MultiMeshInstance3D",true,false):
			if n.material_override is ShaderMaterial and n.material_override.shader.resource_path.ends_with("coastal_foliage.gdshader"):
				if n.material_override not in garden.wind_field.leaf_materials:garden.wind_field.leaf_materials.append(n.material_override)
	refresh()
func stream(a: Vector3,b: Vector3,width: float,task: String):
	var mesh=BoxMesh.new();mesh.size=Vector3(width,a.distance_to(b),width*.32)
	var n=MeshInstance3D.new();n.name="RunningWater";n.mesh=mesh;n.material_override=flow_material
	groups[task].add_child(n);n.position=(a+b)/2;n.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n
func sunbeam(a: Vector3,b: Vector3,width: float,task: String):
	var axis=(b-a).normalized()
	for side in 3:
		var mesh=QuadMesh.new();mesh.size=Vector2(width,a.distance_to(b))
		var n=MeshInstance3D.new();n.name="FilteredSunlight";n.mesh=mesh
		var mat=ShaderMaterial.new();mat.shader=preload("res://shaders/restoration_sunbeam.gdshader");n.material_override=mat
		groups[task].add_child(n);n.position=(a+b)/2
		n.basis=Basis(Quaternion(Vector3.UP,axis))*Basis(Vector3.UP,side*PI/3)
		n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func bounce(p: Vector3,task: String,energy: float,radius: float):
	var n=OmniLight3D.new();n.name="RepairBounce";groups[task].add_child(n);n.position=p
	n.light_color=Color("ffe0a6");n.omni_range=radius;n.light_energy=0;n.shadow_enabled=false
	lights.append({"node":n,"task":task,"energy":energy})
func foliage(p: Vector3,size_value: Vector2,count: int,task: String,flowers=false):
	# Curved leaves, stems and flower petals are real instanced meshes.
	var root=Node3D.new();root.name="ReclaimedPlantBed";groups[task].add_child(root);root.position=p
	var leaves: Array[Transform3D]=[];var blooms: Array[Transform3D]=[];var stems: Array[Transform3D]=[]
	for i in count:
		var x=sin(i*7.13)*size_value.x*.45;var z=cos(i*5.73)*size_value.y*.45
		var base=Vector3(x,0,z);var h=.42+.5*(.5+.5*sin(i*1.7))
		stems.append(Transform3D(Basis.IDENTITY.scaled_local(Vector3(.014,h,.014)),base+Vector3(0,h/2,0)))
		for j in 9:
			var a=j*2.399+i*.7
			var dir=Vector3(cos(a),.18+(j%3)*.12,sin(a)).normalized()
			leaves.append(Transform3D(Basis(Quaternion(Vector3.BACK,dir)).scaled_local(Vector3.ONE*(.33+j*.018)),base+Vector3(0,h*(.22+j*.075),0)))
		if flowers and i%2==0:
			for petal in 6:
				var a=petal*TAU/6
				blooms.append(Transform3D(Basis(Quaternion(Vector3.BACK,Vector3(cos(a),.22,sin(a)).normalized())).scaled_local(Vector3(.15,.15,.19)),base+Vector3(0,h+.035,0)))
	var leaf_batch=botany.foliage(leaves,root,"NewLeaves")
	leaf_batch.material_override=botany.leaves.duplicate();leaf_batch.material_override.set_shader_parameter("leaf_tint",Color("65954d"))
	if not blooms.is_empty():
		var petals=botany.foliage(blooms,root,"NewBlossoms")
		var mat=shapes.material(Color("f1d4a6"));mat.cull_mode=BaseMaterial3D.CULL_DISABLED;petals.material_override=mat
	var stem_mesh=CylinderMesh.new();stem_mesh.height=1;stem_mesh.top_radius=1;stem_mesh.bottom_radius=1;stem_mesh.radial_segments=6
	var batch=botany.foliage(stems,root,"NewStems",stem_mesh);batch.material_override=shapes.material(Color("596348"))
	growing.append({"node":root,"task":task})
func water_results():
	var route: Vector3=garden.nodes.landing+Vector3(0,0,1.13)
	for i in 3:
		stream(route+Vector3(-1.08+i*.8,.92,.18),route+Vector3(-.52+i*.8,.92,.18),.085,"water_route")
	bounce(route+Vector3(0,1.5,.6),"water_route",.48,3.5)
	garden.puzzle_world.face_console(groups.water_route,route,groups.water_route.get_children(),"W01InwardFacing")
	# A real open masonry cistern beside the filter: its surface rises to the lip.
	var p=Vector3(.1,2.35,-3.7)
	# The cistern is carried by masonry down into the tidal foundations.
	var masonry=shapes.weathered_material(Color("a9ad9e"))
	var footing=shapes.rounded_detail(Vector3(.1,.295,-3.7),Vector3(2.25,3.99,2.25),Color("899487"),.055)
	footing.name="CisternTidalFoundation";footing.material_override=masonry
	for side in [-1,1]:
		shapes.rounded_detail(p+Vector3(side*1.08,.48,0),Vector3(.18,1.1,2.25),Color("a9ad9e"),.045).material_override=masonry
		shapes.rounded_detail(p+Vector3(0,.48,side*1.08),Vector3(2.25,1.1,.18),Color("a9ad9e"),.045).material_override=masonry
	shapes.detail(p+Vector3(0,-.06,0),Vector3(2.25,.12,2.25),Color("6d776b"))
	var plane=PlaneMesh.new();plane.size=Vector2(2.04,2.04)
	reservoir=MeshInstance3D.new();reservoir.name="RisingCisternSurface";reservoir.mesh=plane;reservoir.material_override=flow_material
	groups.pressure.add_child(reservoir);reservoir.position=p+Vector3(0,.18,0)
	stream(Vector3(-1.7,3.48,-3.65),Vector3(-.7,3.48,-3.65),.17,"pressure")
	stream(Vector3(-.7,3.48,-3.65),Vector3(-.7,3.20,-3.65),.17,"pressure")
	bounce(Vector3(-2,4.0,-2.0),"pressure",.42,4)
	stream(Vector3(-3,5.23,-5.35),Vector3(-3,1.20,-4.05),.46,"pump")
	stream(Vector3(-3,1.20,-4.05),Vector3(1.5,1.20,1),.22,"pump")
	var a=Vector3(-3,1.07,-4.05);var b=Vector3(1.5,1.07,1);var d=(b-a).normalized()
	for side in [-1,0,1]:
		var kerb=shapes.rounded_detail((a+b)/2+Vector3(d.z,0,-d.x)*side*.24,Vector3(.46 if side==0 else .10,.13 if side==0 else .28,a.distance_to(b)),Color("8e9589"),.025)
		kerb.rotation.y=atan2(d.x,d.z);kerb.material_override=masonry
	for i in 5:
		var support=a.lerp(b,(i+.5)/5.0)
		shapes.rounded_detail(Vector3(support.x,-.25,support.z),Vector3(.38,2.64,.38),Color("8e9589"),.025).material_override=masonry
	foliage(Vector3(1.5,1.2,1),Vector2(4.4,2.8),42,"pump",true)
	bounce(Vector3(-3,5.9,-5.3),"pump",.65,6)
func sun_results():
	for x in [-7,-4,0,4,8]:
		sunbeam(Vector3(x,10.1,-2.5),Vector3(x+1,1.65,-1.8),.7,"power")
	for i in 4:
		var p=garden.nodes.sun+Vector3(-.95+i*.63,.65,-1.05)
		foliage(p,Vector2(.42,.4),5,"mirrors",i%2==0)
	sunbeam(garden.puzzle_world.visuals.mirrors1.position,garden.nodes.sun+Vector3(0,.65,-1.1),.34,"mirrors")
	bounce(garden.nodes.sun+Vector3(0,1.3,-.8),"mirrors",.7,4)
	for i in 7:
		var x=4.35+i*.52
		sunbeam(Vector3(x,10.6,-.75),Vector3(x-2.2,1.5,1.8),.55,"roof")
	foliage(Vector3(6,7.05,-.3),Vector2(3.0,2.7),42,"roof",true)
	bounce(Vector3(5.5,8.6,0),"roof",1.3,6)
func garden_results():
	for i in 3:
		var p: Vector3=garden.nodes[["west","east","north"][i]]
		foliage(p+Vector3(0,.24,0),Vector2(2.7,2.35),22,"planting",i==0)
		for j in 3:stream(p+Vector3(.85,1.0,-.85+j*.6),p+Vector3(.35,.32,-.8+j*.6),.065,"irrigation")
		foliage(p+Vector3(0,.28,0),Vector2(3.0,2.8),30,"irrigation",true)
	for p in [Vector3(-8.2,4.0,-2),Vector3(8.2,4.0,-2),Vector3(-8.2,4.0,3),Vector3(8.2,4.0,3)]:
		foliage(p,Vector2(2.7,3.0),26,"life",true)
	foliage(garden.nodes.summit+Vector3(0,.12,0),Vector2(2.7,2.0),38,"life",true)
	bounce(garden.nodes.summit+Vector3(0,1.5,0),"life",1.1,6)
func refresh():
	for task in groups:
		set_amount(task,amounts[task] if garden.repair_focus and garden.repair_focus.pending(task) else 1.0 if Puzzles.done(task) else 0.0)
func set_amount(task: String,value: float):
	if task not in groups:return
	var amount=clampf(value,0,1);amounts[task]=amount;groups[task].visible=amount>.001
	for plant in growing:
		if plant.task==task:plant.node.scale=Vector3(1,.10+.90*amount,1)
	for light in lights:
		if light.task==task:light.node.light_energy=light.energy*amount
	if task=="pressure" and reservoir:reservoir.position.y=2.53+.58*amount
	if task=="roof":
		for i in garden.shutter_panels.size():garden.shutter_panels[i].position.x=6+(-1 if i==0 else 1)*(1+2*amount)
	if garden.lighting:
		for fixture in garden.lighting.fixtures:
			if fixture.task==task:
				fixture.light.light_energy=fixture.energy*amount
				if "emission" in fixture:fixture.emission.emission_energy_multiplier=2.4*amount
