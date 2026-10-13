extends CanvasLayer
const TITLE_FONT = preload("res://assets/title_font.tres")
const CINEMATIC_TITLE_FONT = preload("res://assets/cinematic_title_font.tres")
const STORY_FONT = preload("res://assets/story_font.tres")
const CONTROL_FONT = preload("res://assets/control_font.tres")
const TELEMETRY_FONT = preload("res://assets/telemetry_font.tres")
const StoryVignette = preload("res://scripts/story_vignette.gd")
const WastelandPanel = preload("res://scripts/wasteland_panel.gd")
const WastelandButton = preload("res://scripts/wasteland_button.gd")
const TECH = Color("99b4aa")
const PAPER = Color("b6a482")
const PAPER_INK = Color("2f3027")
const BRASS = Color("c3a164")
const INK = Color("e6ddc8")
const LIGHT = Color("eee3c8")
const MUTED = Color("b7b09c")
const SHORT_MEMORIES = [
  [
    "一封没有地址的信",
    "她走的时候，把种子留在了窗边。\n纸上只写着一句：\n如果你路过，替我给它一点水。"
  ],
  [
    "河流也会想念弯道",
    "他们把河修得笔直，像一道命令。\n水匆匆赶路，蜻蜓找不到落脚的地方。\n岸边的泥土，也一点点跟着走了。"
  ],
  [
    "地图上空白的地方",
    "旧地图把这片湿地涂成了空白。\n可雨来的时候，水总会回到这里。\n它记得，这里曾经有一个家。"
  ],
  [
    "根的第一封回信",
    "过滤器旁，她种了一小丛芦苇。\n机器留住沙，根留住土地。\n风吹过来，两种声音轻轻合在一起。"
  ],
  [
    "忘记晚安的城",
    "城市的灯越来越亮。\n人们说，再亮一点，就会更好。\n后来，连窗边的小花也忘了怎样入睡。"
  ],
  [
    "最后一位观众",
    "广告屏还在向空座位问好。\n它说，明天一定更好。\n墙缝里的叶子没有回答，只往亮处伸了伸。"
  ],
  [
    "一小块天空",
    "屋顶生了锈，天空却没有离开。\n那株植物等了很久。\n只要把缝隙打开一点，它就会认出太阳。"
  ],
  [
    "让一盏灯休息",
    "她关掉了最后一盏灯。\n不是因为放弃了这座城。\n是因为清晨已经到了，有些光不用制造。"
  ],
  [
    "整齐的花盆",
    "所有花盆，都种着同一种植物。\n它们长得一样高，也在同一天低下了头。\n角落里的杂草，独自等到了下一场雨。"
  ],
  [
    "留一朵不赶时间的花",
    "这朵花长得很慢。\n可一只小虫，在它身上歇了一整个下午。\n那一天，这里并不空。"
  ],
  [
    "一起过冬的办法",
    "花留住访客，豆科养着土地。\n深深的根，把水藏到更远的地方。\n它们不必长成一样，才可以一起生活。"
  ],
  [
    "写给还没来的人",
    "如果你读到了这里，\n请给陌生的叶子留一点地方。\n也许下一次春天，会有我们没见过的颜色。"
  ]
]
const CHAPTER_NAMES = ["第一章 · 水还记得路", "第二章 · 给叶子一片天空", "第三章 · 春天有许多种模样"]
const REPAIR_NOTES=[
	"种子盒还在。替这封信找一个春天。",
	"过滤 → 蓄水 → 回流；桥梁制动已解除。",
	"稳定的水位，给第一滴水留出了时间。",
	"你守着水泵，芽芽守着踏板。土地重新接到了水。",
	"玻璃裂了，清晨仍然可以抵达这里。",
	"电源接通。那些沉默的装置重新有了回应。",
	"中继板把光送到了叶子身上。",
	"屋顶让开。机器第一次替一片叶子留出了天空。",
	"这里需要的不是一样的花盆，而是不一样的生命。",
	"花、豆叶和深根，各自找到了合适的土地。",
	"水没有流向同一个地方；每一株都接到了需要的份量。",
	"根系、储能与风塔接通。春天开始自己运转。"
]
const CHAPTER_PROSE = [
	"水已经绕过这里很久。
芽芽把最后一枚种子背在身后。

不用修好整座城。
先替种子留一滴水。",
	"裂开的玻璃，仍替一片叶子挡着雨。
它一直在等光。

这一次，清晨从你们手里回来。",
	"花卉等访客，豆叶等贫土，深根等水。
它们不必长成一样。

给春天留一个家，或一条路。"
]
const PROLOGUE = [
	["潮水留下的线", "水离开以后，旧城还留着它的去向。", "河流曾在这里拐弯，海风穿过阳台。后来河道被拉直，温室封住窗，维护网络也停了。\n\n潮退时，滤池留下细沙，蓄水槽仍清得见底。泵站墙上的旧水痕，停在三道短刻线之间。\n\n居民离开了，那些痕迹没有。风沿着空窗穿过，像有人还在翻一页旧记录。"],
	["最后一枚种子", "芽芽记住的，是她离开前的那个清晨。", "温室管理员离开前，把最后一枚种子交给芽芽，托这个小机器人守着一份没有收件人的礼物。\n\n多年过去，芽芽仍会在旧踏板旁停一会儿。两片镜面蒙了尘，叶影还朝着屋顶那道缝。\n\n这一天，你的脚步停在旧泵站前。芽芽抬起镜头，把背了很久的种子盒轻轻递向你。"],
	["给春天留的位置", "这份无人签收的礼物，是我们故事的起点。", "《废墟里的种子》，从一个小小的念头开始：给被遗忘的世界，留下一份能继续生长的礼物。\n\n旧花圃里，花旁停过小虫，豆叶下的土仍松软。深根伸向湿处，三个盆沿留下不同高的水印。\n\n芽芽带来的盒子很小，盒外还有许多空着的地方。下一次春天，会长成谁也没见过的模样。"]
]

