extends Node3D
var garden: Node3D
var clock = 0.0
var trail: Array[Vector3] = []
var node_id = "arrival"
var target_key = ""
var target_position = Vector3.ZERO
var arrived = false
var stuck = 0.0
var celebrate = 0.0
var mood = "待机"
var tread_clock = 0.0
var belt_distance = 0.0
var track_links: Array[MeshInstance3D] = []
@onready var head = $HeadPivot
@onready var arm = $ArmPivot
@onready var cargo = $Cargo
func _ready():
	var shapes = load("res://scripts/garden_shapes.gd").new(self)
	$Body.mesh = shapes.rounded_box(Vector3(0.65,0.49,0.46),.075)
	for piece in [$TrackLeft,$TrackRight,$Cargo]: piece.mesh = shapes.rounded_box(piece.mesh.size,.035)
	build_mechanical_details(shapes)
	Puzzles.solved.connect(on_solved)
func on_solved(_id): celebrate = 2.5
func active() -> bool:
	return garden and garden.playing and garden.ui and not garden.ui.panel_open()
func command(mode: String, task = ""):
	Puzzles.data.robot_mode = mode
	Puzzles.data.robot_task = task
	if mode == "follow": Puzzles.data.robot_cargo=false
	arrived = false
	trail.clear()
	if mode == "assist":
		var dock = garden.puzzle_world.robot_dock(task)
		target_key = dock[0]
		target_position = dock[1]
	else: target_key = ""
	record()
	Journey.save_journey()
func ready_for(task: String) -> bool:
	return Puzzles.data.robot_mode == "assist" and Puzzles.data.robot_task == task and arrived
func nearest_node(p: Vector3) -> String:
	var best = node_id
	var distance = INF
	for key in garden.nodes:
		var d: float = p.distance_to(garden.nodes[key])
		if d < distance: best = key; distance = d
	return best
func path_to(key: String, endpoint: Vector3):
	var start = nearest_node(position)
	var route: Array = garden.route(start,key)
	if route.is_empty(): return
	trail = []
	if position.distance_to(garden.nodes[start]) > 0.6: trail.append(garden.nodes[start]+Vector3(0,0.055,0))
	for next in route.slice(1): trail.append(garden.nodes[next]+Vector3(0,0.055,0))
	trail.append(endpoint+Vector3(0,0.055,0))
func record():
	Puzzles.data.robot_node = nearest_node(position)
	Puzzles.data.robot_position = [position.x,position.y,position.z]
