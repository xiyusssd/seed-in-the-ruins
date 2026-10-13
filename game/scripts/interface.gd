extends CanvasLayer
const INK = Color("102d39")
const PAPER = Color("d8e5e4")
const ACCENT = Color("a5cba5")
var world: Node3D
var root: Control
var overlay: Control
var content: VBoxContainer
var hint: Label
var status: Label
var location: Label
var objective: Label
var can_close = true
var feedback: Label
var energy_meter: Label
var bio_meter: Label
var request: HTTPRequest
var active_request = ""
var request_generation = 0
var ai_source: Label

func _ready():
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme = Theme.new()
	theme.default_font = load("res://assets/body_font.tres")
	theme.default_font_size = 18
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style = StyleBoxFlat.new()
		style.bg_color = Color("244653") if state == "normal" else Color("375f68")
		if state == "disabled":
			style.bg_color = Color("32454a")
		style.border_color = ACCENT if state == "focus" else Color("5a7d80")
		style.set_border_width_all(2 if state == "focus" else 1)
		style.content_margin_left = 18
		style.content_margin_right = 18
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		theme.set_stylebox(state, "Button", style)
	theme.set_color("font_color", "Button", PAPER)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	root.theme = theme
	var hud_bg = ColorRect.new()
	hud_bg.color = Color(0.03, 0.10, 0.14, 0.8)
	hud_bg.position = Vector2(18, 14)
	hud_bg.size = Vector2(655, 110)
	hud_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud_bg)
	status = label("", 17, ACCENT)
	status.position = Vector2(30, 24)
	root.add_child(status)
	location = label("EDEN—04 / 中央废墟", 14, PAPER)
	location.position = Vector2(30, 55)
	root.add_child(location)
	objective = label("", 16, PAPER)
	objective.position = Vector2(30, 86)
	root.add_child(objective)
	var cross = label("·", 34, PAPER)
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.position -= Vector2(8, 23)
	root.add_child(cross)
	hint = label("", 20, PAPER)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-280, -95)
	hint.size = Vector2(560, 36)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)
	var controls = label("WASD 移动   /   鼠标 视角   /   E 交互   /   Tab 记忆   /   M 地图   /   Esc 暂停", 14, PAPER)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.position = Vector2(30, -40)
	root.add_child(controls)
	request = HTTPRequest.new()
	request.timeout = 3
	add_child(request)
	request.request_completed.connect(ai_result)

func label(text: String, size = 18, color = PAPER) -> Label:
	var node = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node