var garden: Node3D
var root: Control
var overlay: Control
var content: VBoxContainer
var closable = true
var panel_kind = ""
var hud: Control
var paper_panel = false
var panel_grain: NoiseTexture2D
var menu_card: PanelContainer
var menu_icon: Button
var reticle: Control
var feedback_log: Array[String] = []
var prologue_origin = "journey"
var arrival_story_read = false
var story_spread: BoxContainer
var story_heading: Label
var story_copy: Label
var story_art: Control
var story_motion_paused = false
var story_empty: Control
var story_quote: Label
var story_sheet: StyleBoxFlat
var story_camera_mask = -1

func _ready():
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme = Theme.new()
	theme.default_font = load("res://assets/body_font.tres")
	theme.default_font_size = 17
	root.theme = theme
	var paper_noise=FastNoiseLite.new();paper_noise.seed=12008;paper_noise.frequency=.22
	panel_grain=NoiseTexture2D.new();panel_grain.width=128;panel_grain.height=128;panel_grain.seamless=true;panel_grain.noise=paper_noise
	var grain_ramp=Gradient.new();grain_ramp.set_color(0,Color(.10,.08,.04,0));grain_ramp.set_color(1,Color(.10,.08,.04,.13));panel_grain.color_ramp=grain_ramp
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var colors = {"normal":Color("303b32"),"hover":Color("495344"),"pressed":Color("202a23"),"focus":Color("303b32"),"disabled":Color("2d332c")}
		var style = surface_style(colors[state],32)
		style.content_margin_top=10;style.content_margin_bottom=10
		style.border_color=BRASS if state in ["hover","focus"] else Color("776a50")
		style.border_width_left=2 if state=="focus" else 1
		if state=="focus":style.draw_center=false
		theme.set_stylebox(state,"Button",style)
		theme.set_color("font_color","Button",INK)
		theme.set_color("font_hover_color","Button",LIGHT)
		theme.set_color("font_focus_color","Button",INK)
		theme.set_color("font_disabled_color","Button",MUTED)
		theme.set_font("font","Button",TITLE_FONT)
		theme.set_font_size("font_size","Button",18)
	var scroll_track=surface_style(Color("202a23"),0)
	var scroll_grip=surface_style(Color("7c7559"),0)
	theme.set_stylebox("scroll","VScrollBar",scroll_track)
	theme.set_stylebox("grabber","VScrollBar",scroll_grip)
	theme.set_stylebox("grabber_highlight","VScrollBar",surface_style(BRASS,0))
	theme.set_stylebox("grabber_pressed","VScrollBar",surface_style(Color("95805b"),0))
	var track=surface_style(Color("474b3d"),0)
	track.content_margin_top=3;track.content_margin_bottom=3
	var fill=surface_style(Color("ac9b70"),0)
	fill.content_margin_top=3;fill.content_margin_bottom=3
	theme.set_stylebox("slider","HSlider",track)
	theme.set_stylebox("grabber_area","HSlider",fill)
	theme.set_stylebox("grabber_area_highlight","HSlider",fill)
	for state in ["grabber","grabber_highlight","grabber_disabled"]:
		theme.set_icon(state,"HSlider",preload("res://assets/slider-grip.svg"))
	theme.set_color("font_color","Label",INK)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	reticle = Control.new()
	reticle.name = "Reticle"
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.offset_left=-2;reticle.offset_right=2;reticle.offset_top=-2;reticle.offset_bottom=2
	reticle.mouse_filter=Control.MOUSE_FILTER_IGNORE
	reticle.draw.connect(func():reticle.draw_circle(Vector2(2,2),2,Color("eee3c8")))
	hud.add_child(reticle)
	menu_icon=Button.new()
	menu_icon.name="MenuIcon"
	menu_icon.tooltip_text="菜单 · Esc"
	menu_icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	menu_icon.offset_left=-70;menu_icon.offset_right=-26;menu_icon.offset_top=26;menu_icon.offset_bottom=70
	menu_icon.add_theme_stylebox_override("normal",surface_style(Color(.10,.14,.11,.65),0))
	menu_icon.add_theme_stylebox_override("hover",surface_style(Color(.1,.12,.09,.5),0))
	menu_icon.draw.connect(func():
		for row in 3:menu_icon.draw_line(Vector2(12,15+row*6),Vector2(32,15+row*6),Color("e6ddc8"),1.5,true)
	)
	menu_icon.pressed.connect(pause_menu)
	hud.add_child(menu_icon)

