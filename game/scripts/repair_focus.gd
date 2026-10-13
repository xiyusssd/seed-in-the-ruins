extends Node
# A short authored reveal uses only the camera; the saved player never moves.
var garden: Node3D
var active=false
var task=""
var queue: Array[String]=[]
var clock=0.0
var hold_time=1.6
var original: Transform3D
var destination: Transform3D
var original_fov=76.0
var banner: Control
var heading: Label
var copy: Label
var allow_verification=false
const RESULTS={
"water_route":"接头停止漏水，清水沿着修好的管道前进。",
"pressure":"蓄水池水位上升，滤池的回流稳定下来。",
"pump":"水流越过泵房，第一片绿意回到岸边。",
"power":"旧工作灯亮起，温室重新有了温暖的光。",
"mirrors":"日光抵达育苗台，幼苗向着光展开叶子。",
"roof":"屋顶向两侧打开，阳光穿过玻璃与新生的叶子。",
"planting":"三处种植床长出不同的叶子与花。",
"irrigation":"细流进入花床，新的绿叶和花朵慢慢展开。",
"life":"风塔开始转动，花园的绿意延伸到旧拱廊。"}
func _init(world):garden=world;name="RepairFocus"
func _ready():
	var layer=CanvasLayer.new();layer.layer=24;add_child(layer)
	banner=PanelContainer.new();banner.name="RepairReveal";layer.add_child(banner)
	banner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	banner.offset_left=24;banner.offset_right=-24;banner.offset_top=-130;banner.offset_bottom=-24
	banner.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style=StyleBoxFlat.new();style.bg_color=Color(.06,.10,.09,.91);style.border_color=Color("b99c62")
	style.border_width_left=3;style.content_margin_left=20;style.content_margin_right=20;style.content_margin_top=12;style.content_margin_bottom=12
	banner.add_theme_stylebox_override("panel",style)
	var col=VBoxContainer.new();banner.add_child(col)
	heading=Label.new();heading.add_theme_font_override("font",load("res://assets/control_font.tres"));heading.add_theme_font_size_override("font_size",22);heading.add_theme_color_override("font_color",Color("e4cd9c"));col.add_child(heading)
	copy=Label.new();copy.add_theme_font_override("font",load("res://assets/body_font.tres"));copy.add_theme_font_size_override("font_size",17);copy.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;col.add_child(copy)
	banner.visible=false
func pending(id: String) -> bool:return (active and id==task) or id in queue
func notify(id: String):
	if id not in Puzzles.TASKS[Journey.chapter] or pending(id):return
	if garden.capture or not garden.playing or not garden.ui or garden.ui.panel_open():return
	if (DisplayServer.get_name()=="headless" or Settings.verification()) and not allow_verification:return
	queue.append(id)
	if garden.restoration:garden.restoration.set_amount(id,0)
func view_for(id: String) -> Array:
	match id:
		"water_route":return [Vector3(-3,4.75,3.95),Vector3(-3,3.82,5.92)]
		"pressure":return [Vector3(3.8,5.35,-.5),Vector3(-.15,3.2,-3.7)]
		"pump":return [Vector3(6,4.2,6.2),Vector3(0,2.35,-1.2)]
		"power":return [Vector3(-8.6,4.0,1.2),Vector3(-1,7,-2)]
		"mirrors":return [Vector3(6.15,9.2,2.65),Vector3(6,7.85,-1.1)]
		"roof":return [Vector3(9.3,9.0,5.8),Vector3(5.5,9.1,-.4)]
		"planting":return [Vector3(0,13,8.5),Vector3(0,6.7,-1.4)]
		"irrigation":return [Vector3(5,8.5,3.25),Vector3(5,6.7,-.2)]
		_:return [Vector3(-3.4,10.5,-9.6),Vector3(0,9.7,-10)]
func begin(id: String):
	active=true;task=id;clock=0;garden.avatar.position=garden.walker.position
	original=garden.camera.global_transform;original_fov=garden.camera.fov
	var view=view_for(id)
	destination=Transform3D(Basis.IDENTITY,view[0]).looking_at(view[1])
	hold_time=2.2 if id in ["roof","life"] else 1.6
	garden.busy=true;garden.hovered=null
	heading.text="✓ "+Puzzles.NAMES[id]+"    ·    Esc 返回菜单"
	copy.text=RESULTS[id];banner.visible=true
	if id=="roof":garden.soundscape.effect("roof",garden.nodes.sun,-18)
func advance(delta: float):
	if (active or not queue.is_empty()) and (not garden.playing or garden.capture or garden.ui.panel_open()):cancel();return
	if not active:
		if queue.is_empty() or garden.busy:return
		begin(queue.pop_front())
	clock+=delta
	var travel=.65;var departure=travel+hold_time;var end=departure+travel
	var blend=1.0
	if clock<travel:blend=smoothstep(0.0,travel,clock)
	elif clock>departure:blend=1.0-smoothstep(departure,end,clock)
	garden.camera.global_transform=original.interpolate_with(destination,blend)
	garden.camera.fov=lerpf(original_fov,58.0,blend)
	if garden.restoration:garden.restoration.set_amount(task,smoothstep(travel,travel+1.4,clock))
	if clock>=end:finish()
func finish():
	if not active:return
	if garden.restoration:garden.restoration.set_amount(task,1)
	garden.camera.global_transform=original;garden.camera.fov=original_fov
	active=false;garden.busy=false;banner.visible=false
	garden.sync_mouse_capture()
func cancel():
	finish()
	if garden.restoration:
		for id in queue:garden.restoration.set_amount(id,1)
	queue.clear()
func _process(delta):advance(delta)
