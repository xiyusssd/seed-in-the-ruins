extends Node3D
const ChapterScenery = preload("res://scripts/chapter_scenery.gd")
const CoastalScenery = preload("res://scripts/coastal_scenery.gd")
const Shapes = preload("res://scripts/garden_shapes.gd")
const GardenUI = preload("res://scripts/garden_ui.gd")
const TITLES = ["旧城泵站", "日光温室", "回生花园"]
const PARTNER_LINES={"water_route":"芽芽：水会记住你接上的这段路。","pressure":"芽芽：指针稳住了，我去守住踏板。","pump":"芽芽：听，第一滴水。","power":"芽芽：旧灯亮了，叶子在等日光。","mirrors":"芽芽：它终于不用踮着脚找太阳了。","roof":"芽芽：清晨到了。","planting":"芽芽：它们不一样，正好可以一起生活。","irrigation":"芽芽：每一株都接到了自己的水。","life":"芽芽：下一次春天，会从这里出发。"}
const SUBTITLES = ["水不用赶路，春天也是", "借一束阳光，照顾一片叶子", "不一样的叶子，也能一起过冬"]
const COLORS = [Color("956d50"), Color("787866"), Color("71816a")]
var geometry: Node3D
var s: RefCounted
var avatar: Node3D
var camera: Camera3D
var ui: CanvasLayer
var environment: Environment
var nodes: Dictionary = {}
var edges: Array = []
var pickables: Array[Node3D] = []
var waypoints: Dictionary = {}
var rotor: Node3D
var elevator: Node3D
var shutter_root: Node3D
var shutter_panels: Array = []
var flow_root: Node3D
var living_root: Node3D
var seed_root: Node3D
var lotus: Node3D
var glints: Array = []
var recovery_plants: Array[Node3D] = []
var water_mesh: MeshInstance3D
var audio: Array[AudioStreamPlayer] = []
var lamps: Array[MeshInstance3D] = []
var old_shell: Node3D
var angle = 0.75
var inclination = 0.32
var distance = 26.0
var focus = Vector3(0, 4.2, 0)
var busy = false
var playing = false
var rotation_drag = false
var hovered: Node3D
var time = 0.0
var save_clock = 0.0
var moving = false
var capture = false
var dynamic_audio: AudioStreamPlayer
var follow_view = false
var follow_distance = 12.0
var follow_focus = Vector3.ZERO
var walker: CharacterBody3D
var first_person = true
var recovery = 0.0
var colour_material: ShaderMaterial
var colour_tween: Tween
var sky_material
var benchmark_runner: RefCounted
var puzzle_world: Node3D
var companion: Node3D
var soundscape: Node
var wind_field: Node3D
var lighting: Node3D
var tutorial: Node
var repair_focus: Node
var restoration: Node3D


func _ready():
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 76.0
	camera.near = 0.1
	camera.far = 180
	add_child(camera)
	camera.current = true
	if not Settings.verification():
		var wanted = "gl_compatibility" if Settings.quality == "compatible" else "forward_plus"
		if RenderingServer.get_current_rendering_method() != wanted:
			Settings.restart_with_quality(Settings.quality)
			return
	Puzzles.updated.connect(on_puzzle_update)
	Puzzles.solved.connect(on_puzzle_solved)
	build_environment()
	build_colour_recovery()
	Journey.changed.connect(on_clue_change)
	build_chapter()
	ui = CanvasLayer.new()
	ui.set_script(GardenUI)
	ui.garden = self
	add_child(ui)
	tutorial=load("res://scripts/pump_tutorial.gd").new(self);add_child(tutorial)
	build_audio()
	ui.title_screen()
	if not Settings.verification() and not Settings.story_seen:
		ui.prologue_screen(0,"arrival")
	if Settings.verification():get_viewport().gui_disable_input=true
	if not DisplayServer.get_name()=="headless" and Settings.verification() and "--offscreen-capture" not in OS.get_cmdline_user_args(): get_window().grab_focus()
	if "--garden-capture" in OS.get_cmdline_user_args():
		get_viewport().gui_disable_input=true
		Engine.max_fps = 24
		capture = true
		capture_chapters.call_deferred()
	elif "--garden-film" in OS.get_cmdline_user_args():
		Engine.max_fps = 24
		capture = true
		film.call_deferred()
	elif "--performance-test" in OS.get_cmdline_user_args():
		capture = true
		benchmark_runner = load("res://scripts/render_benchmark.gd").new(self)
		benchmark_runner.run.call_deferred()
	elif "--verify-build" in OS.get_cmdline_user_args():
		await get_tree().create_timer(3).timeout
		print("SPATIAL_BUILD_OK: 3D scene, menus, font and ambience loaded")
		await quit_game()

func build_environment():
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	sky_material = ShaderMaterial.new()
	sky_material.shader = preload("res://shaders/coastal_morning.gdshader")
	sky_material.set_shader_parameter("panorama", preload("res://assets/scenery/coastal_daylight.hdr"))
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_color = Color("b5ac91")
	environment.fog_enabled = true
	environment.fog_light_color = Color("a6b6c0")
	environment.fog_density = 0.009
	environment.fog_sky_affect = 0.2
	environment.fog_light_energy = 0.6
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = .65
	environment.ambient_light_color = Color("a9bbc8")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES if RenderingServer.get_current_rendering_method() == "forward_plus" else Environment.TONE_MAPPER_LINEAR
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		environment.ssao_enabled = true
		environment.ssao_radius = .55
		environment.ssao_intensity = .85
		environment.ssil_enabled = true
		environment.ssil_radius = 2.0
		environment.ssil_intensity = .65
		# The water comparison exposed distant SSR bright-pixel artifacts.
		# Sky/probe reflections remain active without that screen-space pass.
		environment.ssr_enabled = false
		environment.glow_enabled = true
		environment.glow_intensity = .4
		environment.glow_bloom = 0.0
		environment.glow_hdr_threshold=1.6
		environment.volumetric_fog_enabled=true
		environment.volumetric_fog_density=.0022
		environment.volumetric_fog_ambient_inject=.15
		environment.volumetric_fog_anisotropy=.45
		environment.volumetric_fog_length=45
		environment.volumetric_fog_sky_affect=0.0
		environment.fog_height = -1.0
		environment.fog_height_density = 0.04
	var world_env = WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)
	var light = DirectionalLight3D.new()
	light.name="CoastalSun"
	light.rotation_degrees = Vector3(-16, 148, 0)
	light.light_color = Color("ffdab0")
	light.light_energy = 1.06
	light.light_angular_distance=1.8
	light.light_volumetric_fog_energy=.55
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 75
	light.shadow_bias = 0.035
	light.shadow_normal_bias = 0.28
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(light)
	if sky_material is ShaderMaterial:sky_material.set_shader_parameter("sun_direction", light.transform.basis.z)

