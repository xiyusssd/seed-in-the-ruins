extends Node3D
# Original decorative equipment. No collision, screen-space effects or extra shadows.
var garden: Node3D
var shapes: RefCounted
var indicators: Dictionary = {}
var work_lights: Array[OmniLight3D] = []
var level_water: MeshInstance3D
var irrigation_streams: Array[MeshInstance3D] = []
var relay_halo: MeshInstance3D
var seed_halo: MeshInstance3D
var relay_label: Label3D
var wet_surfaces: Array[MeshInstance3D] = []
func _init(g):
	garden=g
	shapes=load("res://scripts/garden_shapes.gd").new(self)
func label(p: Vector3,text: String,size = 16) -> Label3D:
	var node=Label3D.new();node.font=load("res://assets/telemetry_font.tres")
	node.text=text;node.font_size=size;node.pixel_size=.006
	node.modulate=Color("eee1bf");node.outline_modulate=Color("30392f");node.outline_size=2
	add_child(node);node.position=p
	return node
func tube(a: Vector3,b: Vector3,radius: float,color: Color) -> MeshInstance3D:
	var mesh=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=a.distance_to(b);mesh.radial_segments=16
	var node=MeshInstance3D.new();node.mesh=mesh;node.material_override=shapes.material(color)
	add_child(node);node.position=(a+b)/2
	if a.distance_to(b)>.001:node.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	return node
func workbench(p: Vector3,task: String,width: float,code: String):
	for side in [-1,1]:
		shapes.rust_rod(p+Vector3(side*(width/2+.12),.12,-.24),p+Vector3(side*(width/2+.12),2.02,-.24),.028,self)
	shapes.rust_rod(p+Vector3(-width/2-.12,2.02,-.24),p+Vector3(width/2+.12,2.02,-.24),.025,self)
	var housing=shapes.rounded_detail(p+Vector3(0,1.96,-.24),Vector3(width*.65,.10,.16),Color("6b7461"),.025,self)
	var diffuser=shapes.rounded_detail(p+Vector3(0,1.9,-.15),Vector3(width*.6,.032,.08),Color("e4d5ab"),.012,self)
	diffuser.material_override=shapes.material(Color("e4d5ab"),true)
	var light=OmniLight3D.new();light.position=p+Vector3(0,1.9,.52)
	light.light_color=Color("f1ddb2");light.light_energy=.38;light.omni_range=4.5;light.shadow_enabled=false
	add_child(light);work_lights.append(light)
	var lamp=shapes.rounded_detail(p+Vector3(width/2-.13,1.27,.095),Vector3(.12,.07,.024),Color("b59965"),.015,self)
	lamp.material_override=shapes.material(Color("b59965"),true)
	shapes.rounded_detail(p+Vector3(0,2.20,-.24),Vector3(width*.65,.20,.06),Color("363e32"),.018,self)
	indicators[task]=[lamp,label(p+Vector3(0,2.20,-.19),code+" ○",14),code]
	# Physical cable clamps and backing ribs, beyond the existing controller silhouette.
	for side in [-1,1]:
		for y in [.27,.47]:
			shapes.rounded_detail(p+Vector3(side*width*.46,y,-.32),Vector3(.12,.055,.17),Color("514c3b"),.013,self)
func puddle(p: Vector3,size: Vector2):
	var mesh=PlaneMesh.new();mesh.size=size
	var node=MeshInstance3D.new();node.mesh=mesh;node.position=p
	var material=StandardMaterial3D.new();material.albedo_color=Color("4f5b49");material.roughness=.19;material.metallic=.08
	node.material_override=material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node);wet_surfaces.append(node)
func halo(p: Vector3) -> MeshInstance3D:
	var mesh=TorusMesh.new();mesh.inner_radius=.16;mesh.outer_radius=.19;mesh.rings=24;mesh.ring_segments=8
	var node=MeshInstance3D.new();node.mesh=mesh;node.position=p
	node.material_override=shapes.material(Color("d6ba7d"),true)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
	return node
