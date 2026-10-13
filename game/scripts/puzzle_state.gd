extends Node
signal updated
signal solved(id: String)
const TASKS = [["water_route","pressure","pump"],["power","mirrors","roof"],["planting","irrigation","life"]]
const NAMES = {"water_route":"修复水路","pressure":"稳定水压","pump":"双人启动","power":"恢复温室电源","mirrors":"引导日光","roof":"同步开顶","planting":"安排植物","irrigation":"分配灌溉","life":"唤醒花园"}
const REVERSIBLE = ["pipe","valve","mirror","irrigate","root"]
const PLANTS = ["花卉","豆科","深根植物"]
const RECORDS = {"water_route":"route","pressure":"pressure","power":"power","mirrors":"mirrors","planting":"beds","irrigation":"beds","life":"roots"}
var data: Dictionary = {}
var message = ""
var hint_levels: Dictionary = {}
func _init(): reset_all()
func defaults() -> Dictionary:
	return {"pipes":[0,0,0],"valves":[0,0],"fuses":[-1,-1,-1],"fuse_hand":-1,"mirrors":[0,0],"beds":[-1,-1,-1],"plant_hand":-1,"plant_bag":[],"records":[],"irrigation":[0,0,0],"roots":[0,0],"battery":false,"solved":[],"robot_cargo":false,"robot_mode":"follow","robot_task":"","robot_position":[],"robot_node":"arrival"}
func reset_all():
	data = defaults()
	hint_levels.clear()
func snapshot() -> Dictionary: return data.duplicate(true)
func restore(value):
	data = defaults()
	if not value is Dictionary: return
	for key in ["pipes","valves","fuses","mirrors","beds","irrigation","roots"]:
		var incoming = value.get(key)
		if incoming is Array and incoming.size() == data[key].size():
			for i in incoming.size():
				if incoming[i] is float or incoming[i] is int:
					data[key][i] = clampi(int(incoming[i]),-1 if key in ["fuses","beds"] else 0,3)
	# A corrupt inventory cannot duplicate objects or make an object disappear.
	for pair in [["fuses","fuse_hand"],["beds","plant_hand"]]:
		var seen = []
		for i in 3:
			var item = data[pair[0]][i]
			if item > 2 or item in seen: data[pair[0]][i] = -1
			elif item >= 0: seen.append(item)
		var held = value.get(pair[1],-1)
		var valid_held = (held is float or held is int) and int(held) in [0,1,2] and int(held) not in seen
		data[pair[1]] = int(held) if valid_held else -1
	# v4 saves with a single held plant migrate into the satchel without duplication.
	var bag = value.get("plant_bag",[])
	if bag is Array:
		for item in bag:
			if (item is int or item is float) and int(item) in [0,1,2] and int(item) not in data.beds and int(item) not in data.plant_bag:
				data.plant_bag.append(int(item))
	if data.plant_hand >= 0 and data.plant_hand not in data.plant_bag: data.plant_bag.append(data.plant_hand)
	if data.plant_hand < 0 and not data.plant_bag.is_empty(): data.plant_hand=data.plant_bag[0]
	var records=value.get("records",[])
	if records is Array:
		for key in records:
			if key in RECORDS.values() and key not in data.records: data.records.append(key)
	for task in value.get("solved",[]) if value.get("solved",[]) is Array else []:
		if task in NAMES and task not in data.solved: data.solved.append(task)
	data.battery = value.get("battery") == true
	data.robot_cargo = value.get("robot_cargo") == true and not data.battery
	data.robot_mode = value.get("robot_mode","follow") if value.get("robot_mode") in ["follow","wait","assist"] else "follow"
	data.robot_task = value.get("robot_task","") if value.get("robot_task") in ["","pump","roof","battery"] else ""
	data.robot_node = str(value.get("robot_node","arrival"))
	var pos = value.get("robot_position",[])
	if pos is Array and pos.size() == 3 and pos.all(func(n): return (n is float or n is int) and is_finite(float(n))): data.robot_position = pos
func done(id: String) -> bool: return id in data.solved
func chapter_done(chapter: int) -> bool: return TASKS[chapter].all(func(id):return done(id))
func stage(chapter: int) -> String:
	for task in TASKS[chapter]:
		if not done(task): return task
	return "complete"
