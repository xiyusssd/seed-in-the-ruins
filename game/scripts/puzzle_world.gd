extends Node3D
var garden: Node3D
var shapes: RefCounted
var visuals: Dictionary = {}
var labels: Dictionary = {}
var plants: Array[Node3D] = []
var plant_kinds = [-1,-1,-1]
var water_segments: Array[Node3D] = []
var leaks: Array[Node3D] = []
var beams: Array[Node3D] = []
var turbine: Node3D
var battery_model: Node3D
var turns: Dictionary = {}
var relay_position = Vector3.ZERO
var worksite: Node3D
var record_boards: Dictionary = {}
const RECORD_FACES = {
"route":["W-01 / 水路","先过滤，再蓄水，最后回流。\n泵站出口：东 →\n蓄水槽入口：西 ←\n回流口：南 ↓\n接头箭头表示出口方向。"],
"pressure":["W-02 / 水压","净水位停在 Ⅲ 线。\n回流刻痕：Ⅰ，保持慢流。\n进水每档 +2 格\n回流每档 −1 格\n先定回流，再推算进水。"],
"power":["S-01 / 电源","插槽从左至右：\n□ 方形　○ 圆形　△ 三角\n模块按外形匹配插槽。\n装好模块，再检查升降机。\n不要只凭颜色辨认。"],
"mirrors":["M-01 / 日光","第一束光 → 锈铜中继板\n第二束光 → 育苗工作台\n零档北；顺时针东、南、西。\n沿光束检查镜子的出口。\n请芽芽保持镜架制动。"],
"beds":["G-01 / 种植","西床：花卉，水量 Ⅰ\n东床：豆科，水量 Ⅱ\n北床：深根，水量 Ⅲ\n花卉留客，豆科养土。\n深根植物把水留下。"],
"roots":["L-03 / 风塔","左接头朝南 ↓\n右接头朝东 →\n零档北；顺时针东、南、西。\n请芽芽从工具架运来储能。\n根系、储能到位再启动。"],
}
const NOTES = {
"route":"滤池维护图\n\n水不能直接去种植床。先通过滤池，再到蓄水槽，最后接回流。\n泵站出口朝东；蓄水槽入口在西侧；回流口朝南。\n接头上的箭头记录出口方向。",
"pressure":"滤池检修单\n\n净水位要停在Ⅲ线。\n回流槽留着一道刻痕：Ⅰ，维持缓慢回流，让泥沙沉下去。\n\n进水每档增加两格，回流每档减一格。先确定回流，再根据仪表推算进水。",
"power":"电源柜铭牌\n\n从左到右：□  ○  △\n模块不能只凭颜色分辨，要看外形。",
"mirrors":"日光传递图\n\n先让第一束光落到锈铜中继板，再沿中继光找到第二面镜子。第二束光需要落在育苗工作台。\n\n观察实际光束和装置位置，刻度记录出口方向：零档北，顺时针东、南、西。\n制动松开时，镜架会回落；请伙伴保持开关。",
"beds":"写给后来者的种植记录\n\n西床：阳光与浅水，留给访客。水量Ⅰ。\n东床：土壤贫瘠，先照顾养分。水量Ⅱ。\n北床：根要去深处，把水留下。水量Ⅲ。\n\n花卉留住访客，豆科养土，深根植物留水。",
"roots":"风塔双环图\n\n左接头朝南，右接头朝东。\n零档朝北，顺时针东、南、西。\n\n储能单元太重，请芽芽从入口工具架运来。\n两段根系与储能单元到位后，才能启动风塔。"}
func _init(g):
	garden = g
	shapes = load("res://scripts/garden_shapes.gd").new(self)
func label(p: Vector3, text: String, size = 22) -> Label3D:
	var n = Label3D.new()
	n.font = load("res://assets/title_font.tres" if size>=21 else "res://assets/telemetry_font.tres")
	n.text = text
	n.font_size = size
	n.pixel_size = 0.007
	n.modulate = Color("f4e5c3")
	n.outline_size = 1
	n.outline_modulate = Color("253d3d")
	add_child(n)
	n.position = p
	return n