func build():
	name="WorksiteDetails"
	match Journey.chapter:
		0:
			var route: Vector3=garden.nodes.landing+Vector3(0,0,1.13)
			var pressure_frame=garden.puzzle_world.get_node("W02InwardFacing")
			var pressure: Vector3=pressure_frame.position
			workbench(route,"water_route",2.65,"W-01")
			garden.puzzle_world.face_console(self,route,get_children(),"W01InwardFacing")
			var pressure_parts=get_children()
			workbench(pressure,"pressure",1.9,"W-02")
			var base=pressure+Vector3(.88,.25,.09)
			tube(base,base+Vector3(0,.78,0),.055,Color(.63,.68,.56,.18))
			level_water=tube(base,base+Vector3(0,.78,0),.032,Color("86a494"))
			for i in 7:shapes.detail(base+Vector3(-.07,i*.13,.005),Vector3(.07,.012,.012),Color("dfd4b9"),self)
			garden.puzzle_world.face_console(self,pressure,get_children().filter(func(n):return n not in pressure_parts),"W02InwardFacing",pressure_frame.rotation.y)
			for offset in [Vector3(-.95,.026,-.55),Vector3(.84,.026,.35)]:puddle(garden.nodes.altar+offset,Vector2(.6,.38))
		1:
			workbench(garden.nodes.landing+Vector3(0,0,1.2),"power",2.65,"S-01")
			garden.puzzle_world.face_console(self,garden.nodes.landing+Vector3(0,0,1.2),get_children(),"S01InwardFacing")
			relay_halo=halo(garden.puzzle_world.relay_position+Vector3(-.055,0,0));relay_halo.rotation.z=PI/2
			relay_label=label(garden.puzzle_world.relay_position+Vector3(0,-.37,0),"○",15)
			relay_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
			seed_halo=halo(garden.nodes.sun+Vector3(0,.53,0))
			var light=OmniLight3D.new();light.position=garden.nodes.sun+Vector3(0,1.25,0)
			light.light_color=Color("f2d49b");light.omni_range=3;light.light_energy=.0;add_child(light);work_lights.append(light)
			for i in 4:shapes.rounded_detail(garden.nodes.sun+Vector3(-.9+i*.6,.64,-1.01),Vector3(.38,.045,.25),Color("746d54"),.018,self)
		2:
			var roots: Vector3=garden.nodes.summit+Vector3(1.55,0,0)
			workbench(roots,"life",2.65,"L-03")
			garden.puzzle_world.face_console(self,roots,get_children(),"RootsInwardFacing",-PI/2)
			for i in 3:
				var base: Vector3=garden.nodes[["west","east","north"][i]]
				var a=base+Vector3(.65,.35,.8);var b=base+Vector3(.52,.18,.05)
				var stream=tube(a,b,.018,Color("86a494"));irrigation_streams.append(stream)
				shapes.rust_rod(a+Vector3(.045,0,0),b+Vector3(.045,0,0),.032,self)
	refresh()
func refresh():
	for task in indicators:
		var entry=indicators[task]
		var done=Puzzles.done(task)
		entry[0].material_override.albedo_color=Color("a8b896") if done else Color("b59965")
		entry[0].material_override.emission=entry[0].material_override.albedo_color
		entry[1].text=entry[2]+(" ✓" if done else " ○")
	if level_water:
		var amount=clampf(float(Puzzles.data.valves[0]*2-Puzzles.data.valves[1])/6.0,0,1) if Puzzles.done("water_route") else 0.0
		level_water.visible=amount>0
		level_water.scale.y=maxf(.01,amount)
		level_water.position.y=.25+.78*amount/2
	for surface in wet_surfaces:surface.visible=Puzzles.done("pump")
	if relay_halo:
		var relay_on=Puzzles.done("power") and Puzzles.data.mirrors[0]==1
		relay_halo.visible=relay_on;seed_halo.visible=Puzzles.done("mirrors")
		relay_label.text="●" if relay_on else "○"
		work_lights[-1].light_energy=.48 if Puzzles.done("mirrors") else 0
	for i in irrigation_streams.size():irrigation_streams[i].visible=Puzzles.data.irrigation[i]>0 and Puzzles.done("planting")