func surface_style(color: Color, padding: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(0)
	style.set_border_width_all(1)
	style.border_color = Color("756b53")
	style.border_width_top = 1
	style.shadow_color = Color(0.015,0.035,0.04,0.2)
	style.shadow_size = 3
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _process(_delta):
	if panel_open():fit_panel()
	hud.visible = garden.playing and not panel_open() and not (garden.repair_focus and garden.repair_focus.active)
	reticle.visible=garden.first_person and not garden.busy
	reticle.modulate.a=.9 if is_instance_valid(garden.hovered) else .45

func make_label(text: String, size = 18, color = INK) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func button(text: String, action: Callable, parent: Node = null) -> Button:
	var node = WastelandButton.new()
	node.text = text
	node.custom_minimum_size.y = 44
	node.alignment=HORIZONTAL_ALIGNMENT_CENTER
	node.clip_text=false
	node.mouse_entered.connect(func():node.modulate=Color(1.07,1.07,1.04))
	node.mouse_exited.connect(func():node.modulate=Color.WHITE)
	node.pressed.connect(func():garden.soundscape.ui_effect("ui_confirm"))
	node.mouse_entered.connect(func():garden.soundscape.ui_effect("ui_hover"))
	node.pressed.connect(action)
	if parent: parent.add_child(node)
	return node

func prose(text: String, size = 21, color = INK) -> Label:
	var actual_color=color
	if paper_panel: actual_color=PAPER_INK if color in [INK,LIGHT] else Color("595b4c") if color==MUTED else color
	var label = make_label(text,size,actual_color)
	if paper_panel and size>=20: label.add_theme_font_override("font",STORY_FONT)
	label.add_theme_constant_override("line_spacing",7 if paper_panel else 4)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)
	return label

func panel(title: String, subtitle: String, kind: String, can_close = true):
	# Menus are physical field documents: their amber and oxidation remain legible
	# while the world underneath recovers its colour.
	layer=21
	if overlay:
		root.remove_child(overlay)
		overlay.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	panel_kind = kind
	if garden.soundscape:garden.soundscape.presentation(kind)
	paper_panel = kind in ["chapter","memory","ending"]
	if kind!="prologue":restore_story_camera()
	closable = can_close
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	hud.visible = false
	var dim = ColorRect.new()
	dim.color = Color(0.025, 0.035, 0.025, 0.43)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if kind!="prologue":overlay.add_child(dim)
	else:dim.queue_free()
	var card: PanelContainer = PanelContainer.new() if kind=="prologue" else WastelandPanel.new()
	card.name="SalvagedFrame"
	if kind!="prologue":card.paper=paper_panel
	menu_card=card
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var width=820 if kind=="prologue" else 560 if kind in ["controls","settings","record","journal","hint"] else 500
	var height=736 if kind in ["prologue","settings"] else 660 if kind in ["chapter","memory","ending","controls","settings","journal","record"] else 620
	card.offset_left=-width/2.0;card.offset_right=width/2.0
	card.set_meta("panel_size",Vector2(width,height))
	fit_panel()
	var style = surface_style(PAPER if paper_panel else Color("202b24"), 24)
	style.border_width_left=1
	style.border_color = Color("74654d")
	style.shadow_color = Color(0.01,0.035,0.05,0.3)
	style.shadow_size = 20
	card.add_theme_stylebox_override("panel", style)
	overlay.add_child(card)
	var grain=TextureRect.new();grain.texture=panel_grain;grain.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	grain.stretch_mode=TextureRect.STRETCH_TILE;grain.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if kind!="prologue":card.add_child(grain)
	else:grain.queue_free()
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.get_v_scroll_bar().custom_minimum_size.x=5
	card.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	var archive=prose("种子保管计划  /  旧城来信" if paper_panel else "旧城维护终端  /  现场链路",12,MUTED)
	archive.add_theme_font_override("font",TELEMETRY_FONT)
	archive.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var heading=prose(title,38 if kind=="title" else 30)
	heading.add_theme_font_override("font",TITLE_FONT)
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if subtitle!="":
		var sub=prose(subtitle,13,MUTED)
		sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var rule=ColorRect.new();rule.color=Color("8c7c58") if paper_panel else BRASS
	rule.custom_minimum_size=Vector2(0,1);rule.mouse_filter=Control.MOUSE_FILTER_IGNORE
	content.add_child(rule)