func build_chapter():
	if repair_focus:repair_focus.cancel()
	restoration=null
	busy = false
	moving = false
	if geometry:
		remove_child(geometry)
		geometry.queue_free()
	geometry = Node3D.new()
	add_child(geometry)
	s = Shapes.new(geometry)
	nodes.clear()
	edges.clear()
	pickables.clear()
	waypoints.clear()
	lamps.clear()
	glints.clear()
	recovery_plants.clear()
	wind_field=null
	lighting=null
	shutter_panels.clear()
	focus = Vector3(0, 4.2, 0)
	angle = 0.75
	distance = 26.0
	inclination = 0.32
	build_water_plane()
	build_horizon()
	flow_root = Node3D.new()
	geometry.add_child(flow_root)
	living_root = Node3D.new()
	geometry.add_child(living_root)
	seed_root = Node3D.new()
	geometry.add_child(seed_root)
	match Journey.chapter:
		0: water_garden()
		1: sun_garden()
		2: life_garden()
	var scenery = ChapterScenery.new(s, geometry)
	match Journey.chapter:
		0: scenery.pump_station()
		1: scenery.greenhouse()
		2: scenery.regrowth_garden()
	puzzle_world = load("res://scripts/puzzle_world.gd").new(self)
	geometry.add_child(puzzle_world)
	puzzle_world.build()
	companion = load("res://characters/yaya.tscn").instantiate()
	companion.garden = self
	geometry.add_child(companion)
	companion.position = nodes.arrival+Vector3(-0.55,0.055,0.35)
	var robot_saved: Array = Puzzles.data.robot_position
	if robot_saved.size() == 3:
		var saved = Vector3(robot_saved[0],robot_saved[1],robot_saved[2])
		if not is_inf(floor_at(saved)): companion.position = saved
	var probe = ReflectionProbe.new()
	probe.name = "CoastalReflectionCapture"
	probe.position = Vector3(-6,5,-14)
	probe.size = Vector3(180,90,200)
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.max_distance = 180.0
	probe.intensity = .85
	probe.cull_mask = 1
	probe.reflection_mask = 3
	probe.enable_shadows = true
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	probe.box_projection = false
	geometry.add_child(probe)
	build_abandoned_details()
	geometry.add_child(load("res://scripts/ruins_fabric.gd").new(self))
	load("res://scripts/cinematic_ruins.gd").new(self).build()
	build_air_and_foliage()
	lighting=load("res://scripts/ruins_lighting.gd").new(self);geometry.add_child(lighting);lighting.build()
	if Journey.chapter==1:
		var interior_probe=ReflectionProbe.new();interior_probe.name="GreenhouseReflectionCapture"
		interior_probe.position=Vector3(.5,7,1.8);interior_probe.size=Vector3(23,13,14)
		interior_probe.max_distance=32;interior_probe.box_projection=true
		interior_probe.intensity=.65;interior_probe.cull_mask=1;interior_probe.reflection_mask=1
		interior_probe.enable_shadows=true;interior_probe.ambient_mode=ReflectionProbe.AMBIENT_DISABLED
		geometry.add_child(interior_probe)
	for decoration in [flow_root, living_root]:
		for collider in decoration.find_children("*", "StaticBody3D", true, false):
			collider.collision_layer = 0
			collider.collision_mask = 0
	avatar = s.traveler()
	for collider in avatar.find_children("*", "StaticBody3D", true, false):
		collider.collision_layer = 0
		collider.collision_mask = 0
	if walker:
		remove_child(walker)
		walker.queue_free()
	walker = CharacterBody3D.new()
	walker.set_script(load("res://scripts/ruins_walker.gd"))
	walker.garden = self
	add_child(walker)
	if Journey.node_id not in nodes:
		Journey.node_id = "arrival"
	if Journey.chapter == 1 and Journey.node_id == "lift_low" and Journey.lift:
		Journey.node_id = "lift_high"
	if Journey.chapter == 1 and Journey.node_id == "lift_high" and not Journey.lift:
		Journey.node_id = "lift_low"
	avatar.position = nodes[Journey.node_id] + Vector3(0, 0.04, 0)
	if Journey.fps_valid and not is_inf(floor_at(Journey.fps_position)):
		avatar.position = Journey.fps_position
	walker.position = avatar.position
	walker.yaw = Journey.fps_yaw if Journey.fps_valid else (-PI / 2 if Journey.chapter < 2 else 0.0)
	walker.pitch = Journey.fps_pitch if Journey.fps_valid else -0.15
	follow_focus = avatar.position + Vector3(0, 1.1, 0)
	avatar.visible = not first_person
	if not repair_focus:
		repair_focus=load("res://scripts/repair_focus.gd").new(self);add_child(repair_focus)
	restoration=load("res://scripts/restoration_effects.gd").new(self);geometry.add_child(restoration);restoration.build()
	refresh()
	set_recovery(recovery)
	update_camera()
	if soundscape: soundscape.chapter(Journey.chapter)
	if tutorial:tutorial.configure()

func build_water_plane():
	var surface = PlaneMesh.new()
	surface.size = Vector2(140, 140)
	surface.subdivide_width = 128
	surface.subdivide_depth = 128
	water_mesh = MeshInstance3D.new()
	water_mesh.mesh = surface
	# The main camera sees layer 2; the coastal probe captures layer 1 only.
	# Excluding the moving sea prevents a recursive dark ocean in its cubemap.
	water_mesh.layers = 2
	# The moving surface receives shore shadows but cannot shadow itself.
	water_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water_mesh.position.y = -1.3
	geometry.add_child(water_mesh)
	var material = ShaderMaterial.new()
	material.shader = load("res://shaders/ruins_water.gdshader")
	material.set_shader_parameter("chapter", float(Journey.chapter))
	water_mesh.material_override = material
	# A surrounding ocean ring has no geometry under the near waves.
	# The shared boundary matches the near plane's 129 segments exactly.
	var far_mesh=MeshInstance3D.new();far_mesh.name="DistantOceanRing";far_mesh.layers=2
	var surface_tool=SurfaceTool.new();surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in 4:
		for i in 129:
			var points=[];var uvs=[]
			for step in [i,i+1]:
				var t=float(step)/129
				for extent in [70.,800.]:
					var p=Vector3(lerpf(-extent,extent,t),0,extent)
					p=Basis(Vector3.UP,side*PI/2)*p
					points.append(p);uvs.append(Vector2(p.x/140+.5,p.z/140+.5))
			s.add_face(surface_tool,[points[0],points[1],points[3],points[2]],Vector3.UP,[uvs[0],uvs[1],uvs[3],uvs[2]])
	surface_tool.generate_tangents()
	far_mesh.mesh=surface_tool.commit();far_mesh.position.y=-1.3
	far_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	far_mesh.material_override=material;geometry.add_child(far_mesh)

func build_horizon():
	var coast=CoastalScenery.new(s,geometry)
	coast.build()
	for p in [Vector3(-3,-.8,-7),Vector3(6,-.9,0),Vector3(0,-.9,-10)]:
		if (Journey.chapter==0 and p.x==-3) or (Journey.chapter==1 and p.x==6) or (Journey.chapter==2 and p.x==0):
			s.column(p,3.4,1.4,Shapes.STONE,null,2.6)
			s.column(p+Vector3(0,.65,0),2.65,.6,Shapes.STONE,null,2.35)