func cabinet(p: Vector3, title: String, width = 2.65):
	var casing=shapes.rounded_detail(p+Vector3(0,.65,-.15),Vector3(width,1.25,.34),Color("627b77"),.075)
	casing.create_trimesh_collision()
	var enamel=ShaderMaterial.new();enamel.shader=preload("res://shaders/worn_enamel.gdshader")
	enamel.set_shader_parameter("paint_color",Color("627b77"))
	casing.material_override=enamel
	shapes.rounded_detail(p+Vector3(0,.64,.032),Vector3(width-.15,1.09,.024),Color("7a8b7d"),.014)
	shapes.rounded_detail(p+Vector3(0,1.35,-.13),Vector3(width+.12,.12,.4),Color("94745a"),.035)
	shapes.detail(p+Vector3(0,1.57,-.016),Vector3(width,.27,.055),Color("304748"))
	label(p+Vector3(0,1.58,.032),title,14)
	for x in [-width*.44,width*.44]:
		for y in [.16,1.12]:
			var bolt_mesh=CylinderMesh.new();bolt_mesh.top_radius=.024;bolt_mesh.bottom_radius=.024;bolt_mesh.height=.018;bolt_mesh.radial_segments=6
			var bolt=MeshInstance3D.new();bolt.mesh=bolt_mesh;bolt.material_override=shapes.material(Color("b6a076"));add_child(bolt)
			bolt.position=p+Vector3(x,y,.063);bolt.rotation.x=PI/2
		shapes.rounded_detail(p+Vector3(x,.15,0),Vector3(.12,.3,.3),Color("94745a"),.025)
	for i in 7: shapes.detail(p+Vector3(-width*.35+i*.045,.16,.055),Vector3(.024,.095,.01),Color("304748"))

func control(p: Vector3, text: String, action: String, index: int, key = ""):
	var group = Node3D.new()
	add_child(group)
	group.position = p
	var ring = shapes.ring(Vector3(0,0,0),0.18,0.032,Color("c9aa6d"),group)
	ring.rotation.x = PI/2
	for collider in ring.find_children("*","StaticBody3D",true,false): collider.collision_layer=0
	shapes.rounded_detail(Vector3(0,.08,.06),Vector3(.035,.19,.045),Color("ede5d1"),.012,group)
	for i in 4:
		var angle=i*PI/2
		shapes.detail(Vector3(sin(angle)*.224,cos(angle)*.224,.012),Vector3(.025,.035,.012),Color("e2d6b2"),group)
	var hub=shapes.rounded_detail(Vector3(0,0,.045),Vector3(.09,.09,.09),Color("8b745d"),.03,group)
	garden.pick(p+Vector3(0,0,.15),Vector3(.45,.45,.3),"puzzle",action+":"+str(index),text)
	if key != "": visuals[key+str(index)] = group
	return group
func note(p: Vector3, key: String, approach: Vector3):
	var board=Node3D.new();board.name="Maintenance_"+key;add_child(board)
	board.position=p
	var facing=(approach-p);facing.y=0
	board.rotation.y=atan2(facing.x,facing.z)
	# Keep roadside clues below eye height, with their feet outside the route.
	board.scale=Vector3.ONE*.68
	board.set_meta("reading_position",approach+Vector3(0,.055,0))
	record_boards[key]=board
	load("res://scripts/weathered_stele.gd").new().build(board,shapes,key)
	record_text(board,"Code",Vector3(0,1.66,.131),RECORD_FACES[key][0],21,.0018)
	record_text(board,"Title",Vector3(0,1.52,.131),NOTES[key].split("\n")[0],27,.0018)
	var body=record_text(board,"Body",Vector3(-.47,1.25,.131),RECORD_FACES[key][1],38,.0018)
	body.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	record_text(board,"ReadPrompt",Vector3(.08,.91,.131),"……余文漫漶……",18,.0018)
	# Parenting the hit area makes its size and facing follow the actual stone.
	var target=garden.pick(Vector3.ZERO,Vector3(1.25,1.30,.28),"inspect",key,"辨认残碑 · "+NOTES[key].split("\n")[0])
	target.reparent(board,false);target.name="InscriptionTarget"
	target.position=Vector3(0,1.25,.07)
	board.set_meta("reading_target",board.to_global(Vector3(0,1.25,.131)))
	return board

