extends Node
# Teaches real controls while the player repairs the original first chapter.
var garden: Node3D
var suppressed=false
var origin=Vector3.ZERO
var stage=""
var target: Node3D
var view: Control
var card: PanelContainer
var title: Label
var body: Label
var keys: Label
var feedback: Label
var layer: CanvasLayer
func _init(world):garden=world
func _ready():
	layer=CanvasLayer.new();layer.layer=23;add_child(layer)
	view=Control.new();view.name="FieldTutorial";view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);view.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(view)
	view.draw.connect(draw_target)
	card=PanelContainer.new();card.name="TutorialCard";card.mouse_filter=Control.MOUSE_FILTER_IGNORE;view.add_child(card)
	var style=StyleBoxFlat.new();style.bg_color=Color(.08,.12,.10,.93);style.border_color=Color("ae9162");style.border_width_left=2
	style.content_margin_left=18;style.content_margin_right=18;style.content_margin_top=14;style.content_margin_bottom=14
	card.add_theme_stylebox_override("panel",style)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",6);column.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(column)
	for i in 4:
		var text=Label.new();text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.mouse_filter=Control.MOUSE_FILTER_IGNORE
		text.add_theme_font_override("font",load("res://assets/control_font.tres" if i==0 else "res://assets/telemetry_font.tres" if i==2 else "res://assets/body_font.tres"))
		text.add_theme_font_size_override("font_size",17 if i<2 else 13)
		text.add_theme_color_override("font_color",Color("c3a164") if i==2 else Color("e6ddc8") if i<2 else Color("b7b09c"))
		column.add_child(text)
		if i==0:title=text
		elif i==1:body=text
		elif i==2:keys=text
		else:feedback=text
	configure()
func configure():
	if garden.walker:origin=garden.walker.position
	stage="";target=null
	# Old saves that already repaired machinery do not repeat basic movement.
	if Puzzles.data.solved.size()>0 or Puzzles.data.records.size()>0:
		for skill in ["move","look"]:
			if skill not in Journey.tutorial_steps:Journey.tutorial_steps.append(skill)
	poll()
func learn(skill: String):
	if Journey.chapter!=0 or skill in Journey.tutorial_steps:return
	Journey.tutorial_steps.append(skill);Journey.save_journey()
func observe_interaction(action: String,id: String):
	if action in ["memory","inspect"]:learn("inspect")
	if action=="puzzle":
		learn("operate")
		if "_back:" in id:learn("reverse")
	if action=="robot":learn("partner")
func find_target(action: String,id="") -> Node3D:
	for node in garden.pickables:
		if node.get_meta("action")==action and (id=="" or str(node.get_meta("id"))==id):return node
	return null