func build_abandoned_details():
	# Original abandoned machinery sits beside the route, never on the walking floor.
	var rust = Color("a97855")
	var paint = Color("c8b384")
	for i in 3:
		var anchor = nodes.arrival + Vector3(1.9 if Journey.chapter == 2 else 0, -0.3, 1.9 if Journey.chapter < 2 else 0)
		anchor += Vector3(i * 1.05, -0.1 * i, 0.5 * i)
		var machine = Node3D.new()
		geometry.add_child(machine)
		machine.position = anchor
		machine.rotation.y = 0.2 + i * 0.7
		s.detail(anchor + Vector3(0,-0.18,0), Vector3(1.2,0.22,1.2), Shapes.STONE)
		var foundation_height = anchor.y + 1.2
		s.detail(Vector3(anchor.x, anchor.y - foundation_height / 2 - 0.25, anchor.z), Vector3(0.42, foundation_height, 0.42), rust)
		var planter = s.plant(anchor + Vector3(-0.4, 0.84, 0.15), 0.45, 1)
		planter.set_meta("growth_scale",0.45)
		recovery_plants.append(planter)
		for collider in planter.find_children("*", "StaticBody3D", true, false):
			collider.collision_layer = 0
			collider.collision_mask = 0
		s.detail(Vector3(0, 0.42, 0), Vector3(0.82, 0.84, 0.65), paint.darkened(i * 0.08), machine)
		s.detail(Vector3(0, 0.66, 0.34), Vector3(0.64, 0.29, 0.035), Shapes.INK, machine)
		for j in 5:
			s.detail(Vector3(-0.25 + j * 0.12, 0.3, 0.35), Vector3(0.045, 0.24, 0.045), rust, machine)
		s.detail(Vector3(0.46, 0.2, 0), Vector3(0.11, 0.18, 0.78), rust, machine)
		s.detail(Vector3(-0.46, 0.2, 0), Vector3(0.11, 0.18, 0.78), rust, machine)
		for j in 4:
			var chip = s.detail(Vector3(-0.32 + j * 0.19, 0.84, 0), Vector3(0.08, 0.015, 0.6), rust, machine)
			chip.rotation.y = j * 0.13

func build_air_and_foliage():
	wind_field=load("res://scripts/wasteland_wind.gd").new()
	wind_field.garden=self
	geometry.add_child(wind_field)

func point(id: String, p: Vector3):
	nodes[id] = p
	var marker = s.ring(p + Vector3(0, 0.035, 0), 0.3, 0.05, Shapes.GOLD)
	waypoints[id] = marker
	for collider in marker.find_children("*","StaticBody3D",true,false):
		collider.collision_layer = 0
	pick(p + Vector3(0, 0.12, 0), Vector3(1.5, 0.6, 1.5), "walk", id, "走到这里")

func connect_path(a: String, b: String, requirement = ""):
	edges.append([a, b, requirement])

func pick(p: Vector3, size: Vector3, action: String, id: String, text: String):
	var body = StaticBody3D.new()
	body.set_meta("action", action)
	body.set_meta("id", id)
	body.set_meta("text", text)
	geometry.add_child(body)
	body.position = p
	body.collision_layer = 2
	body.collision_mask = 0
	var shape = BoxShape3D.new()
	shape.size = size
	var collision = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	pickables.append(body)
	return body

func handle(p: Vector3, action: String, id = "", text = "转动轮柄，让长桥转身"):
	s.column(p + Vector3(0, 0.32, 0), 0.12, 0.65, Shapes.GOLD)
	var ring = s.ring(p + Vector3(0, 0.68, 0), 0.42, 0.09, COLORS[Journey.chapter])
	ring.rotation.x = PI / 2
	s.sphere(p + Vector3(0, 0.68, 0), 0.12, Shapes.GOLD)
	pick(p + Vector3(0, 0.6, 0), Vector3(0.65, 1.05, 0.65), action, id, text)

func rotary_bridge(p: Vector3, length: float):
	rotor = Node3D.new()
	geometry.add_child(rotor)
	rotor.position = p
	s.bridge(Vector3(-length / 2, 0, 0), Vector3(length / 2, 0, 0), 1.45, rotor, COLORS[Journey.chapter])
	s.column(Vector3(0, -0.5, 0), 0.8, 1, Shapes.STONE, rotor)
	s.column(Vector3(0, -p.y / 2 - 0.4, 0), 0.3, p.y, Shapes.STONE, rotor)
	s.ring(Vector3(0, 0.04, 0), 0.55, 0.1, Shapes.GOLD, rotor)

func water_garden():
	point("arrival", Vector3(-7, 2.8, 5))
	point("landing", Vector3(-3, 2.8, 5))
	point("spring", Vector3(-3, 2.8, -3))
	point("altar", Vector3(-3, 5, -7))
	point("stair_top", Vector3(-3,5,-4.65))
	s.deck(nodes.arrival, 3.4, 3.4)
	s.arch(nodes.arrival + Vector3(-0.3, 0, -0.85), 1.5, 2.4, Shapes.CORAL)
	s.bridge(nodes.arrival, nodes.landing, 1.5, null, Shapes.CORAL)
	s.deck(nodes.landing, 2.8, 2.8)
	# The first mechanism is a real eight-metre bridge, not a projected connection.
	rotary_bridge(Vector3(-3, 2.8, 1), 8)
	s.deck(nodes.spring, 3, 2.7)
	s.stairs(nodes.spring, nodes.stair_top, 1.7)
	s.bridge(nodes.stair_top,nodes.altar,1.7)
	s.deck(nodes.altar, 4.2, 4.2)
	s.column(Vector3(-3, 1.1, -7), 2.15, 6.6, Shapes.STONE)
	# Channel bowl and visible cascading water.
	s.column(nodes.altar + Vector3(0, 0.12, 0), 0.75, 0.24, Shapes.STONE)
	s.column(nodes.altar + Vector3(0, 0.26, 0), 0.64, 0.025, Shapes.TEAL, flow_root)
	s.block(Vector3(-3, 4.93, -5.3), Vector3(0.5, 0.08, 2.5), Shapes.TEAL, flow_root)
	s.block(Vector3(-3, 3.3, -4.05), Vector3(0.47, 3.2, 0.055), Color("93c9c5"), flow_root)
	s.deck(Vector3(1.5, 1, 1), 5.5, 4)
	s.column(Vector3(1.5, 1.06, 1), 1.7, 0.14, Shapes.TEAL, flow_root)
	for i in 7:
		s.plant(Vector3(0.4 + i * 0.38, 1.16, 0.3 + (i % 2) * 1.2), 0.65, i % 3, living_root)
	handle(nodes.landing + Vector3(0.75, 0, -0.7), "bridge")
	handle(nodes.altar + Vector3(1.15, 0, 0.85), "water", "", "打开水闸，送水回家")
	connect_path("arrival", "landing")
	connect_path("landing", "spring", "z_bridge")
	connect_path("spring", "stair_top")
	connect_path("stair_top", "altar")
	memory_stone("arrival", 0, Vector3(-0.7, 0, -0.6))
	# Keep the result stone clear of the inward-facing W-01 interaction rays.
	memory_stone("landing", 1, Vector3(-0.95, 0, -0.65))
	memory_stone("spring", 2, Vector3(-0.7, 0, 0.5))
	memory_stone("altar", 3, Vector3(-0.8, 0, 0))
	make_seed(nodes.altar + Vector3(0, 0.3, 0), false)