func fit_panel():
	if not is_instance_valid(menu_card):return
	var size: Vector2=menu_card.get_meta("panel_size",Vector2(500,620))
	if panel_kind!="prologue" and is_instance_valid(content) and menu_card.is_ancestor_of(content):
		size.y=minf(size.y,content.get_combined_minimum_size().y+48)
	if panel_kind=="prologue":
		size=root.size
		if is_instance_valid(story_heading) and menu_card.is_ancestor_of(story_heading):
			var compact=size.x<900
			story_empty.visible=not compact
			story_heading.add_theme_font_size_override("font_size",30 if compact else 46)
			story_quote.add_theme_font_size_override("font_size",16 if compact else 18)
			story_copy.add_theme_font_size_override("font_size",18 if compact else 21)
			story_copy.add_theme_constant_override("line_spacing",5 if compact else 8)
			story_sheet.content_margin_left=24 if compact else 64
			story_sheet.content_margin_right=24 if compact else 48
			story_sheet.content_margin_top=20 if compact else 28
			story_sheet.content_margin_bottom=20 if compact else 28
	else:size=size.min((root.size-Vector2(48,64)).max(Vector2(280,240)))
	menu_card.offset_left=-size.x/2;menu_card.offset_right=size.x/2
	menu_card.offset_top=-size.y/2;menu_card.offset_bottom=size.y/2

func panel_open() -> bool:
	return is_instance_valid(overlay)

func restore_story_camera():
	if story_camera_mask>=0 and is_instance_valid(garden.camera):
		garden.camera.cull_mask=story_camera_mask
		story_camera_mask=-1

func close_panel():
	restore_story_camera()
	layer=1
	if overlay:
		root.remove_child(overlay)
		overlay.queue_free()
		overlay = null
	panel_kind = ""
	if garden.soundscape:garden.soundscape.presentation("world")
	hud.visible = garden.playing
	garden.sync_mouse_capture()