func prose(text: String, size = 19, color = PAPER) -> Label:
	var node = label(text, size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(node)
	return node

func button(text: String, action: Callable, parent: Node = null) -> Button:
	var node = Button.new()
	node.text = text
	node.custom_minimum_size.y = 48
	node.pressed.connect(action)
	(parent if parent else content).add_child(node)
	return node

func panel(kicker: String, title: String, subtitle: String, closable = true):
	request.cancel_request()
	active_request = ""
	request_generation += 1
	if overlay:
		overlay.queue_free()
	world.player.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	can_close = closable
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var dim = ColorRect.new()
	dim.color = Color(0.025, 0.08, 0.11, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var outer = PanelContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 240
	outer.offset_right = -240
	outer.offset_top = 58
	outer.offset_bottom = -58
	var style = StyleBoxFlat.new()
	style.bg_color = INK
	style.border_color = Color("597b80")
	style.set_border_width_all(1)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 26
	style.content_margin_bottom = 26
	outer.add_theme_stylebox_override("panel", style)
	overlay.add_child(outer)
	var scroll = ScrollContainer.new()
	outer.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)
	prose(kicker, 14, ACCENT)
	prose(title, 34)
	if subtitle != "":
		prose(subtitle, 17, Color("a2bfc1"))
	content.add_child(HSeparator.new())

func close():
	request.cancel_request()
	active_request = ""
	if overlay:
		overlay.queue_free()
		overlay = null
	world.player.active = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	can_close = true
	update_hud()

func menu():
	panel("A GIFT FOR THE ABANDONED WORLD", "废墟里的种子", "SEED IN THE RUINS  /  叙事探索体验", false)
	prose("礼物没有被送到你手上。\n它被留在一座废弃的城市里，等待一个仍愿意寻找的人。", 23)
	prose("城市曾经承诺永续。现在，只有一处生命信号还在闪烁。\n穿过废墟，找回水、光和生长的可能。")
	if State.discovered or State.memories.size() > 0:
		button("继续寻找 · " + str(State.memories.size()) + " 段记忆", close)
	button("开始新的旅程", new_journey)
	button("现场体验模式 · " + ("开启" if State.demo else "关闭"), func(): State.demo = not State.demo; menu())
	button("离开游戏", world.quit_game)
	prose("WASD 移动 · 鼠标观察 · E 读取物件\n三处生态设施 / 十二段记忆 / 两种未来\n全程离线可玩。AI 记忆重构为可选功能。", 14, Color("a2bfc1"))

func new_journey():
	if State.discovered or State.memories.size() > 0:
		panel("NEW JOURNEY", "重新进入废墟？", "这会重置当前旅程的记忆、修复进度和结局。")
		button("保留当前旅程", menu)
		button("确认开始新旅程", start_new)
	else:
		start_new()

func start_new():
	State.reset()
	world.player.position = Vector3(0, 1, 15)
	world.player.rotation = Vector3.ZERO
	world.player.camera.rotation = Vector3.ZERO
	panel("SIGNAL FOUND / EDEN—04", "生命可能性：未知", "人口 0 / 水循环 离线 / 生物圈 失效")
	prose("“如果你还能听见这段记录，请向广场中央前进。\n我们留下了最后的礼物。”", 23)
	prose("找到中央发光的玻璃种子舱，靠近并按 E。\n沿途的铜色记忆标记可以读取。按 M 查看区域地图。")
	button("走进废墟", close)

func pause_menu():
	State.save_game()
	panel("JOURNEY PAUSED", "在这里停一会儿", "进度已经保存。")
	button("继续探索", close)
	button("查看记忆", journal)
	button("查看地图", map_view)
	button("声音 · " + ("开启" if not AudioServer.is_bus_mute(0) else "关闭"), func(): AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0)); pause_menu())
	button("返回标题", menu)

func update_hud():
	var stages = ["休眠", "生根", "萌芽", "展叶"]
	status.text = "REGENESIS / " + stages[State.stage()] + "    ◇ " + str(State.memories.size()) + "/12"
	if not State.discovered:
		objective.text = "循着微光，找到广场中央的生命信号。"
	elif State.stage() < 3:
		objective.text = "让它生长：探索水循环区、能源区和生物温室。"
	elif State.memories.size() < 6:
		objective.text = "生命条件已恢复。再寻找 %d 段记忆，拼出城市的过去。" % (6 - State.memories.size())
	elif State.ending == "":
		objective.text = "核心档案已解锁。前往入口后方的 REGENESIS 控制台。"
	else:
		objective.text = "旅程已完成。你仍可以留在这里，寻找剩下的记忆。"

func update_location(p: Vector3):
	var name = "中央废墟"
	if p.x < -14:
		name = "水循环区"
	elif p.x > 14:
		name = "能源区"
	elif p.z < -14:
		name = "生物温室"
	elif p.z > 22:
		name = "再生核心"
	location.text = "EDEN—04 / " + name

func interact(kind: String, id: int):
	match kind:
		"seed": seed_view()
		"memory": memory_view(id)
		"water", "energy", "bio":
			if not State.discovered:
				panel("DORMANT NETWORK", "尚未找到生命信号", "先读取广场中央的玻璃种子舱，确认它需要什么。")
				button("继续寻找", close)
			else:
				match kind:
					"water": water_view()
					"energy": energy_view()
					"bio": bio_view()
		"core": core_view()

func seed_view():
	State.discovered = true
	State.save_game()
	panel("BIOLOGICAL OBJECT / REGENESIS", "一颗没有收件人的种子", "状态：" + ["休眠", "生根", "萌芽", "展叶"][State.stage()])
	prose("玻璃里有一颗微弱跳动的种子。保存装置没有署名。\n它需要的不是主人，而是能够让它生长的地方。", 22)
	for pair in [["water", "水 · 净化与湿地"], ["energy", "光 · 有限能源的重新分配"], ["bio", "土壤 · 一个互补的生态系统"]]:
		prose(("✓  " if State.restored[pair[0]] else "○  ") + pair[1], 19, ACCENT)
	prose("收集至少六段记忆，理解 EDEN 发生了什么。\n按 M 查看地图，前往三处控制台。", 16)
	button("让它继续等待我", close)