func sun_garden():
	point("arrival", Vector3(-7, 3, 5))
	point("landing", Vector3(-2, 3, 5))
	point("lift_low", Vector3(-2, 3, 0))
	point("lift_high", Vector3(-2, 7, 0))
	point("sun", Vector3(6, 7, 0))
	s.deck(nodes.arrival, 3.4, 3.4, Shapes.PURPLE)
	s.arch(nodes.arrival + Vector3(0, 0, -0.85), 1.6, 2.5, Shapes.PURPLE)
	s.deck(nodes.landing, 3, 3)
	s.bridge(nodes.arrival, nodes.landing, 1.5, null, Shapes.PURPLE)
	s.bridge(nodes.landing, nodes.lift_low, 1.5, null, Shapes.PURPLE)
	# Lift cage stays open so the traveler remains visible while moving vertically.
	for x in [-3.2, -0.8]:
		for z in [-1.1, 1.1]:
			s.column(Vector3(x, 4.3, z), 0.1, 9, Shapes.GOLD)
	s.arch(Vector3(-2, 7, 0.95), 2, 2.8, Shapes.PURPLE)
	elevator = Node3D.new()
	geometry.add_child(elevator)
	elevator.position = nodes.lift_low
	s.block(Vector3(0, -0.15, 0), Vector3(2.4, 0.3, 2.4), Shapes.IVORY, elevator)
	s.ring(Vector3(0, 0.015, 0), 0.78, 0.045, Shapes.GOLD, elevator)
	rotary_bridge(Vector3(2, 7, 0), 8)
	s.deck(nodes.sun, 4, 4, Shapes.PURPLE)
	s.column(Vector3(6, 3.25, 0), 1.7, 7, Shapes.STONE)
	# Repaired industrial frames carry the opening roof.
	for x in [4.1, 7.9]:
		s.arch(Vector3(x, 7, 0), 3, 3.5, Shapes.IVORY, PI / 2)
	s.arch(Vector3(6, 7, -1.8), 3.4, 3.5, Shapes.IVORY)
	shutter_root = Node3D.new()
	geometry.add_child(shutter_root)
	for side in [-1, 1]:
		var panel = s.block(Vector3(6 + side, 10.5, 0), Vector3(1.9, 0.18, 4.4), Shapes.PURPLE, shutter_root)
		shutter_panels.append(panel)
	# A corroded roof vent replaces the ornamental floating sun.
	s.rust_rod(Vector3(4.1,11.7,0),Vector3(7.9,11.7,0),.06)
	s.rust_rod(Vector3(6,11.7,0),Vector3(6,11.22,0),.035)
	var vent=s.ring(Vector3(6,11.2,0),.62,.055,Shapes.GOLD)
	vent.material_override=s.weathered_material(Color("765540"),true)
	for blade_id in 4:
		var a=blade_id*PI/2
		var blade=s.detail(Vector3(6+sin(a)*.28,11.2,cos(a)*.28),Vector3(.17,.04,.52),Shapes.PURPLE)
		blade.rotation.y=a
	for i in 3:
		var pos = Vector3(-6 + i * 1.4, 4.5 + i * 1.1, -4)
		s.column(Vector3(pos.x,(pos.y+1.35)/2,pos.z),.065,pos.y-1.35,Shapes.STONE)
		var lamp = s.sphere(pos, 0.12, Shapes.GOLD)
		lamp.material_override = s.material(Shapes.GOLD, true)
		lamps.append(lamp)
		var shade=s.column(pos+Vector3(0,.20,0),.26,.09,Shapes.CORAL)
		shade.material_override=s.surface_pbr("rusty_metal_sheet",Color("b29b75"),.55,.12)
		for cage_side in 4:
			var a=cage_side*PI/2;var offset=Vector3(cos(a)*.20,0,sin(a)*.20)
			s.rust_rod(pos+offset+Vector3(0,-.18,0),pos+offset+Vector3(0,.18,0),.012)
		s.ring(pos+Vector3(0,-.19,0),.20,.018,Shapes.STONE)
	for i in 9:
		s.plant(nodes.sun + Vector3(-1.3 + (i % 3) * 1.25, 0.03, -1.2 + (i / 3) * 1.15), 0.7, i % 3, living_root)
	# Sunlight is shaded through the opening and local mist, rather than a yellow cylinder.
	handle(nodes.lift_low + Vector3(0.7, 0, 0.3), "lift", "", "升起日光台，去高处看看")
	# The upper handle permits returning; the lower handle is useful from arrival.
	handle(nodes.lift_high + Vector3(-0.7, 0, 0), "lift", "", "升起日光台，去高处看看")
	handle(nodes.lift_high + Vector3(0.65, 0, 0.5), "bridge")
	handle(nodes.sun + Vector3(1.25, 0, 0.8), "shutters", "", "打开屋顶，借一束阳光")
	connect_path("arrival", "landing")
	connect_path("landing", "lift_low", "lift_down")
	connect_path("lift_high", "sun", "x_bridge_lift")
	memory_stone("arrival", 4, Vector3(-0.65, 0, -0.8))
	memory_stone("landing", 5, Vector3(-0.95, 0, -0.65))
	memory_stone("lift_high", 6, Vector3(-0.6, 0, -0.65))
	memory_stone("sun", 7, Vector3(1.1, 0, -1.2))
	make_seed(nodes.sun + Vector3(0, 0.15, 0), false)

func planting_position(index: int) -> Vector3:
	# Tall deep-root leaves stay behind the operator and clear of the tower stairs.
	return nodes[["west","east","north"][index]]+(Vector3(.8,0,-.85) if index==2 else Vector3.ZERO)