func poll():
	if not is_instance_valid(view):return
	view.visible=Journey.chapter==0 and garden.playing and not garden.ui.panel_open() and not suppressed and not (garden.repair_focus and garden.repair_focus.active)
	if not view.visible:return
	if garden.walker.position.distance_to(origin)>.65:learn("move")
	var heading="";var text="";var controls="";target=null
	if not ("move" in Journey.tutorial_steps and "look" in Journey.tutorial_steps) and "operate" not in Journey.tutorial_steps and Puzzles.data.records.is_empty():
		stage="movement";heading="先认识这座泵站"
		text="沿码头走几步，再看看四周。芽芽带来的信就在身旁。"
		controls="W A S D  行走     鼠标  环顾     Esc  菜单"
		target=find_target("memory","0")
	elif 0 not in Journey.memories and not Puzzles.done("water_route") and Puzzles.data.records.is_empty() and "operate" not in Journey.tutorial_steps:
		stage="letter";heading="走近芽芽留下的信"
		text="把准星对准旧纸页，靠近后读一读。旧城会随着你找到的来信慢慢恢复颜色。"
		controls="E / 左键  调查     Tab  查阅已收录的来信"
		target=find_target("memory","0")
	elif not Puzzles.done("water_route"):
		stage="route";heading="修复桥边的水路"
		if "route" not in Puzzles.data.records:
			text="码头入口有一份旧记录。先看看水曾经怎样穿过这些装置。"
			controls="E / 左键  读取维护记录";target=find_target("inspect","route")
		else:
			text="沿入口桥走上平台，转身看朝向平台内侧的 W-01。对照记录调整三个接头，观察管道和水流的变化。"
			controls="E  顺转一档     F  反转一档     Tab  复查记录"
			for i in 3:
				if Puzzles.data.pipes[i]!=[1,3,2][i]:target=find_target("puzzle","pipe:%d"%i);break
	elif not Puzzles.done("pressure") and Journey.bridge==0:
		stage="bridge";heading="让长桥接上另一岸"
		text="水路已接通。走到桥中央的轮柄旁，再让长桥转向滤池。"
		controls="E / 左键  转动轮柄";target=find_target("bridge")
	elif not Puzzles.done("pressure"):
		stage="pressure";heading="让水位稳下来"
		if "pressure" not in Puzzles.data.records:
			text="穿过长桥，到滤池旁读检修单。留意墙上的刻痕和仪表。"
			controls="W A S D  过桥     E  读取检修单";target=find_target("inspect","pressure")
		else:
			text="两个阀门共同影响水位。观察指针与刻痕，调整后可以随时反向转回。"
			controls="E  顺转     F  反转     Tab  复查记录"
			for i in 2:
				if Puzzles.data.valves[i]!=[2,1][i]:target=find_target("puzzle","valve:%d"%i);break
	elif not Puzzles.done("pump"):
		stage="partner";heading="这一次需要两位伙伴"
		if not garden.companion.ready_for("pump"):
			text="芽芽可以守住供电踏板。派它协助，然后沿阶梯走到泵房。"
			controls="C  芽芽 → 协助：守住供电踏板";target=find_target("robot","pump")
		else:
			text="芽芽已经守住踏板。沿阶梯走进泵房，启动那台沉默的水泵。"
			controls="E / 左键  启动水泵";target=find_target("water")
	else:
		stage="complete";heading="第一滴水回来了"
		text="你已经学会观察、调查、调节机关和与芽芽协作。可以留在这里看看，或前往温室。"
		controls="Esc  菜单 → 前往下一章     Tab  查阅来信"
	title.text=heading;body.text=text;keys.text=controls
	var last=garden.ui.feedback_log[-1] if not garden.ui.feedback_log.is_empty() else ""
	feedback.text=last.split("\n")[0] if stage not in ["movement","letter","complete"] else ""
	feedback.visible=feedback.text!=""
	var width=minf(510,view.size.x-48)
	card.size=Vector2(width,0);card.position=Vector2(24,view.size.y-card.get_combined_minimum_size().y-24)
	view.queue_redraw()
func draw_target():
	if not view.visible or not is_instance_valid(target):return
	var point=target.global_position+Vector3(0,.28,0)
	var screen=garden.camera.unproject_position(point)
	if garden.camera.is_position_behind(point) or not Rect2(Vector2(18,18),view.size-Vector2(36,36)).has_point(screen):
		var right=garden.camera.to_local(point).x>=0
		var tip=Vector2(view.size.x-18 if right else 18,view.size.y*.46)
		var sign_value=1 if right else -1
		view.draw_colored_polygon(PackedVector2Array([tip,tip+Vector2(-sign_value*8,-6),tip+Vector2(-sign_value*8,6)]),Color("c3a164"))
		return
	if card.get_rect().has_point(screen):return
	view.draw_arc(screen,9,0,TAU,32,Color("c3a164"),1.4,true)
	view.draw_line(screen+Vector2(0,12),screen+Vector2(0,19),Color("c3a164"),1.2,true)
func _process(_delta):poll()