func memory_view(id: int):
	State.collect(id)
	var item: Dictionary = world.data[id]
	panel("MEMORY %02d / %s" % [id + 1, item.type], item.title, "已保存到记忆册 · Tab 随时回看")
	prose(item.text, 24)
	button("离线记忆重构", func(): reconstruction(id, false))
	button("AI 记忆重构（可选）", func(): reconstruction(id, true))
	button("继续探索", close)

func reconstruction(id: int, online: bool):
	var item: Dictionary = world.data[id]
	panel("MEMORY RECONSTRUCTION", item.title, "以下是基于遗物的想象性重构，不是新的核心剧情证据。")
	feedback = prose(item.reconstruction, 23)
	var source = prose("来源：离线预设记忆", 14, ACCENT)
	ai_source = source
	button("回到档案", func(): memory_view(id))
	button("继续探索", close)
	if online:
		source.text = "正在连接本地记忆服务；不可用时保留离线文本。"
		active_request = "memory"
		var error = request.request("http://127.0.0.1:8787/memory/reconstruct", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify({"memory_ids": [id]}))
		if error != OK:
			active_request = ""
			source.text = "来源：离线预设记忆（本地服务未连接）"

func journal():
	panel("MEMORY ARCHIVE / %d OF 12" % State.memories.size(), "城市留下的声音", "读过的档案会留在这里。未发现的档案仍藏在废墟中。")
	if State.memories.is_empty():
		prose("还没有收集记忆。寻找铜色 ◇ 标记，靠近后按 E。")
	for i in 12:
		if i in State.memories:
			button("%02d / %s" % [i + 1, world.data[i].title], func(): memory_view(i))
		else:
			prose("%02d / 尚未发现" % (i + 1), 16, Color("718f97"))
	button("回到废墟", close)

func water_view():
	panel("WATER RECLAMATION / 01", "给水留一条慢路", "先观察水质，再决定路线。错误配置可以随时重试。")
	prose("循环率很高，污染却在积累。两段管路可以重新接通。\n过滤器移除颗粒，湿地需要接收经过过滤的水。直通最快。", 18)
	for i in 2:
		var row = HBoxContainer.new()
		content.add_child(row)
		row.add_child(label("第一段" if i == 0 else "第二段", 18))
		for option in ["直通", "过滤", "湿地"]:
			var b = button(("● " if State.water_route[i] == option else "○ ") + option, func(): set_route(i, option), row)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feedback = prose("当前：水源 → %s → %s → 种子蓄水池" % State.water_route, 18, ACCENT)
	button("试运行水路", try_water)
	if State.restored.water:
		prose("✓ 水已清澈。你可以继续试验路线，已完成的修复会保留。", 16, ACCENT)
	button("返回水池边", close)

func set_route(index: int, option: String):
	State.water_route[index] = option
	State.save_game()
	water_view()

func try_water():
	State.attempts.water += 1
	if State.water_valid(State.water_route):
		complete("water", "水慢下来，第一条根出现了。", "过滤后的水进入湿地。灰色池面逐渐变清，池边长出第一株植物。")
	else:
		feedback.text = "试运行：水仍浑浊。\n先让过滤器处理污染，再让湿地恢复它。湿地不能接收未经处理的水。"
		world.play_sound("error")

func energy_view():
	panel("FINITE ENERGY / 02", "不必让所有灯重新亮起", "可用能源：100 单位。保留温室与种子实验室，避免总需求过载。")
	var names = ["广告网络", "居民记忆档案", "旧商业区", "温室", "种子实验室"]
	for i in 5:
		button(("● 供电" if State.power[i] else "○ 断开") + "   /   " + names[i] + "   /   " + str(State.COSTS[i]), func(): toggle_power(i))
	energy_meter = prose("总需求 %d / 100" % State.power_total(State.power), 22, ACCENT)
	feedback = prose("居民档案也可以留下。把电留给什么，由你决定。", 16)
	button("应用调度", try_energy)
	button("返回能源区", close)