func life_garden():
	point("arrival", Vector3(0, 2.5, 10))
	point("landing", Vector3(0, 6, 5))
	point("entry_step", Vector3(0,6,6.3))
	point("center", Vector3(0, 6, 0))
	point("west", Vector3(-5, 6, 0))
	point("east", Vector3(5, 6, 0))
	point("north", Vector3(0, 6, -5))
	point("summit", Vector3(0, 8.5, -10))
	point("summit_step", Vector3(0,8.5,-7.55))
	focus = Vector3(0, 5, 0)
	distance = 29
	s.deck(nodes.arrival, 3.4, 3.4)
	s.arch(nodes.arrival + Vector3(0, 0, 0.85), 1.6, 2.5, Shapes.TEAL)
	s.stairs(nodes.arrival, nodes.entry_step, 1.7)
	s.bridge(nodes.entry_step,nodes.landing,1.7)
	s.deck(nodes.landing, 2.8, 2.2)
	rotary_bridge(nodes.center, 10)
	s.column(Vector3(0, 2.5, 0), 1.25, 7, Shapes.STONE)
	s.column(nodes.center + Vector3(0, -0.1, 0), 0.85, 0.2, Shapes.IVORY)
	for key in ["west", "east", "north"]:
		s.deck(nodes[key], 3.3, 3.3)
		s.pavilion(nodes[key], 2.3, Shapes.TEAL if key == "north" else Shapes.CORAL, false)
		if key == "north":
			# The stair exit is an open ruin: no overhead arch intersects the ascending player's head.
			for piece in geometry.get_children():
				if piece is Node3D and piece.position.distance_to(nodes.north + Vector3(0,0,-1.15)) < 0.01:
					geometry.remove_child(piece)
					piece.queue_free()
		var i = ["west", "east", "north"].find(key)
		s.urn(planting_position(i))
		# The puzzle world supplies the actual currently planted species.

	s.stairs(nodes.north,nodes.summit_step,1.7)
	s.bridge(nodes.summit_step,nodes.summit,1.7)
	s.pavilion(nodes.summit, 4.0, Shapes.TEAL)
	s.column(Vector3(0, 3.25, -10), 2.3, 9.6, Shapes.STONE)
	s.ring(nodes.summit + Vector3(0, 0.12, 0), 1.1, 0.1, Shapes.GOLD)
	make_seed(nodes.summit + Vector3(0, 0.35, 0), true)
	old_shell = Node3D.new()
	geometry.add_child(old_shell)
	var shell=s.column(nodes.summit + Vector3(0, 1, 0), 0.58, 1.7, Color(0.7, 0.8, 0.82, 0.22), old_shell)
	var glass=ShaderMaterial.new();glass.shader=preload("res://shaders/ruins_glass.gdshader")
	shell.material_override=glass
	for h in [0.12, 1.9]:
		s.ring(nodes.summit + Vector3(0, h, 0), 0.64, 0.065, Shapes.GOLD, old_shell)
	for h in [2, 4, 6]:
		var band = s.ring(Vector3(0, h, -10), 2.35, 0.08, Shapes.GOLD, old_shell)
		band.material_override = s.material(Shapes.GOLD, true)
	# A hidden ending decoration must not block the player or the final interaction ray.
	for body in old_shell.find_children("*","StaticBody3D",true,false):
		body.collision_layer=0;body.collision_mask=0
	pick(nodes.summit + Vector3(0, 1, 0), Vector3(0.7, 0.65, 0.7), "final", "", "把种子留给下一次春天")
	handle(nodes.center + Vector3(0.55, 0.06, 0.55), "bridge")
	connect_path("arrival", "entry_step")
	connect_path("entry_step", "landing")
	connect_path("landing", "center", "z_bridge")
	connect_path("center", "west", "x_bridge")
	connect_path("center", "east", "x_bridge")
	connect_path("center", "north", "z_bridge")
	connect_path("north", "summit_step", "habitat")
	connect_path("summit_step", "summit", "habitat")
	for i in 18:
		var a = i * TAU / 18
		s.plant(nodes.summit + Vector3(cos(a) * 1.6, 0.07, sin(a) * 1.6), 0.6 + (i % 3) * 0.15, i % 3, living_root)
	# Root-like bands belong to the building after release; an old shell can be habitat.
	for i in 8:
		var a = i * TAU / 8
		var root = s.column(Vector3(sin(a) * 1.9, 4, -10 + cos(a) * 1.9), 0.045, 7.9, Shapes.TEAL, living_root)
		root.rotation.z = sin(a) * 0.12
	memory_stone("landing", 8, Vector3(0.65, 0, 0.65))
	memory_stone("west", 9, Vector3(1, 0, 0.7))
	memory_stone("east", 10, Vector3(-1, 0, 0.7))
	memory_stone("north", 11, Vector3(-0.8, 0, -0.5))

func make_seed(p: Vector3, open: bool):
	seed_root.position = p
	s.column(Vector3(0, -0.1, 0), 0.48, 0.2, Shapes.STONE, seed_root)
	lotus = Node3D.new()
	seed_root.add_child(lotus)
	s.sphere(Vector3(0, 0.35, 0), 0.12, Shapes.GOLD, lotus)
	for i in 6:
		var a = i * TAU / 6
		var petal = s.sphere(Vector3(cos(a) * 0.18, 0.22, sin(a) * 0.18), 0.15, Shapes.TEAL, lotus)
		petal.scale = Vector3(1.2, 0.35, 0.65)
		petal.rotation.y = -a
	if not open:
		var seed_arch = s.arch(p + Vector3(0, 0.15, 0), 0.75, 1.5, Shapes.GOLD)
		for body in seed_arch.find_children("*","StaticBody3D",true,false): body.collision_layer=0

func memory_stone(key: String, id: int, offset: Vector3):
	var p: Vector3 = nodes[key] + offset
	s.block(p + Vector3(0, 0.24, 0), Vector3(0.32, 0.48, 0.18), Shapes.STONE)
	var mark = s.sphere(p + Vector3(0, 0.55, 0), 0.055, Shapes.GOLD)
	glints.append(mark)
	pick(p + Vector3(0, 0.35, 0), Vector3(0.7, 1.1, 0.7), "memory", str(id), "读一封旧城来信")

func requirement_open(requirement: String) -> bool:
	match requirement:
		"x_bridge": return Journey.bridge == 0
		"z_bridge": return Journey.bridge == 1 and (Journey.chapter != 0 or Puzzles.done("water_route"))
		"lift_down": return not Journey.lift
		"x_bridge_lift": return Journey.bridge == 0 and Journey.lift
		"habitat": return Puzzles.done("irrigation")
	return true

func route(from_id: String, to_id: String) -> Array:
	if from_id not in nodes or to_id not in nodes: return []
	var queue = [from_id]
	var seen = {from_id: ""}
	while not queue.is_empty():
		var current: String = queue.pop_front()
		if current == to_id:
			var result = [current]
			while seen[current] != "":
				current = seen[current]
				result.push_front(current)
			return result
		for edge in edges:
			if not requirement_open(edge[2]): continue
			var other = edge[1] if edge[0] == current else edge[0] if edge[1] == current else ""
			if other != "" and other not in seen:
				seen[other] = current
				queue.append(other)
	return []

func walk(id: String, speed_override = -1.0) -> bool:
	if busy: return false
	var path = route(Journey.node_id, id)
	if path.is_empty():
		if ui: ui.say("路还没有连通。转动轮柄，让长桥转身，或观察升降台的位置。")
		play_sound("error", -24)
		return false
	busy = true
	moving = true
	for step in path.slice(1):
		var position_target: Vector3 = nodes[step] + Vector3(0, 0.04, 0)
		var offset = position_target - avatar.position
		avatar.rotation.y = atan2(offset.x, offset.z)
		if first_person and capture:
			walker.yaw = atan2(-offset.x,-offset.z)
			walker.pitch = 0.0
		var duration = offset.length() / 3.1 if speed_override < 0 else speed_override
		var tween = create_tween()
		tween.tween_property(avatar, "position", position_target, maxf(duration, 0.01))
		await tween.finished
		Journey.node_id = step
		Journey.save_journey()
	moving = false
	busy = false
	refresh_markers()
	if walker:
		walker.position = avatar.position
		remember_player_position()
	return true