func record_text(parent: Node3D,node_name: String,p: Vector3,text: String,size: int,pixel: float) -> Label3D:
	var printed=Label3D.new();printed.name=node_name;parent.add_child(printed)
	# Authoring/layout markers; the visible strokes are cut into the stone PBR
	# material from the matching depth masks, rather than drawn as Label3D ink.
	printed.visible=false
	printed.position=p;printed.text=text;printed.font=preload("res://assets/stele_font.tres")
	printed.font_size=size;printed.pixel_size=pixel;printed.modulate=Color("59564a")
	printed.shaded=true;printed.outline_size=1;printed.outline_modulate=Color("b2aa90")
	printed.double_sided=false;printed.line_spacing=9
	return printed
func pipe(a: Vector3,b: Vector3,radius: float,color: Color) -> MeshInstance3D:
	var mesh = CylinderMesh.new()
	mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=a.distance_to(b);mesh.radial_segments=24
	var n = MeshInstance3D.new();n.mesh=mesh;n.material_override=shapes.material(color)
	add_child(n);n.position=(a+b)/2
	if a.distance_to(b)>.001: n.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	if radius>.045:
		for sign_value in [-1,1]:
			var flange_mesh=CylinderMesh.new();flange_mesh.top_radius=radius*1.36;flange_mesh.bottom_radius=radius*1.36;flange_mesh.height=radius*.45;flange_mesh.radial_segments=24
			var flange=MeshInstance3D.new();flange.mesh=flange_mesh;flange.material_override=shapes.material(Color("8b745d"));n.add_child(flange)
			flange.position.y=sign_value*(mesh.height/2-radius*.32)
	return n
func build():
	match Journey.chapter:
		0: water()
		1: sun()
		2: life()
	# Replace collectible shortcuts with readable results that only become available after solving.
	for body in garden.pickables:
		if body.get_meta("action") == "memory" and int(body.get_meta("id"))%4 != 0:
			body.set_meta("action","result")
			body.set_meta("text","查看这段机关留下的回信")
	var light = OmniLight3D.new()
	light.position = garden.nodes.arrival+Vector3(0,2.5,1)
	light.light_color = Color("edd9ad");light.light_energy=.65;light.omni_range=7
	add_child(light)
	worksite=load("res://scripts/worksite_details.gd").new(garden)
	add_child(worksite);worksite.build()
	refresh()