func toggle_power(index: int):
	State.power[index] = not State.power[index]
	State.save_game()
	world.refresh_world()
	energy_view()

func try_energy():
	State.attempts.energy += 1
	if State.energy_valid(State.power):
		complete("energy", "一片胚芽迎向了光。", "总需求回到承载范围内。" + ("广告停止了。风原来一直都在。" if not State.power[0] else "广告仍在播放，但旧商业区已经安静。"))
	else:
		feedback.text = "调度失败：" + ("总需求超过供给，系统过载。" if State.power_total(State.power) > 100 else "温室和种子实验室都需要供电。")
		world.play_sound("error")

func bio_view():
	panel("ROOM FOR DIFFERENCE / 03", "为差异留出位置", "从六种植物里选择三种。互补的功能，比单季高产更重要。")
	var functions = ["高产，但依赖肥料", "补充土壤养分", "保护地表与土壤", "深层取水，稳定根系", "为传粉者提供栖息地", "速生，但大量消耗养分"]
	for i in 6:
		button(("● " if i in State.plants else "○ ") + State.PLANTS[i] + " / " + functions[i], func(): toggle_plant(i))
	bio_meter = prose("已选择 %d / 3" % State.plants.size(), 18, ACCENT)
	feedback = prose("一个系统需要土壤保护、水分韧性和传粉者。", 16)
	button("模拟一季生长", try_bio)
	button("返回温室", close)

func toggle_plant(index: int):
	if index in State.plants:
		State.plants.erase(index)
	elif State.plants.size() < 3:
		State.plants.append(index)
	else:
		feedback.text = "只能选择三种。先取消一个已选植物。"
		return
	State.save_game()
	bio_view()

func try_bio():
	State.attempts.bio += 1
	if State.bio_valid(State.plants):
		complete("bio", "第二片叶子展开。", "温室没有变成森林。只有几株互相支持的植物，和第一处可以留给昆虫的地方。")
	else:
		var missing: Array[String] = []
		if State.plants.size() != 3: missing.append("三个物种")
		if 4 not in State.plants: missing.append("传粉者栖息地")
		if 3 not in State.plants: missing.append("深根取水能力")
		if 1 not in State.plants and 2 not in State.plants: missing.append("土壤保护")
		feedback.text = "模拟结果：系统仍然脆弱。缺少" + "、".join(missing) + "。"
		world.play_sound("error")

func complete(zone: String, title: String, text: String):
	var first = not State.restored[zone]
	State.complete(zone)
	world.play_sound("grow")
	panel("LIFE POSSIBILITY / " + str(State.stage()), title, "修复已经保存。回到中央种子舱可以查看生长。")
	prose(text, 24)
	if first and State.stage() == 3:
		prose("三处生长条件已经恢复。核心仍需要至少六段记忆。\n你修复了设施，但它们曾经为什么失效？")
	button("看看发生了什么", close)

func core_view():
	if not State.core_open():
		panel("REGENESIS / LOCKED", "核心档案尚未开放", "恢复三处设施，并收集至少六段记忆。")
		prose("已恢复：%d / 3\n已读取记忆：%d / 6" % [State.stage(), State.memories.size()], 24)
		button("继续寻找", close)
		return
	panel("FINAL ARCHIVE / REGENESIS", "不要重建 EDEN。", "让新的东西生长。")
	prose("这座城市提高了效率，却没有减少总消耗。\n每一次节省都被更多需求提前用完；湿地、多样性和维修被当作可以省掉的成本。", 21)
	prose("种子保存着本地植物、微生物和土壤修复协议。\n研究员留下它，不是为了重建城市，而是为了让这个地方重新拥有产生生命的能力。", 21)
	prose("现在，两种未来都在你手里。选择之后仍可回到核心，探索另一种结局。", 16, ACCENT)
	button("重启 EDEN / 让旧城市重新运行", func(): choose_ending("eden"))
	button("释放再生计划 / 把空间留给新生命", func(): choose_ending("regeneration"))
	button("再想一会儿", close)