func progress(chapter: int) -> float:
	return float(TASKS[chapter].filter(func(id):return done(id)).size())/3.0
func finish(id: String):
	if done(id): return
	data.solved.append(id)
	var chapter = 0
	for c in 3:
		if id in TASKS[c]: chapter = c
	Journey.remember(chapter*4+TASKS[chapter].find(id)+1)
	solved.emit(id)
func cycle(key: String, index: int, task: String, step = 1):
	if done(task):
		message = "这段机关已经稳定了。可以继续调查下一处。"
		return
	data[key][index] = posmod(int(data[key][index])+step,4)
	message = "调到第 %d 档。看看装置发生了什么变化。" % data[key][index]
func operate(action: String, index = 0, robot_ready = false) -> String:
	message = ""
	var step = -1 if action.ends_with("_back") else 1
	action=action.trim_suffix("_back")
	var indexed = {"pipe":"pipes","valve":"valves","slot":"fuses","retrieve_slot":"fuses","mirror":"mirrors","bed":"beds","retrieve_bed":"beds","irrigate":"irrigation","root":"roots"}
	if action in indexed and (index < 0 or index >= data[indexed[action]].size()): return "这个操作位置不可用。"
	if action in ["take_fuse","take_plant"] and index not in [0,1,2]: return "物件不在工具架上。"
	match action:
		"pipe":
			cycle("pipes",index,"water_route",step)
			if data.pipes == [1,3,2]: finish("water_route");message = "水经过滤池，流入了蓄水槽。桥的制动锁松开了。"
			elif not done("water_route"): message = feedback("water_route")
		"valve":
			if not done("water_route"): return "先让水经过滤池，压力表才会工作。"
			cycle("valves",index,"pressure",step)
			if data.valves == [2,1]: finish("pressure");message = "水位停在三道刻痕之间。现在可以启动水泵了。"
			elif not done("pressure"): message=feedback("pressure")
		"pump":
			if not done("pressure"): return "压力还不稳定。看看滤池旁的维护记录。"
			if not robot_ready: return "电路需要一直有人守着。用 C 派芽芽去供电踏板。"
			finish("pump");message = "芽芽守住了电路。水泵醒了，第一滴水回到了土地。"
		"take_fuse","take_plant":
			var slots = "fuses" if action == "take_fuse" else "beds"
			var hand = "fuse_hand" if action == "take_fuse" else "plant_hand"
			var task = "power" if action == "take_fuse" else "planting"
			if done(task): return "物件已经各就各位。"
			if index in data[slots]: return "它已经装在另一处了。可以从那里取回来。"
			if hand=="plant_hand":
				if index not in data.plant_bag: data.plant_bag.append(index)
			# Returning the previous item to its supply rack is automatic, so one slot is enough.
			data[hand] = index
			message = "带上了" + (["圆形模块","三角模块","方形模块"][index] if hand == "fuse_hand" else PLANTS[index]) + ("。对准目标位置按 E 安装。" if hand=="fuse_hand" else "。种苗袋可装三株；按 Q 切换要种的植物。")
		"retrieve_slot","retrieve_bed":
			var slots="fuses" if action=="retrieve_slot" else "beds"
			var task="power" if slots=="fuses" else "planting"
			if done(task): return "这一组已经稳定了。"
			var item=int(data[slots][index])
			if item<0:return "这里没有可取回的物件。"
			data[slots][index]=-1
			if slots=="beds":
				if item not in data.plant_bag:data.plant_bag.append(item)
				data.plant_hand=item
			else:data.fuse_hand=item
			message="已取回"+(PLANTS[item] if slots=="beds" else ["圆形模块","三角模块","方形模块"][item])+"。可以重新安排位置。"
		"slot","bed":
			var slots = "fuses" if action == "slot" else "beds"
			var hand = "fuse_hand" if action == "slot" else "plant_hand"
			var task = "power" if action == "slot" else "planting"
			if done(task): return "这一组已经稳定了。"
			var old = data[slots][index]
			var held = data[hand]
			if held<0 and old<0: return "这里还是空的。先去工具架拿取"+("模块。" if action=="slot" else "种苗；可一次带上三株。")
			data[slots][index] = data[hand]
			if action=="bed":
				data.plant_bag.erase(held)
				if old>=0 and old not in data.plant_bag: data.plant_bag.append(old)
				data.plant_hand=old if old>=0 else -1 if data.plant_bag.is_empty() else data.plant_bag[0]
			else: data[hand] = old
			message = "位置已调整。根据铭牌和维护记录，检查对应关系。"
			if data[slots] == ([2,0,1] if action == "slot" else [0,1,2]): finish(task);message = "电源接通了。高处的镜架可以调整了。" if action == "slot" else "三种植物都找到了合适的家。接下来给它们分配水。"
			elif not done(task): message=feedback(task)
		"mirror":
			if not done("power"): return "镜架还没有电。先检查温室电源柜。"
			cycle("mirrors",index,"mirrors",step)
			if data.mirrors == [1,3]: finish("mirrors");message = "光依次经过两面镜子和中继板，落到了幼苗上。"
			elif not done("mirrors"): message=feedback("mirrors")
		"roof":
			if not done("mirrors"): return "日光还没有照到幼苗。观察镜架旁的刻度图。"
			if not robot_ready: return "松开制动，镜架就会回落。用 C 派芽芽守住制动开关。"
			finish("roof");message = "屋顶缓缓让开。芽芽仰起头，陪叶子看见了天空。"
		"irrigate":
			if not done("planting"): return "先给植物找到合适的种植床。"
			cycle("irrigation",index,"irrigation",step)
			if data.irrigation == [1,2,3]: finish("irrigation");message = "每一张种植床，都接住了需要的水。风塔可以修复了。"
			elif not done("irrigation"): message=feedback("irrigation")
		"root":
			if not done("irrigation"): return "先让三处水量与需求刻痕对应。"
			cycle("roots",index,"life",step)
			message=feedback("life")
		"life":
			if not done("irrigation"): return "种植床还在等水。"
			if not data.battery: return "风塔缺少储能单元。用 C 请芽芽把它送来。"
			if data.roots != [2,1]: return "根系还没有接通。墙上的双环图记录了两处接头的方向。"
			finish("life");message = "风塔转起来了。这一次，春天有了自己的力量。"
	updated.emit()
	Journey.save_journey()
	return message