func water():
	var p: Vector3 = garden.nodes.landing+Vector3(0,0,1.13)
	var console_parts=get_children()
	var first_pick=garden.pickables.size()
	cabinet(p,"W-01")
	for i in 3:
		var pos = p+Vector3(-.8+i*.8,.72,.15)
		control(pos,"旋转第 %d 个管道接头"%(i+1),"pipe",i,"pipes")
		labels["pipes"+str(i)] = label(pos+Vector3(0,-.37,.1),"",18)
		pipe(pos+Vector3(-.3,0,-.08),pos+Vector3(.3,0,-.08),.065,Color("b3c9b8"))
		water_segments.append(pipe(pos+Vector3(-.3,.2,-.06),pos+Vector3(.3,.2,-.06),.022,Color("8ac6bd")))
		leaks.append(pipe(pos+Vector3(0,-.13,.08),pos+Vector3(0,-.55,.08),.025,Color(.68,.82,.8,.45)))
	# The operator stands on the landing, not beyond its seaward edge.
	face_console(self,p,get_children().filter(func(n):return n not in console_parts)+garden.pickables.slice(first_pick),"W01InwardFacing")
	note(garden.nodes.arrival+Vector3(-1.05,0,1.08),"route",garden.nodes.arrival+Vector3(-.45,0,.45))
	p = garden.nodes.spring+Vector3(1.25,0,.20)
	console_parts=get_children();first_pick=garden.pickables.size()
	cabinet(p,"W-02",1.9)
	for i in 2:
		control(p+Vector3(-.5+i,.7,.17),"调整"+("入水阀" if i==0 else "回流阀"),"valve",i,"valves")
		labels["valves"+str(i)] = label(p+Vector3(-.5+i,.35,.28),"",18)
	labels.gauge=label(p+Vector3(0,1.13,.21),"水位 0 / 目标 Ⅲ",19)
	face_console(self,p,get_children().filter(func(n):return n not in console_parts)+garden.pickables.slice(first_pick),"W02InwardFacing",-PI/2)
	note(garden.nodes.spring+Vector3(-1.22,0,.65),"pressure",garden.nodes.spring+Vector3(-.40,0,.30))
	var dock = robot_dock("pump")[1]
	shapes.detail(dock+Vector3(0,.03,0),Vector3(.6,.06,.65),Color("8b745d"))
	label(dock+Vector3(0,.45,0),"○—○",16)
	garden.pick(dock+Vector3(0,.2,0),Vector3(.65,.4,.65),"robot","pump","派芽芽守住供电踏板")
	# A compact pump room frames the chapter mechanism rather than another pavilion.
	var room: Vector3 = garden.nodes.altar
	shapes.detail(room+Vector3(0,1.25,-1.65),Vector3(3.9,2.5,.28),Color("c3beb0"))
	for x in [-1.7,1.7]: shapes.detail(room+Vector3(x,1.1,-.8),Vector3(.26,2.2,1.7),Color("a59e8c"))
	pipe(room+Vector3(-1,.25,-1.2),room+Vector3(-1,1.5,-1.2),.17,Color("8b745d"))
	label(room+Vector3(0,2.35,-1.47),"P-01",21)
func face_console(parent: Node3D,pivot: Vector3,parts: Array,console_name: String,facing=PI) -> Node3D:
	# Keep dials' local Z rotation independent of the cabinet's facing.
	var frame=Node3D.new();frame.name=console_name;parent.add_child(frame)
	frame.position=pivot;frame.rotation.y=facing
	for part in parts:
		part.reparent(frame,false)
		part.position-=pivot
	return frame