func choose_ending(choice: String):
	State.ending = choice
	State.save_game()
	State.changed.emit()
	world.play_sound("grow")
	close()
	world.player.active = false
	world.player.position = Vector3(0, 1, 5)
	world.player.rotation = Vector3.ZERO
	world.player.camera.rotation.x = 0.05
	if choice == "regeneration":
		var plants = world.greenery.ending
		plants.scale = Vector3(0.1, 0.1, 0.1)
		var tween = create_tween()
		tween.tween_property(plants, "scale", Vector3.ONE, 5)
	await get_tree().create_timer(5).timeout
	ending_card()

func ending_card():
	var regenerated = State.ending == "regeneration"
	panel("YOUR SEED / EDEN—04", "未送达的春天" if regenerated else "一座再次亮起的城", "A Gift for the Abandoned World", false)
	prose("你收到的不是一个世界。\n而是让世界再次生长的机会。" if regenerated else "EDEN ONLINE.\nGROWTH TARGET: +4.2%\n玻璃容器里，种子也发芽了。", 25)
	feedback = prose("你留下了城市的骨架，把光还给了新的生命。" if regenerated else "你让熟悉的灯再次亮起。种子还在玻璃里，等待下一次选择。", 19, ACCENT)
	prose("◇ 记忆 %d / 12   ·   水 已恢复   ·   生物圈 已恢复\n旅程时长 %d 分 %d 秒" % [State.memories.size(), int(State.elapsed) / 60, int(State.elapsed) % 60], 15)
	button("保存种子纪念卡 PNG", save_card)
	button("生成 AI 寄语（可选）", request_ending)
	button("留在这个世界", close)
	button("返回标题", menu)

func save_card():
	# Capture only the authored card, without its interactive buttons.
	var buttons: Array = []
	for node in content.get_children():
		if node is Button:
			buttons.append(node)
			node.visible = false
	await RenderingServer.frame_post_draw
	var directory = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("SeedInTheRuins")
	if "--walkthrough" in OS.get_cmdline_user_args():
		directory = ProjectSettings.globalize_path("res://../builds/cards")
	var error = DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		directory = OS.get_user_data_dir()
	var path = directory.path_join("seed-" + str(int(Time.get_unix_time_from_system())) + ".png")
	var image = get_viewport().get_texture().get_image()
	var result = image.save_png(path)
	for node in buttons:
		node.visible = true
	feedback.text = "纪念卡已保存：" + path if result == OK else "保存失败。请检查文档目录写入权限。"

func request_ending():
	active_request = "ending"
	request.cancel_request()
	var error = request.request("http://127.0.0.1:8787/ending/generate", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify({"ending": State.ending, "memories_found": State.memories.size(), "energy_choice": State.power}))
	if error != OK:
		active_request = ""

func ai_result(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
	if active_request == "":
		return
	var kind = active_request
	active_request = ""
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not is_instance_valid(feedback):
		if kind == "memory" and is_instance_valid(ai_source):
			ai_source.text = "来源：离线预设记忆（AI 服务不可用）"
		return
	var value = JSON.parse_string(body.get_string_from_utf8())
	if value is Dictionary:
		var text = value.get("text" if kind == "memory" else "message", "")
		if text is String and text.length() > 0 and text.length() <= 160:
			if kind == "memory" and is_instance_valid(ai_source):
				ai_source.text = "记忆重构完成"
			feedback.text = text + "\n\n来源：" + ("AI 生成" if value.get("source") == "llm" else "离线预设记忆")

func map_view():
	panel("EDEN—04 / FIELD MAP", "循着设施，找回生长", "三处区域可以按任意顺序探索。铜色 ◇ 是记忆。")
	prose("                     北 / 生物温室\n                        温室种植台\n                              │\n西 / 水循环区 ─ 中央种子舱 ─ 东 / 能源区\n   水路控制台           │           能源调度台\n                              │\n                     南 / 再生计划核心\n                        入口在核心前方", 21)
	prose("水：" + ("已恢复" if State.restored.water else "等待修复") + "  /  能源：" + ("已恢复" if State.restored.energy else "等待修复") + "  /  生物圈：" + ("已恢复" if State.restored.bio else "等待修复"), 16, ACCENT)
	prose("所有控制台与档案都在地面上。靠近后对准物件，出现 E 提示即可交互。")
	button("回到废墟", close)