func interact(action: String, id: String):
	if busy or not playing: return
	if tutorial:tutorial.observe_interaction(action,id)
	if action == "puzzle":
		var parts = id.split(":")
		var op = parts[0]
		var before = Puzzles.data.solved.size()
		var message = Puzzles.operate(op,int(parts[1]),companion.ready_for(op))
		var sound_op=op.trim_suffix("_back")
		soundscape.effect("mirror" if sound_op=="mirror" else "module" if sound_op in ["slot","bed","take_fuse","take_plant","retrieve_slot","retrieve_bed"] else "valve",walker.position,-21)
		ui.say(repair_feedback(message,before))
		if Puzzles.data.solved.size()>before and op == "life": companion.celebrate=3
		return
	match action:
		"bridge": await turn_bridge()
		"lift": await use_lift()
		"water":
			var before=Puzzles.data.solved.size()
			ui.say(repair_feedback(Puzzles.operate("pump",0,companion.ready_for("pump")),before))
			if Puzzles.done("pump"): ui.chapter_complete()
		"shutters":
			var before=Puzzles.data.solved.size()
			ui.say(repair_feedback(Puzzles.operate("roof",0,companion.ready_for("roof")),before))
			if Puzzles.done("roof"):
				ui.chapter_complete()
		"robot": dispatch_robot(id)
		"inspect": ui.inspect_record(id)
		"result":
			var value = int(id)
			var task: String = Puzzles.TASKS[Journey.chapter][value%4-1]
			if Puzzles.done(task): ui.memory(value)
			else: ui.say("这封回信还在等待。先完成「"+Puzzles.NAMES[task]+"」。")
		"memory":
			Journey.remember(int(id))
			play_sound("clue",-19)
			ui.memory(int(id))
		"final":
			if not Puzzles.chapter_done(2): ui.say("风塔还没有醒来。先让植物、水路和根系彼此接通。")
			else: ui.final_choice()

func repair_feedback(message: String,previous_count: int) -> String:
	if Puzzles.data.solved.size()>previous_count:
		message+="\n"+PARTNER_LINES.get(Puzzles.data.solved[-1],"")
	return message
func dispatch_robot(task: String):
	if task == "pump" and not Puzzles.done("pressure"): ui.say("先稳定滤池压力，再请芽芽协助。");return
	if task == "roof" and not Puzzles.done("mirrors"): ui.say("先让两面镜子把日光送到幼苗。");return
	if task == "battery" and not Puzzles.done("irrigation"): ui.say("先给三处种植床分好水。");return
	if tutorial:tutorial.learn("partner")
	companion.command("assist",task)
	ui.say("芽芽正在赶往"+{"pump":"供电踏板","roof":"制动开关","battery":"风塔储能接口"}[task]+"。")

func on_puzzle_update():
	Journey.water = Puzzles.done("pump")
	Journey.shutters = Puzzles.done("roof")
	Journey.species = [0,1,2] if Puzzles.done("planting") else []
	if Puzzles.chapter_done(Journey.chapter): Journey.finish_chapter()
	if puzzle_world: puzzle_world.refresh(true)
	if walker: refresh()

func on_puzzle_solved(id: String):
	play_sound("grow",-19)
	if ui: ui.say("「"+Puzzles.NAMES[id]+"」完成 · 世界又想起一点颜色")
	if repair_focus:repair_focus.notify(id)

func turn_bridge(speed_override = -1.0) -> bool:
	if busy: return false
	var safe = ["landing", "lift_high", "center"][Journey.chapter]
	if Journey.chapter == 0 and not Puzzles.done("water_route"):
		if ui: ui.say("桥的制动锁还没松开。先修复桥边的水路。")
		return false
	if walker.position.distance_to(nodes[safe]) > 1.9:
		if ui: ui.say("请先走到桥梁中央的轮柄旁。")
		return false
	avatar.position = walker.position
	Journey.node_id = safe
	busy = true
	Journey.bridge = 1 - Journey.bridge
	var target_angle = PI / 2 if Journey.bridge == 1 else 0.0
	var tween = create_tween()
	tween.tween_property(rotor, "rotation:y", target_angle, 1.35 if speed_override < 0 else 0.01).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# At the central pivot, the traveler rides the rotation in place.
	play_sound("interact")
	await tween.finished
	busy = false
	Journey.save_journey()
	refresh_markers()
	if ui:
		ui.say("长桥转过身来了。沿着新接好的路，去下一处微光看看。")
	return true