func sun():
	var p: Vector3 = garden.nodes.arrival+Vector3(0,0,1.12)
	var console_parts=get_children()
	var first_pick=garden.pickables.size()
	cabinet(p,"MODULES",2.3)
	for i in 3:
		module_shape(p+Vector3(-.7+i*.7,.78,.17),i)
		garden.pick(p+Vector3(-.7+i*.7,.7,.3),Vector3(.5,.6,.3),"puzzle","take_fuse:"+str(i),"拿取"+["圆形","三角","方形"][i]+"模块")
	face_console(self,p,get_children().filter(func(n):return n not in console_parts)+garden.pickables.slice(first_pick),"ModulesInwardFacing")
	var board: Vector3 = garden.nodes.landing+Vector3(0,0,1.2)
	console_parts=get_children()
	first_pick=garden.pickables.size()
	cabinet(board,"S-01")
	for i in 3:
		control(board+Vector3(-.8+i*.8,.65,.16),"安装 / 取回插槽 %d 模块"%(i+1),"slot",i)
		labels["fuses"+str(i)]=label(board+Vector3(-.8+i*.8,1.06,.18),["□","○","△"][i],26)
	# Both racks present their shape clues and interactions to safe standing space.
	face_console(self,board,get_children().filter(func(n):return n not in console_parts)+garden.pickables.slice(first_pick),"S01InwardFacing")
	note(garden.nodes.landing+Vector3(1.25,0,-.35),"power",garden.nodes.landing+Vector3(.40,0,-.15))
	relay_position=garden.nodes.lift_high+Vector3(2,1.6,-.65)
	var relay_plate=shapes.detail(relay_position,Vector3(.48,.48,.08),Color("c9aa6d"))
	relay_plate.rotation.y=PI/2
	
	for i in 2:
		var base: Vector3 = garden.nodes.lift_high if i==0 else garden.nodes.sun
		var pos = base+(Vector3(-.85,1.18,-.65) if i==0 else Vector3(1.1,1.18,0))
		var mirror = shapes.detail(pos,Vector3(.72,.95,.07),Color("ccd6d4"))
		var m = shapes.material(Color("a3c4c0"));m.metallic=.75;m.roughness=.15
		mirror.material_override=m
		visuals["mirrors"+str(i)]=mirror
		console_parts=get_children();first_pick=garden.pickables.size()
		control(base+Vector3(.1,.8,1.05),"调整第 %d 面日光镜"%(i+1),"mirror",i)
		labels["mirrors"+str(i)]=label(base+Vector3(.1,1.1,1.15),"",20)
		face_console(self,base+Vector3(.1,0,1.05),get_children().filter(func(n):return n not in console_parts)+garden.pickables.slice(first_pick),"Mirror%dInwardFacing"%i)
		beams.append(pipe(pos,pos+Vector3(0,0,1.4),.025,Color(1,.86,.6,.26)))
		var lamp = OmniLight3D.new();lamp.position=pos;lamp.light_energy=.4;lamp.light_color=Color("ecd8a6");lamp.omni_range=3
		add_child(lamp)
	beams.append(pipe(garden.nodes.sun,garden.nodes.sun+Vector3(0,1,0),.025,Color(1,.86,.6,.26)))
	for beam in beams:
		beam.material_override.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		beam.material_override.emission_enabled=true
		beam.material_override.emission=Color(1,.86,.6)
		beam.material_override.emission_energy_multiplier=.4
	note(garden.nodes.lift_high+Vector3(0,0,-1.0),"mirrors",garden.nodes.lift_high+Vector3(0,0,-.15))
	var dock = robot_dock("roof")[1]
	shapes.detail(dock+Vector3(0,.04,0),Vector3(.6,.08,.6),Color("957b69"))
	label(dock+Vector3(0,.5,0),"○—○",16)
	garden.pick(dock+Vector3(0,.3,.1),Vector3(.65,.6,.5),"robot","roof","派芽芽保持镜架制动")
	# Workbench, seed drawers and a relay plate at reachable eye height.
	shapes.detail(garden.nodes.sun+Vector3(0,.3,-1.35),Vector3(2.8,.6,.6),Color("8b745d"))
	label(garden.nodes.sun+Vector3(0,2.1,-1.2),"L-02",19)
func module_shape(pos: Vector3, kind: int):
	var mesh: Mesh
	if kind == 0:
		var cylinder=CylinderMesh.new();cylinder.top_radius=.14;cylinder.bottom_radius=.14;cylinder.height=.09;mesh=cylinder
	elif kind == 1:
		var cylinder=CylinderMesh.new();cylinder.top_radius=.17;cylinder.bottom_radius=.17;cylinder.height=.09;cylinder.radial_segments=3;mesh=cylinder
	else:
		var box=BoxMesh.new();box.size=Vector3(.27,.09,.27);mesh=box
	var n=MeshInstance3D.new();n.mesh=mesh;n.material_override=shapes.material(Color("d2b87e"));add_child(n);n.position=pos;n.rotation.x=PI/2