func title_screen():
	garden.playing = false
	garden.enter_first_person()
	panel("废墟里的种子", "", "title", false)
	var opening=prose("城市睡着以后，
还有一颗种子，没有放弃春天。",21,MUTED)
	opening.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if Journey.fps_valid or not Journey.memories.is_empty() or Puzzles.data.solved.size()>0:
		content.add_child(primary_button("继续旅程", resume))
	content.add_child(button("开始新的旅程", begin))
	content.add_child(button("旧城往事",func():prologue_screen(0,"title")))
	content.add_child(button("设置", settings_menu))
	content.add_child(button("退出游戏", garden.quit_game))

func begin():
	if Journey.fps_valid or not Journey.memories.is_empty() or Puzzles.data.solved.size() > 0:
		panel("从头再走一次？", "从第一阵风开始", "reset")
		prose("这会替换当前旅程的庭院进度和记忆。", 19)
		content.add_child(button("留着现在的脚印", title_screen))
		content.add_child(button("重新出发", start_new))
	else:
		start_new()

func start_new():
	feedback_log.clear()
	Journey.fresh()
	garden.build_chapter()
	garden.playing = true
	garden.enter_first_person()
	close_panel()
	if arrival_story_read:chapter_opening()
	else:prologue_screen()

func prologue_screen(page = 0,origin = "journey"):
	page=clampi(page,0,2)
	var previous=-1
	var previous_time=0.0
	if panel_kind=="prologue" and is_instance_valid(story_art):
		previous=story_art.page;previous_time=story_art.elapsed
	prologue_origin=origin
	panel(PROLOGUE[page][0],"", "prologue",false)
	garden.soundscape.presentation("prologue",page)
	# The opaque film covers the world: omit its 3D draws while reading.
	if story_camera_mask<0:
		story_camera_mask=garden.camera.cull_mask
	garden.camera.cull_mask=0
	var illustration=StoryVignette.new();story_art=illustration
	illustration.name="StoryPanorama";illustration.page=page
	illustration.previous_page=previous;illustration.previous_elapsed=previous_time
	illustration.motion_paused=story_motion_paused
	illustration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(illustration);overlay.move_child(illustration,0)
	story_sheet=surface_style(Color(0,0,0,0),0)
	story_sheet.shadow_size=0;story_sheet.set_border_width_all(0)
	menu_card.add_theme_stylebox_override("panel",story_sheet)
	for child in content.get_children():
		content.remove_child(child);child.queue_free()
	var scroll: ScrollContainer=content.get_parent()
	menu_card.remove_child(scroll)
	var layout=VBoxContainer.new();layout.name="StoryLayout"
	layout.add_theme_constant_override("separation",20)
	menu_card.add_child(layout)
	var top=HBoxContainer.new();top.name="StoryTop"
	layout.add_child(top)
	var archive=make_label("废墟里的种子  /  序章",12,Color("b9b2a2"))
	archive.add_theme_font_override("font",STORY_FONT)
	archive.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	top.add_child(archive)
	var pause=story_button("继续镜头" if story_motion_paused else "静止画面",func():
		story_motion_paused=not story_motion_paused
		story_art.motion_paused=story_motion_paused
		var motion_button=overlay.find_child("StoryMotion",true,false)
		motion_button.text="继续镜头" if story_motion_paused else "静止画面",true)
	pause.name="StoryMotion";pause.custom_minimum_size=Vector2(88,36)
	top.add_child(pause)
	var skip=story_button("跳过",finish_prologue,true)
	skip.name="StorySkip";skip.custom_minimum_size=Vector2(72,36)
	skip.tooltip_text="进入第一章" if origin=="journey" else "返回菜单"
	top.add_child(skip)
	story_spread=HBoxContainer.new();story_spread.name="StorySpread"
	story_spread.size_flags_vertical=Control.SIZE_EXPAND_FILL
	story_spread.add_theme_constant_override("separation",48)
	layout.add_child(story_spread)
	scroll.name="StoryReading"
	scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio=0.48
	scroll.get_v_scroll_bar().custom_minimum_size.x=5
	story_spread.add_child(scroll)
	story_empty=Control.new();story_empty.mouse_filter=Control.MOUSE_FILTER_IGNORE
	story_empty.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	story_empty.size_flags_stretch_ratio=0.52
	story_spread.add_child(story_empty)
	content.add_theme_constant_override("separation",20)
	var breathing=Control.new();breathing.custom_minimum_size.y=20
	content.add_child(breathing)
	var mark=prose(["Ⅰ   潮退之后","Ⅱ   被托付的清晨","Ⅲ   春天尚未抵达"][page],13,Color("c4a977"))
	mark.add_theme_font_override("font",STORY_FONT)
	story_heading=prose(PROLOGUE[page][0],46,Color("efe8d9"))
	story_heading.add_theme_font_override("font",CINEMATIC_TITLE_FONT)
	story_quote=prose(PROLOGUE[page][1],18,Color("c8bdaa"))
	story_quote.add_theme_font_override("font",STORY_FONT)
	var rule=ColorRect.new();rule.color=Color("b99865")
	rule.custom_minimum_size=Vector2(48,1);rule.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	rule.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(rule)
	story_copy=prose(PROLOGUE[page][2],21,Color("e0dbce"))
	story_copy.add_theme_font_override("font",STORY_FONT)
	var footer=HBoxContainer.new();footer.name="StoryFooter"
	footer.add_theme_constant_override("separation",8)
	layout.add_child(footer)
	var previous_button=story_button("上一页",func():prologue_screen(page-1,origin))
	previous_button.name="StoryPrevious";previous_button.disabled=page==0
	previous_button.custom_minimum_size=Vector2(128,48)
	footer.add_child(previous_button)
	var count=make_label("%02d   ─   03"%(page+1),13,Color("c8bdaa"))
	count.add_theme_font_override("font",TELEMETRY_FONT)
	count.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(count)
	var next=story_button("下一页" if page<2 else "走进旧城" if origin=="journey" else "前往菜单" if origin=="arrival" else "返回菜单",func():prologue_screen(page+1,origin) if page<2 else finish_prologue())
	next.name="StoryNext";next.custom_minimum_size=Vector2(128,48)
	footer.add_child(next)
	fit_panel()
	for pair in [[story_heading,0.0],[story_quote,.10],[story_copy,.18]]:
		var label: Label=pair[0];label.modulate.a=0.0
		var reveal=create_tween().bind_node(label)
		reveal.tween_interval(pair[1])
		reveal.tween_property(label,"modulate:a",1.0,.55).set_trans(Tween.TRANS_SINE)

func story_button(text: String,action: Callable,quiet=false) -> Button:
	var node=Button.new();node.text=text
	var cue="ui_page" if text in ["上一页","下一页"] else "ui_exit" if text in ["跳过","返回菜单","前往菜单"] else "ui_arrival" if text=="走进旧城" else "ui_confirm"
	node.pressed.connect(func():garden.soundscape.ui_effect(cue))
	node.mouse_entered.connect(func():garden.soundscape.ui_effect("ui_hover"))
	node.pressed.connect(action)
	node.add_theme_font_override("font",STORY_FONT)
	node.add_theme_font_size_override("font_size",13 if quiet else 17)
	for state in ["normal","hover","pressed","disabled","focus"]:
		var style=surface_style(Color(.03,.06,.07,.32) if state=="normal" else Color(.23,.25,.22,.60),14)
		style.shadow_size=0;style.content_margin_top=6;style.content_margin_bottom=6
		style.set_border_width_all(0)
		style.border_width_bottom=0 if quiet or state=="disabled" else 1
		style.border_color=Color("b99865")
		if quiet or state=="disabled":style.bg_color=Color(0,0,0,0) if state!="hover" else Color(.23,.25,.22,.60)
		if state=="focus":style.draw_center=false;style.set_border_width_all(2)
		node.add_theme_stylebox_override(state,style)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		node.add_theme_color_override(state,Color("ede5d6"))
	node.add_theme_color_override("font_disabled_color",Color("85877d"))
	return node

func finish_prologue():
	if prologue_origin=="arrival":
		arrival_story_read=true
		Settings.story_seen=true
		Settings.save()
		title_screen()
	elif prologue_origin=="journey":chapter_opening()
	else:menu_return()

func resume():
	garden.playing = true
	garden.enter_first_person()
	close_panel()
	if Journey.ending != "": ending_card()

func primary_button(text: String, action: Callable) -> Button:
	var node = button(text, action)
	node.primary=true
	var style = surface_style(Color("baa16c"), 32)
	style.content_margin_top=10;style.content_margin_bottom=10
	style.border_color = Color("cfb47b")
	node.add_theme_stylebox_override("normal", style)
	var hover=style.duplicate();hover.bg_color=Color("d1b47b")
	node.add_theme_stylebox_override("hover",hover)
	var pressed=style.duplicate();pressed.bg_color=Color("9b855b")
	node.add_theme_stylebox_override("pressed",pressed)
	node.add_theme_color_override("font_color", Color("303427"))
	node.add_theme_color_override("font_hover_color", Color("20281f"))
	node.add_theme_color_override("font_pressed_color", Color("20281f"))
	node.add_theme_color_override("font_focus_color", Color("303427"))
	return node

func chapter_opening():
	if Journey.chapter==0:
		garden.playing=true;close_panel()
		if garden.tutorial:garden.tutorial.configure()
		return
	panel(CHAPTER_NAMES[Journey.chapter], "旧城来信 / 请慢慢读", "chapter", false)
	var opening=prose(CHAPTER_PROSE[Journey.chapter], 19, LIGHT)
	opening.add_theme_constant_override("line_spacing",4)
	prose(garden.SUBTITLES[Journey.chapter], 15, MUTED)
	content.add_child(primary_button("走进" + garden.TITLES[Journey.chapter], close_panel))

func say(text: String):
	# Archive feedback; the first chapter also explains the current operation in place.
	if text=="" or (not feedback_log.is_empty() and feedback_log[-1]==text): return
	feedback_log.append(text)
	if feedback_log.size()>8:feedback_log.pop_front()

func inspect_record(key: String):
	if key not in garden.puzzle_world.NOTES:return
	Puzzles.remember_record(key)
	panel("残碑拓记",garden.puzzle_world.RECORD_FACES[key][0]+" / 已收录","record")
	var document= garden.puzzle_world.NOTES[key].split("\n\n",true,1)
	prose(document[0],23,TECH).add_theme_font_override("font",CONTROL_FONT)
	prose(document[1],21).add_theme_font_override("font",STORY_FONT)
	content.add_child(primary_button("收好，回去试一试",close_panel))

func companion_menu():
	if not garden.playing or garden.busy: return
	panel("伙伴链路 · 芽芽","MAINTENANCE UNIT / C 指令","companion")
	prose("一台旧维护机器人，也想替春天做一点事。
现在："+garden.companion.mood,20)
	content.add_child(button("跟着我",func():garden.companion.command("follow");close_panel()))
	content.add_child(button("在这里等我",func():garden.companion.command("wait");close_panel()))
	var task: String = ["pump","roof","battery"][Journey.chapter]
	content.add_child(primary_button(["协助：守住供电踏板","协助：保持镜架制动","协助：运送储能单元"][Journey.chapter],func():close_panel();garden.dispatch_robot(task)))
	prose("芽芽需要走到装置旁才能协助。
你可以随时召回它，机关不会因等待而损坏。",16,MUTED)
	content.add_child(button("先不用，回到庭院",close_panel))

func settings_menu():
	panel("让旅程舒服一点","声音与画面","settings")
	content.add_theme_constant_override("separation",8)
	var video_row=HBoxContainer.new();video_row.add_theme_constant_override("separation",8);content.add_child(video_row)
	var frame_button=button("",func():Settings.cycle_fps();settings_menu())
	frame_button.name="FrameLimit"
	frame_button.text="帧率上限："+("不限" if Settings.fps_limit==0 else str(Settings.fps_limit)+" FPS")
	frame_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;video_row.add_child(frame_button)
	var sync_button=button("垂直同步："+("开启" if Settings.vsync else "关闭"),func():Settings.vsync=not Settings.vsync;Settings.apply_video();Settings.save();settings_menu())
	sync_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;video_row.add_child(sync_button)
	prose("高刷新率屏幕可选择120或144帧；实际帧率取决于画面和设备。",14,MUTED)
	for pair in [["音乐","music"],["音效","effects"],["环境","ambience"]]:
		var key: String = pair[1]
		prose(pair[0],18)
		var slider=HSlider.new()
		slider.min_value=0;slider.max_value=1;slider.step=.05;slider.value=Settings.get(key)
		slider.custom_minimum_size=Vector2(280,25)
		slider.value_changed.connect(func(value):Settings.set(key,value);Settings.apply_audio();Settings.save())
		content.add_child(slider)
	var current = "高画质" if RenderingServer.get_current_rendering_method()=="forward_plus" else "兼容画质"
	prose("当前："+current+"
切换画质会保存旅程并重启游戏。",16,MUTED)
	content.add_child(button("使用高画质并重启",func():Settings.restart_with_quality("high")))
	content.add_child(button("使用兼容画质并重启",func():Settings.restart_with_quality("compatible")))
	if garden.playing:content.add_child(button("重置本章机关",confirm_reset_puzzles))
	content.add_child(button("返回菜单",menu_return))

func confirm_reset_puzzles():
	panel("重新接续这一章？","物件与机关会回到初始位置","reset-puzzles")
	prose("这一章的解谜进度会重置。已读的信与恢复的颜色保留。
你会回到本章入口，芽芽也会回来。",19)
	content.add_child(button("保留现在的进度",pause_menu))
	content.add_child(button("重置本章机关",func():Puzzles.reset_chapter(Journey.chapter);Journey.node_id="arrival";Journey.fps_valid=false;Puzzles.data.robot_position=[];garden.build_chapter();close_panel()))

func menu_return():
	if garden.playing:pause_menu()
	else:title_screen()

func dismiss_panel():
	if not closable:return
	if panel_kind in ["settings","inventory"] or not garden.playing:menu_return()
	else:close_panel()

func inventory_menu():
	panel("随身物品", "", "inventory")
	if Journey.chapter==1:
		prose("保险模块："+("未携带" if Puzzles.data.fuse_hand<0 else ["○ 圆形","△ 三角","□ 方形"][Puzzles.data.fuse_hand]),20)
	elif Journey.chapter==2:
		if Puzzles.data.plant_bag.is_empty():prose("种苗袋为空。",20,MUTED)
		for plant in Puzzles.data.plant_bag:
			var kind=int(plant)
			content.add_child(button(("✓ " if kind==Puzzles.data.plant_hand else "")+Puzzles.PLANTS[kind],func():choose_plant(kind)))
	else:prose("种子由芽芽保管。",20,MUTED)
	content.add_child(primary_button("返回菜单",menu_return))

func choose_plant(kind: int):
	if kind not in Puzzles.data.plant_bag:return
	Puzzles.data.plant_hand=kind
	Puzzles.updated.emit();Journey.save_journey()
	inventory_menu()

func memory(id: int):
	panel(SHORT_MEMORIES[id][0], "旧城来信 / 第 %02d 封" % (id + 1), "memory")
	prose(SHORT_MEMORIES[id][1], 25)
	prose("修复档案 / "+REPAIR_NOTES[id],16,MUTED)
	prose("收好了第 %d 封信 / 12 · 找回颜色 %d%%" % [Journey.memories.size(),roundi(Journey.memories.size()*100.0/12.0)], 14, MUTED)
	content.add_child(button("继续走", close_panel))

func journal():
	panel("随身记录库", "ARCHIVE / %d 份维护记录 · %d 封来信" % [Puzzles.data.records.size(),Journey.memories.size()], "journal")
	if not feedback_log.is_empty():
		prose("最近的现场反馈",18,TECH)
		for entry in feedback_log.slice(-3):prose(entry,16,MUTED)
	if not Puzzles.data.records.is_empty():
		prose("设备记录",19,TECH)
		var names={"route":"水路出口图","pressure":"水压维护刻痕","power":"保险模块铭牌","mirrors":"日光镜架刻度","beds":"种植与水量需求","roots":"风塔根系双环图"}
		for key in Puzzles.data.records:
			content.add_child(button(names[key],func():inspect_record(key)))
	prose("旧城来信",19,BRASS)
	if Journey.memories.is_empty(): prose("尚未收录来信。", 19,MUTED)
	for id in Journey.memories:
		content.add_child(button(SHORT_MEMORIES[id][0], func(): memory(id)))
	content.add_child(button("回到庭院", close_panel))

func pause_menu():
	if not garden.playing or garden.busy: return
	Journey.save_journey()
	panel("菜单", "", "pause")
	content.add_child(primary_button("继续游戏", close_panel))
	content.add_child(button("芽芽", companion_menu))
	content.add_child(button("随身物品", inventory_menu))
	content.add_child(button("来信与记录", journal))
	content.add_child(button("旧城往事",func():prologue_screen(0,"pause")))
	content.add_child(button("设置", settings_menu))
	if Puzzles.chapter_done(Journey.chapter) and Journey.chapter<2: content.add_child(button("前往下一章",next_garden))
	content.add_child(button("返回标题", title_screen))

func toggle_audio():
	Journey.muted = not Journey.muted
	AudioServer.set_bus_mute(0, Journey.muted)
	Journey.save_journey()
	pause_menu()

func chapter_complete():
	say("旧泵站已恢复。" if Journey.chapter==0 else "温室已恢复。")

func next_garden():
	if not Puzzles.chapter_done(Journey.chapter): return
	Journey.next_chapter()
	garden.build_chapter()
	close_panel()
	garden.playing = true
	chapter_opening()

func final_choice():
	if not Puzzles.chapter_done(2): return
	panel("这份春天，留在哪里？", "最后一封信 / 留给还没来的人", "final")
	prose("种子躺在你手心，轻得像一句愿望。\n旧城的玻璃罩还在，\n外面的风，也正在等它。", 24)
	prose("打开保护罩，让植物沿旧建筑自由生长。\n或留住保护罩，让种子在里面慢慢发芽。", 18, MUTED)
	content.add_child(primary_button("打开保护罩，让春天往外长", func(): garden.choose_ending("regeneration")))
	content.add_child(button("留住保护罩，照顾这颗种子", func(): garden.choose_ending("eden")))
	content.add_child(button("再想一会儿", close_panel))

func ending_card():
	var reg = Journey.ending == "regeneration"
	panel("未送达的春天" if reg else "再次亮起的旧城", "这份春天，已经寄出", "ending", false)
	prose("风穿过空窗，带来叶子的声音。\n这座城还很旧。\n可春天，已经学会自己推门了。" if reg else "玻璃上多了一点绿色的影子。\n你替种子留住了一个小小的家。\n它在里面长着，也望着外面的天空。", 24)
	prose("一点水，一束光，和不一样的叶子\n◇ 随身带着 %d 封旧城来信" % Journey.memories.size(), 15, MUTED)
	content.add_child(button("把这页春天存成纪念卡", save_card))
	content.add_child(button("留在庭院里", func(): close_panel(); garden.playing = true))
	content.add_child(button("再次选择", final_choice))
	content.add_child(button("回到标题", title_screen))

func save_card():
	var buttons: Array = []
	for node in content.get_children():
		if node is Button:
			buttons.append(node)
			node.visible = false
	await RenderingServer.frame_post_draw
	var directory = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("SeedInTheRuins")
	if garden.capture:
		directory = ProjectSettings.globalize_path("res://../builds/cards-v2")
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		directory = OS.get_user_data_dir()
	var path = directory.path_join("seed-garden-" + str(int(Time.get_unix_time_from_system())) + ".png")
	var result = get_viewport().get_texture().get_image().save_png(path)
	for node in buttons: node.visible = true
	say("种子纪念卡已保存到文档目录。" if result == OK else "保存失败，请检查文档目录写入权限。")