func use_lift(speed_override = -1.0) -> bool:
	if busy or Journey.chapter != 1: return false
	var from_key = "lift_high" if Journey.lift else "lift_low"
	if not Puzzles.done("power"):
		if ui: ui.say("日光台还没有电。检查入口的电源柜。")
		return false
	if walker.position.distance_to(nodes[from_key]) > 1.9:
		if ui: ui.say("先走进日光台，再转动轮柄。")
		return false
	busy = true
	Journey.lift = not Journey.lift
	var to_key = "lift_high" if Journey.lift else "lift_low"
	var tween = create_tween().set_parallel(true)
	var duration = 2.2 if speed_override < 0 else 0.01
	tween.tween_property(elevator, "position", nodes[to_key], duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(avatar, "position", nodes[to_key] + Vector3(0, 0.04, 0), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	play_sound("interact")
	await tween.finished
	Journey.node_id = to_key
	walker.position = avatar.position
	remember_player_position()
	Journey.save_journey()
	busy = false
	refresh_markers()
	if ui:
		ui.say("到高处了。抬头，天空一直在这里。" if Journey.lift else "日光台轻轻落下，回到水边等你。")
	return true

func open_shutters(speed_override = -1.0):
	if not Puzzles.done("roof"): return
	soundscape.effect("roof",nodes.sun,-18)
	busy = true
	Journey.shutters = true
	var tween = create_tween().set_parallel(true)
	for i in 2:
		tween.tween_property(shutter_panels[i], "position:x", 6 + (-3 if i == 0 else 3), 2 if speed_override < 0 else 0.01).set_trans(Tween.TRANS_SINE)
	await tween.finished
	Journey.finish_chapter()
	refresh()
	play_sound("grow")
	busy = false
	if ui: ui.say("旧灯可以歇一歇了。今天，太阳会照顾这些叶子。")

func choose_ending(choice: String, speed_override = -1.0):
	if choice not in ["eden", "regeneration"] or not Puzzles.chapter_done(2): return
	Journey.ending = choice
	follow_view = false
	angle = -0.65
	inclination = 0.36
	Journey.finish_chapter()
	Journey.save_journey()
	if ui: ui.close_panel()
	playing = false
	busy = true
	refresh()
	if choice == "regeneration":
		living_root.scale = Vector3.ONE * 0.01
		var tween = create_tween().set_parallel(true)
		tween.tween_property(living_root, "scale", Vector3.ONE, 4 if speed_override < 0 else 0.01).set_trans(Tween.TRANS_SINE)
		tween.tween_property(self, "distance", 25.0, 4 if speed_override < 0 else 0.01)
		await tween.finished
	play_sound("grow")
	busy = false
	if ui: ui.ending_card()

func refresh():
	if lighting:lighting.refresh()
	if rotor: rotor.rotation.y = PI / 2 if Journey.bridge == 1 else 0
	flow_root.visible = Journey.water if Journey.chapter == 0 else Journey.shutters if Journey.chapter == 1 else false
	living_root.visible = Journey.water if Journey.chapter == 0 else Journey.shutters if Journey.chapter == 1 else Journey.ending == "regeneration"
	if Journey.chapter == 1:
		elevator.position = nodes.lift_high if Journey.lift else nodes.lift_low
		for i in 2:
			shutter_panels[i].position.x = 6 + (-3 if i == 0 else 3) if Journey.shutters else 6 + (-1 if i == 0 else 1)
		for lamp in lamps:
			lamp.material_override = s.material(Shapes.INK if Journey.shutters else Shapes.GOLD, not Journey.shutters)
	lotus.scale = Vector3.ONE * (1.35 if Journey.ending == "regeneration" else 1.0)
	if Journey.chapter == 2:
		old_shell.visible = Journey.ending == "eden"
	if Journey.chapter == 2 and Journey.ending == "eden":
		lotus.scale = Vector3.ONE * 0.55
		lotus.visible = true
	refresh_markers()
	if dynamic_audio:
		dynamic_audio.volume_db = lerpf(-44, -24, recovery)
	if restoration:restoration.refresh()

func refresh_markers():
	for id in waypoints:
		var reachable = not route(Journey.node_id, id).is_empty()
		waypoints[id].material_override = s.material(Shapes.GOLD if reachable else Shapes.STONE.darkened(0.15), reachable)
		waypoints[id].scale = Vector3.ONE * (1.25 if id == Journey.node_id else 1)

func enter_follow_view():
	follow_view = true
	follow_distance = 12.0
	follow_focus = avatar.position + Vector3(0, 1.1, 0)
	inclination = 0.22
	update_camera()

func toggle_view():
	if busy or not playing: return
	if follow_view:
		follow_view = false
		inclination = 0.42
	else:
		enter_follow_view()
	update_camera()

func update_camera():
	if repair_focus and repair_focus.active:return
	if first_person and walker:
		camera.fov = 76
		camera.position = walker.eye_position()
		camera.rotation = Vector3(walker.pitch, walker.yaw, 0)
		return
	camera.fov = 54
	var target = follow_focus if follow_view else focus
	var radius = follow_distance if follow_view else distance * 1.03
	var offset = Vector3(sin(angle) * cos(inclination), sin(inclination), cos(angle) * cos(inclination)) * radius
	camera.position = target + offset
	camera.look_at(target)

func _process(delta):
	time += delta
	if not camera: return
	if avatar and follow_view:
		follow_focus = follow_focus.lerp(avatar.position + Vector3(0, 1.1, 0), 1.0 - exp(-delta * 5.0))
	update_camera()
	if avatar and moving:
		avatar.get_child(2).position.y = 0.43 + sin(time * 12) * 0.035
	if lotus:
		lotus.rotation.y = time * 0.15
	for i in glints.size():
		glints[i].scale = Vector3.ONE * (0.8 + sin(time * 2 + i) * 0.2)
	if not playing or not ui or ui.panel_open(): return
	Journey.elapsed += delta
	save_clock += delta
	if save_clock > 6:
		save_clock = 0
		Journey.save_journey()
	var mouse = get_viewport().get_visible_rect().size / 2 if first_person else get_viewport().get_mouse_position()
	hovered = pick_at(mouse)
	if first_person and not valid_nearby_target(hovered): hovered = null
	if hovered and hovered.has_meta("action"):
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	else:
		hovered = null
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _unhandled_input(event):
	# Automated render compositions must not react to keys typed in other apps.
	if "--garden-capture" in OS.get_cmdline_user_args() or "--performance-test" in OS.get_cmdline_user_args(): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if repair_focus and repair_focus.active:repair_focus.cancel();ui.pause_menu();return
			if ui.panel_open() and ui.closable: ui.dismiss_panel()
			elif playing and not busy: ui.pause_menu()
		elif event.physical_keycode == KEY_TAB and playing and not busy: ui.journal()
		elif event.physical_keycode == KEY_C and playing and not busy: ui.companion_menu()
		elif event.physical_keycode == KEY_E and first_person: use_nearby_target()
		elif event.physical_keycode == KEY_F and first_person: use_nearby_target(true)
		elif event.physical_keycode == KEY_Q and first_person and playing and not busy and not ui.panel_open() and Journey.chapter==2:
			ui.say(Puzzles.select_next_plant())
	elif event is InputEventMouseMotion and first_person and playing and not ui.panel_open() and not busy:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: walker.look(event.relative)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and playing and not ui.panel_open():
		if first_person:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not capture: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else: use_nearby_target()
		elif not busy:
			var clicked = pick_at(event.position)
			if clicked and clicked.has_meta("action"): interact(clicked.get_meta("action"), clicked.get_meta("id"))

func build_colour_recovery():
	var layer = CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var screen = ColorRect.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colour_material = ShaderMaterial.new()
	colour_material.shader = load("res://shaders/colour_recovery.gdshader")
	screen.material = colour_material
	layer.add_child(screen)
	recovery = float(Journey.memories.size()) / 12.0
	colour_material.set_shader_parameter("recovery", recovery)

func set_recovery(value: float):
	recovery = clampf(value, 0, 1)
	if sky_material is ShaderMaterial: sky_material.set_shader_parameter("recovery", recovery)
	if environment:
		environment.fog_density = lerpf(0.012, 0.0045, recovery)
		environment.fog_light_color = Color("a1abb2").lerp(Color("aebfc7"), recovery)
		environment.ambient_light_energy = lerpf(0.38, 0.46, recovery)
	for plant in recovery_plants:
		if is_instance_valid(plant):
			plant.scale = Vector3.ONE * float(plant.get_meta("growth_scale")) * lerpf(0.45, 1.0, recovery)
	if colour_material: colour_material.set_shader_parameter("recovery", recovery)
	if dynamic_audio: dynamic_audio.volume_db = lerpf(-44, -24, recovery)

func on_clue_change():
	var target = float(Journey.memories.size()) / 12.0
	if colour_tween and colour_tween.is_valid(): colour_tween.kill()
	if target == 0 or DisplayServer.get_name() == "headless": set_recovery(target)
	else:
		colour_tween = create_tween()
		colour_tween.tween_method(set_recovery, recovery, target, 2.4).set_trans(Tween.TRANS_SINE)

func enter_first_person():
	first_person = true
	follow_view = false
	avatar.visible = false
	walker.position = avatar.position
	update_camera()

func sync_mouse_capture():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if playing and first_person and ui and not ui.panel_open() and not capture else Input.MOUSE_MODE_VISIBLE

func valid_nearby_target(body: Node3D) -> bool:
	return is_instance_valid(body) and body.has_meta("action") and body.get_meta("action") != "walk" and walker.position.distance_to(body.global_position) <= 2.65

func use_nearby_target(reverse = false):
	if not playing or busy or ui.panel_open(): return
	var body = pick_at(get_viewport().get_visible_rect().size / 2)
	if valid_nearby_target(body):
		var id: String=body.get_meta("id")
		if reverse:
			if body.get_meta("action")!="puzzle":return
			var parts=id.split(":")
			if parts[0] in Puzzles.REVERSIBLE:id=parts[0]+"_back:"+parts[1]
			elif parts[0] in ["slot","bed"]:id="retrieve_"+parts[0]+":"+parts[1]
			else:return
		interact(body.get_meta("action"), id)
	else: ui.say("再走近一点吧。对准微光石碑或铜色轮柄，按 E。")

func floor_at(p: Vector3) -> float:
	var best = INF
	var difference = INF
	for id in nodes:
		if Journey.chapter == 1 and ((id == "lift_low" and Journey.lift) or (id == "lift_high" and not Journey.lift)): continue
		var n: Vector3 = nodes[id]
		if Vector2(p.x-n.x,p.z-n.z).length() < (0.4 if id in ["stair_top","entry_step","summit_step"] else 0.6 if id == "center" else 1.1) and absf(p.y-n.y) < 0.9:
			if absf(p.y-n.y) < difference:
				best = n.y
				difference = absf(p.y-n.y)
	for edge in edges:
		if not requirement_open(edge[2]): continue
		var a: Vector3 = nodes[edge[0]]
		var b: Vector3 = nodes[edge[1]]
		var start = Vector2(a.x,a.z)
		var span = Vector2(b.x-a.x,b.z-a.z)
		if span.length_squared() < 0.01: continue
		var t = clampf((Vector2(p.x,p.z)-start).dot(span)/span.length_squared(),0,1)
		var h = lerpf(a.y,b.y,t)
		if Vector2(p.x,p.z).distance_to(start+span*t) < 0.5 and absf(p.y-h) < 0.9 and (absf(p.y-h) < difference or absf(a.y-b.y) > 0.1):
			best = h
			difference = absf(p.y-h)
	return best

func remember_player_position():
	if not walker: return
	Journey.fps_position = walker.position
	Journey.fps_valid = true
	Journey.fps_yaw = walker.yaw
	Journey.fps_pitch = walker.pitch
	var nearest = ""
	var d = 1.4
	for id in nodes:
		var candidate: float = walker.position.distance_to(nodes[id])
		if candidate < d and not is_inf(floor_at(nodes[id])):
			d = candidate
			nearest = id
	if nearest != "": Journey.node_id = nearest

func build_audio():
	soundscape = load("res://scripts/soundscape.gd").new()
	soundscape.garden = self
	add_child(soundscape)
	soundscape.chapter(Journey.chapter)
func play_sound(key: String, volume = -19):
	if soundscape and walker: soundscape.effect(key,walker.position,volume)
func stop_audio():
	if soundscape:
		for player in soundscape.get_children():
			if player is AudioStreamPlayer or player is AudioStreamPlayer3D: player.stream_paused=false;player.stop()
func _exit_tree(): stop_audio()

func quit_game():
	Journey.save_journey()
	stop_audio()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

func screenshot(name: String):
	print("CAPTURE_FRAME: ", name, " / panel=",ui.panel_kind," playing=",playing)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../builds/" + name + ".png")

func hold(duration: float):
	await get_tree().create_timer(duration).timeout

func aim_at(p: Vector3):
	var direction = p - walker.eye_position()
	walker.yaw = atan2(-direction.x,-direction.z)
	walker.pitch = atan2(direction.y,Vector2(direction.x,direction.z).length())
	update_camera()

func capture_chapters():
	print("CAPTURE_BEGIN")
	Journey.fresh()
	build_chapter()
	enter_first_person()
	playing = true
	ui.close_panel()
	await hold(0.5)
	await screenshot("fps-blackwhite")
	await screenshot("garden-water")
	for id in 6: Journey.remember(id)
	await hold(2.8)
	await screenshot("fps-midcolour")
	for id in range(6,12): Journey.remember(id)
	await hold(2.8)
	await screenshot("fps-fullcolour")
	var coastline_yaw=walker.yaw
	var coastline_pitch=walker.pitch
	walker.position=nodes.spring+Vector3(0,.055,0);avatar.position=walker.position
	aim_at(Vector3(-25,3,-6))
	await hold(.3)
	await screenshot("scene-coastal-houses")
	walker.position=nodes.arrival+Vector3(0,.055,0);avatar.position=walker.position
	aim_at(Vector3(-10,-1,30))
	await hold(.3)
	await screenshot("scene-open-sea")
	walker.yaw=coastline_yaw;walker.pitch=coastline_pitch;update_camera()
	var saved_pose = walker.position
	walker.position = nodes.arrival+Vector3(0,.055,1.8)
	avatar.position=walker.position
	aim_at(companion.position+Vector3(0,.6,0))
	await hold(.3)
	await screenshot("yaya-companion")
	walker.position=saved_pose;avatar.position=saved_pose
	walker.position = nodes.landing + Vector3(0,0.055,0)
	avatar.position = walker.position
	aim_at(nodes.altar + Vector3(0,2.7,-1))
	await hold(0.3)
	await screenshot("scene-pump-station")
	walker.position=nodes.landing+Vector3(0,.055,3.1)
	avatar.position=walker.position
	aim_at(nodes.landing+Vector3(0,.9,1.2))
	await hold(.3)
	await screenshot("puzzle-workbench")
	ui.pause_menu()
	await hold(.3)
	await screenshot("ui-menu")
	ui.pause_menu()
	await hold(.3)
	await screenshot("ui-controls")
	ui.close_panel()
	ui.companion_menu()
	await hold(.3)
	await screenshot("ui-companion")
	ui.close_panel()
	ui.journal()
	await hold(.3)
	await screenshot("ui-hint")
	ui.inspect_record("route")
	await hold(.3)
	await screenshot("ui-field-notes")
	ui.settings_menu()
	await hold(.3)
	await screenshot("ui-settings")
	ui.close_panel()
	Journey.fresh()
	build_chapter()
	ui.title_screen()
	await hold(0.3)
	await screenshot("garden-title")
	for page in 3:
		ui.prologue_screen(page,"title")
		await hold(.3)
		await screenshot("prologue-"+str(page+1))
	ui.chapter_opening()
	await hold(0.3)
	await screenshot("chapter-water")
	playing = true
	ui.close_panel()
	Journey.next_chapter()
	build_chapter()
	await hold(0.5)
	await screenshot("garden-sun")
	ui.chapter_opening()
	await hold(0.3)
	await screenshot("chapter-sun")
	ui.close_panel()
	for id in 12: Journey.remember(id)
	walker.position = nodes.lift_high + Vector3(.3,0.055,-.6)
	avatar.position = walker.position
	aim_at(nodes.sun + Vector3(0,1.6,0))
	await hold(2.8)
	await screenshot("scene-greenhouse")
	Journey.next_chapter()
	build_chapter()
	await hold(0.5)
	await screenshot("garden-life")
	ui.chapter_opening()
	await hold(0.3)
	await screenshot("chapter-life")
	ui.close_panel()
	walker.position = nodes.landing + Vector3(0,0.055,0)
	avatar.position = walker.position
	aim_at(nodes.summit + Vector3(0,2.2,0))
	await hold(0.3)
	await screenshot("scene-regrowth")
	Journey.species = [0,1,2]
	Journey.node_id = "summit"
	avatar.position = nodes.summit
	walker.position = avatar.position
	for id in 12: Journey.remember(id)
	# Controlled screenshot composition; not gameplay or puzzle verification.
	for task in Puzzles.TASKS[2]: Puzzles.finish(task)
	await choose_ending("regeneration",0.01)
	await hold(2.8)
	await screenshot("garden-card")
	await ui.save_card()
	ui.close_panel()
	playing = true
	aim_at(nodes.summit + Vector3(0,0.7,0))
	await hold(0.3)
	await screenshot("garden-regeneration")
	await quit_game()

func film_clue(id: int):
	var stone: Node3D
	for body in pickables:
		if body.get_meta("action") == "memory" and int(body.get_meta("id")) == id: stone = body
	if not stone: return
	aim_at(stone.global_position)
	Journey.remember(id)
	play_sound("clue",-19)
	ui.memory(id)
	await hold(3)
	ui.close_panel()

func film():
	var runner = load("res://scripts/puzzle_playthrough.gd").new(self)
	await runner.run(true)
	await quit_game()

func pick_at(screen_position: Vector2) -> Node3D:
	var origin = camera.project_ray_origin(screen_position)
	var query = PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen_position) * 100, 3)
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider")