func life():
	# Leave both the arrival stairs and the onward bridge clear of the supply rack.
	var p: Vector3 = garden.nodes.landing+Vector3(-1.1,0,0)
	var console_parts=get_children();var first_pick=garden.pickables.size()
	cabinet(p,"SEEDS",2.3)
	for i in 3:
		var plant=shapes.plant(p+Vector3(-.75+i*.75,.75,.1),.42,i)
		garden.pick(p+Vector3(-.75+i*.75,.9,.2),Vector3(.55,.8,.4),"puzzle","take_plant:"+str(i),"带上"+["花卉","豆科","深根植物"][i])
		label(p+Vector3(-.75+i*.75,.43,.28),["花卉","豆科","深根"][i],16)
	face_console(self,p,get_children().filter(func(n):return n not in console_parts)+garden.pickables.slice(first_pick),"SeedsInwardFacing",PI/2)
	note(garden.nodes.landing+Vector3(1.08,0,0),"beds",garden.nodes.landing+Vector3(.23,0,0))
	for i in 3:
		var base: Vector3 = garden.nodes[["west","east","north"][i]]
		garden.pick(garden.planting_position(i)+Vector3(0,.75,0),Vector3(.42,.5,.42),"puzzle","bed:"+str(i),"种植 / 取回"+["西床","东床","北床"][i]+"植物")
		var empty = Node3D.new();add_child(empty);plants.append(empty)
		var pos=base+Vector3(.65,.85,.8)
		console_parts=get_children();first_pick=garden.pickables.size()
		control(pos,"调整"+["西床","东床","北床"][i]+"分水器","irrigate",i,"irrigation")
		labels["irrigation"+str(i)]=label(pos+Vector3(0,.32,.1),"",17)
		face_console(self,base+Vector3(.65,0,.8),get_children().filter(func(n):return n not in console_parts)+garden.pickables.slice(first_pick),"Irrigation%dInwardFacing"%i,atan2(-.65,-.8))
		labels["beds"+str(i)]=label(base+Vector3(-.75,1,.75),["访客 / Ⅰ","养分 / Ⅱ","深水 / Ⅲ"][i],18)
		labels["beds"+str(i)].rotation.y=atan2(.75,-.75)
	var top: Vector3 = garden.nodes.summit
	p=top+Vector3(1.55,0,0)
	console_parts=get_children();first_pick=garden.pickables.size()
	cabinet(p,"L-03")
	for i in 2:
		control(p+Vector3(-.65+i*1.3,.78,.2),"旋转"+("左" if i==0 else "右")+"根系接头","root",i,"roots")
		labels["roots"+str(i)]=label(p+Vector3(-.65+i*1.3,.38,.3),"",18)
	control(p+Vector3(0,1,.2),"启动风塔","life",0)
	label(p+Vector3(0,1.22,.3),"启动",17)
	face_console(self,p,get_children().filter(func(n):return n not in console_parts)+garden.pickables.slice(first_pick),"RootsInwardFacing",-PI/2)
	note(top+Vector3(-1.55,0,-.3),"roots",top+Vector3(-.70,0,-.15))
	turbine=Node3D.new();add_child(turbine);turbine.position=top+Vector3(1.7,3,-1.6)
	pipe(top+Vector3(1.7,0,-1.6),turbine.position,.07,Color("8b745d"))
	for i in 3:
		var blade=shapes.detail(Vector3(.6,0,0),Vector3(1.2,.13,.08),Color("abc2b6"),turbine)
		blade.position=Vector3(cos(i*TAU/3)*.6,sin(i*TAU/3)*.6,0);blade.rotation.z=i*TAU/3
	battery_model=shapes.detail(garden.nodes.landing+Vector3(-1,.4,-.5),Vector3(.4,.6,.3),Color("c9aa6d"))
	label(top+Vector3(1.2,1.85,-.5),"储能接口 · C",18)
func robot_dock(task: String) -> Array:
	match task:
		"pump": return ["spring",garden.nodes.get("spring",garden.nodes.arrival)+Vector3(-.55,0,-.55)]
		"roof": return ["lift_high",garden.nodes.get("lift_high",garden.nodes.arrival)+Vector3(-.5,0,.5)]
		"battery": return ["summit",garden.nodes.get("summit",garden.nodes.arrival)+Vector3(.55,0,-.4)]
	return ["arrival",garden.nodes.arrival]