func _process(delta):
	if not active(): return
	clock += delta
	var mode: String = Puzzles.data.robot_mode
	var task: String = Puzzles.data.robot_task
	if mode == "follow" and position.distance_to(garden.walker.position) > 2.0 and trail.is_empty():
		var key = Journey.node_id
		var dock: Vector3 = garden.nodes.get(key,garden.nodes.arrival)+Vector3(-0.55,0,0.35)
		path_to(key,dock)
	elif mode == "assist" and not arrived and trail.is_empty():
		var dock = garden.puzzle_world.robot_dock(task)
		if task == "battery" and not Puzzles.data.robot_cargo:
			dock = ["landing",garden.nodes.landing+Vector3(-.55,0,.35)]
		target_key = dock[0]
		target_position = dock[1]
		path_to(target_key,target_position)
	var moving_now = not trail.is_empty()
	var before_position=position
	if moving_now:
		var next: Vector3 = trail[0]
		var diff = next-position
		var candidate = position.move_toward(next,delta*2.15)
		var floor_y: float = garden.floor_at(candidate)
		if not is_inf(floor_y):
			position = candidate
			position.y = floor_y+0.055
			stuck = 0
			if Vector2(diff.x,diff.z).length() > 0.05: rotation.y = lerp_angle(rotation.y,atan2(diff.x,diff.z),delta*6)
		else:
			stuck += delta
			trail.clear()
		if position.distance_to(next) < 0.12: trail.pop_front()
		if trail.is_empty() and mode == "assist" and position.distance_to(target_position) < 0.3:
			if task == "battery" and not Puzzles.data.robot_cargo:
				Puzzles.data.robot_cargo=true
				garden.soundscape.effect("robot_arm",global_position,-22)
				garden.puzzle_world.refresh()
				garden.ui.say("芽芽从工具架取到了储能单元，正在送往风塔。")
				record();Journey.save_journey()
				return
			arrived = true
			if task == "battery":
				Puzzles.data.battery = true
				Puzzles.data.robot_cargo=false
				Puzzles.updated.emit()
				garden.ui.say("芽芽把储能单元接进风塔。现在检查两段根系。")
			else: garden.ui.say("芽芽已守住" + ("供电踏板。去泵房启动水泵吧。" if task == "pump" else "制动开关。现在转动屋顶轮柄吧。"))
			record()
			Journey.save_journey()
	# A lift can separate levels. Rejoin only while outside the player's view, never across a visible gap.
	if (mode=="follow" and position.distance_to(garden.walker.position)>9) or stuck>3:
		if not garden.camera.is_position_in_frustum(global_position+Vector3(0,0.6,0)):
			var key = Journey.node_id
			position = garden.nodes.get(key,garden.nodes.arrival)+Vector3(-0.55,0.055,0.35)
			trail.clear()
			stuck = 0
	mood = "搬运" if mode == "assist" and task == "battery" and not arrived else "操作" if arrived else "跟随" if moving_now else "观察" if mode == "follow" else "等待"
	var gaze=sin(clock*.65)*.13
	if mode=="follow" and position.distance_to(garden.walker.position)<4.0:
		var local_target=to_local(garden.walker.global_position+Vector3(0,.8,0))
		gaze=clampf(atan2(local_target.x,local_target.z),-.65,.65)
	head.rotation.y=lerp_angle(head.rotation.y,0.0 if arrived else gaze,1.0-exp(-delta*4.0))
	head.rotation.x = sin(clock*1.2)*0.045
	arm.rotation.x = lerpf(arm.rotation.x,-0.7 if arrived else sin(clock*3)*0.08 if moving_now else 0.15,1.0-exp(-delta*6.0))
	cargo.visible = task == "battery" and Puzzles.data.robot_cargo and not Puzzles.data.battery
	$Body.position.y = 0.48+sin(clock*(7 if moving_now else 1.8))*0.013
	celebrate = maxf(0,celebrate-delta)
	if celebrate>0: head.rotation.z = sin(clock*6)*0.15*minf(1.0,celebrate/.6);arm.rotation.z=sin(clock*5)*0.3*minf(1.0,celebrate/.6)
	else: head.rotation.z = 0;arm.rotation.z=0
	belt_distance += Vector2(position.x-before_position.x,position.z-before_position.z).length()
	update_tracks()
	tread_clock += delta
	if moving_now and tread_clock > 0.6:
		tread_clock = 0
		garden.soundscape.effect("robot_tread",global_position,-28)
	record()