func select_next_plant() -> String:
	if data.plant_bag.is_empty(): return "种苗袋是空的。去入口工具架带上三株种苗。"
	var next=(data.plant_bag.find(data.plant_hand)+1)%data.plant_bag.size()
	data.plant_hand=data.plant_bag[next]
	updated.emit();Journey.save_journey()
	return "准备种植："+PLANTS[data.plant_hand]+" · 对准种植床按 E"
func remember_record(key: String):
	if key not in RECORDS.values() or key in data.records: return
	data.records.append(key);Journey.save_journey()
func feedback(task: String) -> String:
	match task:
		"water_route":
			var connected=0
			for i in 3:
				if data.pipes[i]!=[1,3,2][i]: break
				connected+=1
			return "通路 %d / 3 · %s"%[connected,"水路已连通" if connected==3 else "第 %d 处仍漏水；沿出口箭头观察"%(connected+1)]
		"pressure":
			if not done("water_route"): return "压力表离线 · 先接通滤池水路"
			var level=int(data.valves[0])*2-int(data.valves[1])
			return "水位 %d / Ⅲ · %s"%[level,"水位偏低" if level<3 else "水位偏高" if level>3 else "水位到线；再核对两个阀门的维护刻痕" if not done("pressure") else "压力稳定"]
		"pump": return "水压稳定 · 请芽芽守住踏板，再去泵房启动" if done("pressure") else "供电待机 · 先稳定水压"
		"power":
			var count=0
			for i in 3:
				if data.fuses[i]==[2,0,1][i]:count+=1
			return "触点接通 %d / 3 · 核对插槽外形；按 E 可取回或交换"%count
		"mirrors":
			if not done("power"): return "镜架离线 · 先恢复电源"
			return "中继未接光 · 观察第一面镜子的光束" if data.mirrors[0]!=1 else "中继已接光 · 第二面镜子的光还没到幼苗" if data.mirrors[1]!=3 else "幼苗已接到日光"
		"roof":return "日光已就位 · 请芽芽保持制动，再操作屋顶轮柄"
		"planting":
			var occupied=data.beds.filter(func(n):return n>=0).size()
			return "种植床 %d / 3 · 按 Q 选苗；核对日照、水分与根系记录"%occupied
		"irrigation":
			var count=0
			for i in 3:
				if data.irrigation[i]==i+1:count+=1
			return "水量匹配 %d / 3 · 仪表显示欠水、过量或到线"%count
		"life":return "储能 %s · 根系 %d / 2 连通"%["到位" if data.battery else "待运送",int(data.roots[0]==2)+int(data.roots[1]==1)]
	return ""
