extends Node3D
# Practical lights are built with visible housings and never affect collision.
var garden: Node3D
var fixtures: Array=[]
func _init(g):garden=g;name="RuinsLighting"
func build():
	match Journey.chapter:
		0:
			lamp(Vector3(-7.5,5.05,4.25),Vector3(-6.7,3.0,5.3),Color("efd2a1"),1.6,6,"always")
			lamp(Vector3(-4.6,8.4,-7.9),Vector3(-3,5.25,-7),Color("ffcf8e"),2.6,7,"pump")
		1:
			for x in [-4,3]:lamp(Vector3(x,10.55,-2.4),Vector3(x+1,7.3,0),Color("f3dfae"),2.2,8,"power")
			seed_light(garden.nodes.sun+Vector3(0,.6,0),Color("ffd49a"),.7,"roof")
			# Light entering an existing broken roof bay illuminates the nursery
			# before power is repaired, distinct from the switched work lamps.
			var daylight=SpotLight3D.new();daylight.name="RoofGapDaylight";add_child(daylight)
			daylight.position=Vector3(9.6,12.2,4.6);daylight.look_at(Vector3(8.6,1.8,2.0))
			daylight.light_color=Color("ffdfa6");daylight.light_energy=2.8
			daylight.spot_range=14;daylight.spot_angle=24;daylight.spot_attenuation=.8
			daylight.shadow_enabled=true;daylight.shadow_bias=.035;daylight.shadow_normal_bias=.25
			daylight.light_size=.22;daylight.light_volumetric_fog_energy=1.5
		2:
			lamp(Vector3(-6,8.9,-.8),Vector3(-5,6.5,0),Color("d9dfbb"),1.6,6,"irrigation")
			lamp(Vector3(6,8.9,-.8),Vector3(5,6.5,0),Color("d9dfbb"),1.6,6,"irrigation")
			lamp(Vector3(0,11.15,-8.7),Vector3(0,9.2,-9.7),Color("f8d598"),2.4,6,"battery",false)
			seed_light(garden.nodes.summit+Vector3(0,.65,0),Color("efce8c"),.8,"life")
	if RenderingServer.get_current_rendering_method()=="forward_plus":
		var mist=FogVolume.new();mist.name="InteriorLightMist"
		mist.size=[Vector3(8,5,6),Vector3(16,7,11),Vector3(5,3.5,5)][Journey.chapter]
		mist.position=[Vector3(-3,6.9,-7.2),Vector3(0,8.5,1.5),Vector3(0,10,-10)][Journey.chapter]
		var fog=FogMaterial.new();fog.density=.014;fog.albedo=Color("bbb9a3");fog.edge_fade=.6
		mist.material=fog;add_child(mist)
	refresh()
func lamp(p: Vector3,target: Vector3,color: Color,energy: float,radius: float,task: String,shadow=true):
	var group=Node3D.new();group.name="WorkLamp";add_child(group);group.position=p
	var shapes=garden.s
	var housing=shapes.rounded_detail(Vector3.ZERO,Vector3(.43,.18,.33),Color("776047"),.028,group)
	housing.material_override=shapes.surface_pbr("rusty_metal_sheet",Color("b6ac96"),.7,.15)
	var glass=shapes.rounded_detail(Vector3(0,-.1,0),Vector3(.32,.065,.22),color,.016,group)
	var emissive=StandardMaterial3D.new();emissive.albedo_color=color;emissive.roughness=.32
	emissive.emission_enabled=true;emissive.emission=color;glass.material_override=emissive
	for x in [-.13,0,.13]:shapes.detail(Vector3(x,-.143,0),Vector3(.016,.018,.24),Color("514d3e"),group)
	shapes.detail(Vector3(0,.22,0),Vector3(.045,.42,.045),Color("625e49"),group)
	var light=SpotLight3D.new();light.name="PracticalSpot";group.add_child(light)
	light.position=Vector3(0,-.16,0);light.look_at(target)
	light.light_color=color;light.light_energy=energy;light.spot_range=radius
	light.spot_angle=46;light.spot_angle_attenuation=.7;light.spot_attenuation=1.25
	light.shadow_enabled=shadow;light.shadow_bias=.035;light.shadow_normal_bias=.35
	light.light_size=.12;light.light_volumetric_fog_energy=1.2
	fixtures.append({"light":light,"emission":emissive,"energy":energy,"task":task})
func seed_light(p: Vector3,color: Color,energy: float,task: String):
	var light=OmniLight3D.new();light.name="SeedBounce";add_child(light);light.position=p
	light.light_color=color;light.omni_range=2.4;light.omni_attenuation=1.5
	light.light_volumetric_fog_energy=.25
	fixtures.append({"light":light,"energy":energy,"task":task})
func refresh():
	for fixture in fixtures:
		var task=fixture.task
		var powered=task=="always" or Puzzles.data.battery if task=="battery" else task=="always" or Puzzles.done(task)
		fixture.light.light_energy=fixture.energy if powered else 0.0
		if "emission" in fixture:fixture.emission.emission_energy_multiplier=2.4 if powered else 0.0