func build_mechanical_details(shapes):
	var shell=ShaderMaterial.new();shell.shader=preload("res://shaders/worn_enamel.gdshader")
	shell.set_shader_parameter("paint_color",Color("bac0af"))
	shell.set_shader_parameter("wear",.16)
	var rubber=shapes.material(Color("27383b"));rubber.roughness=.94
	var brass=shapes.material(Color("ab8755"));brass.metallic=.65;brass.roughness=.4
	$Body.material_override=shell
	$HeadPivot/Head.material_override=shell
	$TrackLeft.material_override=rubber;$TrackRight.material_override=rubber
	# A layered lens housing and glass rather than a single flattened sphere.
	for pair in [[.178,.035,.12,rubber],[.149,.021,.164,brass],[.127,.012,.184,rubber]]:
		var mesh=TorusMesh.new();mesh.outer_radius=pair[0];mesh.inner_radius=pair[0]-pair[1];mesh.rings=40;mesh.ring_segments=12
		var ring=MeshInstance3D.new();ring.mesh=mesh;ring.material_override=pair[3]
		$HeadPivot.add_child(ring);ring.position=Vector3(0,0,pair[2]);ring.rotation.x=PI/2
	$HeadPivot/Eye.position.z=.192
	$HeadPivot/Eye.material_override=$HeadPivot/Eye.material_override.duplicate()
	$HeadPivot/Eye.material_override.roughness=.12
	$HeadPivot/Eye.material_override.metallic=.3
	$HeadPivot/Eye.material_override.emission_energy_multiplier=1.8
	var lens_light=OmniLight3D.new();lens_light.name="LensGlow";$HeadPivot.add_child(lens_light)
	lens_light.position=Vector3(0,0,.25);lens_light.light_color=Color("a5cbbb")
	lens_light.light_energy=.16;lens_light.omni_range=1.0;lens_light.light_volumetric_fog_energy=0.0
	var iris=shapes.rounded_detail(Vector3(0,0,.23),Vector3(.054,.085,.012),Color("214446"),.008,$HeadPivot)
	# A permanent seed tin sits above the separate transport cargo.
	shapes.rounded_detail(Vector3(0,.79,-.27),Vector3(.28,.14,.16),Color("8b745d"),.025,self)
	shapes.rounded_detail(Vector3(0,.866,-.27),Vector3(.3,.025,.18),Color("cbb482"),.012,self)
	for x in [-.06,0,.06]: shapes.rounded_detail(Vector3(x,.79,-.354),Vector3(.025,.044,.012),Color("dfd2a5"),.01,self)
	# Bolted access panel, vents and a raised maintenance badge.
	shapes.rounded_detail(Vector3(0,.49,.237),Vector3(.51,.35,.022),Color("a2ae9f"),.04,self)
	for x in [-.225,.225]:
		for y in [.36,.62]:
			var bolt=shapes.sphere(Vector3(x,y,.26),.018,Color("ab8755"),self)
			for body in bolt.find_children("*","StaticBody3D",true,false):body.collision_layer=0
	for i in 5: shapes.detail(Vector3(-.12+i*.06,.4,.265),Vector3(.022,.065,.01),Color("334647"),self)
	shapes.rounded_detail(Vector3(0,.58,.27),Vector3(.17,.066,.012),Color("d2b77c"),.01,self)
	# Actual links move around a closed rounded belt in proportion to distance.
	for side in [-1,1]:
		for i in 26:
			var link=shapes.detail(Vector3.ZERO,Vector3(.19,.018,.045),Color("47504b"),self)
			link.name="TreadLink%d_%d"%[side,i]
			link.set_meta("side",side);link.set_meta("belt_index",i)
			track_links.append(link)
	update_tracks()
	# The gripper has a visible elbow, sleeve and two fingers, with decorative collision disabled.
	var elbow=shapes.sphere(Vector3(0,-.15,0),.072,Color("526968"),$ArmPivot)
	for body in elbow.find_children("*","StaticBody3D",true,false):body.collision_layer=0
	for side in [-1,1]:
		shapes.rounded_detail(Vector3(side*.053,-.34,.022),Vector3(.03,.1,.08),Color("bcc4b3"),.012,$ArmPivot)
	var neck=shapes.column(Vector3(0,.745,.07),.08,.13,Color("526968"),self)
	for body in neck.find_children("*","StaticBody3D",true,false):body.collision_layer=0

func update_tracks():
	var straight=.44
	var curve=PI*.10
	var perimeter=2.0*(straight+curve)
	for link in track_links:
		var d=fposmod(float(link.get_meta("belt_index"))/26.0*perimeter+belt_distance,perimeter)
		var side=float(link.get_meta("side"))
		if d<straight:
			link.position=Vector3(side*.31,.258,-.22+d);link.rotation.x=0
		elif d<straight+curve:
			var angle=(d-straight)/.1
			link.position=Vector3(side*.31,.158+.1*cos(angle),.22+.1*sin(angle));link.rotation.x=angle
		elif d<2*straight+curve:
			link.position=Vector3(side*.31,.058,.22-(d-straight-curve));link.rotation.x=PI
		else:
			var angle=(d-2*straight-curve)/.1
			link.position=Vector3(side*.31,.158-.1*cos(angle),-.22-.1*sin(angle));link.rotation.x=PI+angle