func refresh(animate = false):
	var directions=["↑ N","→ E","↓ S","← W"]
	for key in ["pipes","valves","mirrors","irrigation","roots"]:
		for i in Puzzles.data[key].size():
			var id=key+str(i);var value=int(Puzzles.data[key][i])
			if id in visuals:
				var axis="rotation:y" if key=="mirrors" else "rotation:z"
				var angle=value*PI/4 if key=="mirrors" else -value*PI/2
				var node: Node3D=visuals[id]
				if node.get_meta("gear",-1)!=value:
					node.set_meta("gear",value)
					if id in turns and turns[id].is_valid():turns[id].kill()
					if animate:
						# Choose the adjacent angular turn when a gear wraps through zero.
						var initial=float(node.get_indexed(axis))
						if key!="mirrors":angle=initial+wrapf(angle-initial,-PI,PI)
						var tween=create_tween();turns[id]=tween
						tween.tween_property(node,axis,angle,.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					else:node.set_indexed(axis,angle)
			if id in labels:
				labels[id].font_size=18
				labels[id].pixel_size=.007
				labels[id].text="%02d %s"%[value,directions[value]] if key in ["pipes","mirrors","roots"] else "%02d"%value
				if key=="irrigation":labels[id].text+="\n"+("↓" if value<i+1 else "↑" if value>i+1 else "—")
	if "gauge" in labels:
		var level=int(Puzzles.data.valves[0])*2-int(Puzzles.data.valves[1])
		labels.gauge.text="%02d / Ⅲ\n%s"%[maxi(0,level),"○" if not Puzzles.done("water_route") else "↓" if level<3 else "↑" if level>3 else "—"]
	for i in water_segments.size():
		water_segments[i].visible=Puzzles.data.pipes.slice(0,i+1)==[1,3,2].slice(0,i+1)
		leaks[i].visible=not water_segments[i].visible
	if beams.size()==3:
		var first: Vector3 = visuals.mirrors0.position
		var second: Vector3 = visuals.mirrors1.position
		var relay = relay_position
		var first_ok = Puzzles.data.mirrors[0]==1
		var second_ok = Puzzles.data.mirrors[1]==3
		var end0 = relay if first_ok else first+Vector3(sin(Puzzles.data.mirrors[0]*PI/2)*3,0,-cos(Puzzles.data.mirrors[0]*PI/2)*3)
		var end2 = garden.nodes.sun+Vector3(0,.5,0) if second_ok else second+Vector3(sin(Puzzles.data.mirrors[1]*PI/2)*3,0,-cos(Puzzles.data.mirrors[1]*PI/2)*3)
		var lines = [[first,end0],[relay,second],[second,end2]]
		for i in 3:
			beams[i].visible=Puzzles.done("power") and (i==0 or first_ok)
			var a: Vector3 = lines[i][0];var b: Vector3 = lines[i][1]
			beams[i].mesh.height=a.distance_to(b)
			beams[i].position=(a+b)/2
			beams[i].quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	for i in plants.size():
		var kind=int(Puzzles.data.beds[i])
		if kind!=plant_kinds[i]:
			plants[i].queue_free()
			plants[i]=shapes.plant(garden.planting_position(i)+Vector3(0,.5,0),.8,maxi(0,kind))
			plant_kinds[i]=kind
			if is_instance_valid(garden.wind_field):garden.wind_field.register_foliage(plants[i])
		plants[i].visible=kind>=0
		plants[i].scale=Vector3.ONE*(.95 if Puzzles.done("irrigation") else .7 if kind==i else .4)
		if "beds"+str(i) in labels:
			labels["beds"+str(i)].text=["访客 / Ⅰ","养分 / Ⅱ","深水 / Ⅲ"][i]
	for i in 3:
		if "fuses"+str(i) in labels: labels["fuses"+str(i)].text=["□","○","△"][i]+"\n"+("—" if Puzzles.data.fuses[i]<0 else ["○","△","□"][Puzzles.data.fuses[i]])
	if battery_model: battery_model.visible=not Puzzles.data.battery and not Puzzles.data.robot_cargo
	if is_instance_valid(worksite):worksite.refresh()
func _process(delta):
	if turbine and Puzzles.done("life") and garden.playing and not garden.ui.panel_open(): turbine.rotation.z+=delta*.65