func objective(chapter: int) -> String:
	var task=stage(chapter)
	var goals={"water_route":"桥边水路台 · 沿箭头把水送过滤池","pressure":"滤池压力台 · 看水位和两处刻痕","pump":"滤池踏板 + 泵房 · 与芽芽一起启动","power":"模块架 → 电源柜 · 按凹槽外形装配","mirrors":"乘升降台 · 把光送经中继到幼苗","roof":"上层制动 + 屋顶轮柄 · 双人开顶","planting":"带上三株种苗 · 读记录后安排西、东、北床","irrigation":"三床分水器 · 让水量落在需求刻痕","life":"登上风塔 · 运送储能并接续根系"}
	return goals.get(task,"")
func reset_chapter(chapter: int):
	var fresh = defaults()
	var keys = [["pipes","valves"],["fuses","fuse_hand","mirrors"],["beds","plant_hand","plant_bag","irrigation","roots","battery"]][chapter]
	for key in keys: data[key] = fresh[key]
	for task in TASKS[chapter]: data.solved.erase(task)
	data.robot_mode = "follow"
	data.robot_task = ""
	data.robot_cargo = false
	hint_levels.clear()
	Journey.water = done("pump")
	Journey.shutters = done("roof")
	Journey.species = [0,1,2] if done("planting") else []
	Journey.completed.erase(chapter)
	Journey.ending = ""
	Journey.save_journey()
	updated.emit()
func hint(chapter: int, advance = false) -> String:
	var id = stage(chapter)
	if id == "complete": return "这一章的机关已恢复。可以继续旅程，或留在这里看看。"
	var level = int(hint_levels.get(id,0))
	if advance: level = mini(level+1,2)
	hint_levels[id] = level
	var cards = {
	"water_route":["去长桥旁看看水路板，沿管道的出口找滤池。","箭头需要依次指向滤池、蓄水槽和回流口；旁路不能接入。","三个接头从左到右调整为 1、3、2 档。"],
	"pressure":["滤池旁的墙上有一份刻着短线的维护记录。","进水每档两格，回流每档一格。先让回流与维护刻痕一致，再让净水位到三。","入水阀调到 2 档，回流阀调到 1 档。"],
	"pump":["泵房电缆通向滤池边的一块踏板。","必须有人持续压住踏板，另一个人去启动水泵。","按 C 选择协助：供电踏板，等芽芽到位后去泵房按 E 启动。"],
	"power":["检查电源柜铭牌，再去旁边的模块架。","三个插槽的凹槽形状分别是方、圆、三角。","依次拿取方形、圆形、三角模块，安装到左、中、右插槽。"],
	"mirrors":["乘日光台到上层，镜架旁有一张旧刻度图。","光要先照到中继，再经过第二面镜子；观察每次偏转。","第一面镜子调到 1 档，第二面调到 3 档。"],
	"roof":["屋顶轮柄旁写着：制动松开时，镜架会回落。","芽芽可以替你保持制动。","按 C 选择协助：制动开关，等它到位，再去幼苗旁转动屋顶轮柄。"],
	"planting":["三个种植床的牌子分别描述访客、养分和深处的水。","花留住访客，豆科养土，深根留水。","把花放西床、豆科放东床、深根放北床。物件在入口工具架。"],
	"irrigation":["每张种植床边缘，都刻着它需要的水量。","水量档位要与西、东、北三处的一、二、三道刻痕对应。","三处分水器分别调到 1、2、3 档。"],
	"life":["沿北侧阶梯登上风塔，寻找储能接口与根系图。","请芽芽送来储能单元，再按双环图接通两段根系。","按 C 派送储能单元；左根系接头 2 档、右接头 1 档，最后启动风塔。"]}
	return "提示 %d / 3 · %s\n\n%s" % [level+1,NAMES[id],cards[id][level]]
