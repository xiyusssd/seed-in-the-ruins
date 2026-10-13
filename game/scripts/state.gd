extends Node

signal changed
var save_path = "user://journey.json"
var restored = {"water": false, "energy": false, "bio": false}
var memories: Array = []
var discovered = false
var ending = ""
var position = Vector3(0, 1, 15)
var water_route: Array = ["直通", "直通"]
var power: Array = [true, true, true, true, true]
var plants: Array = []
var elapsed = 0.0
var demo = false
var attempts = {"water": 0, "energy": 0, "bio": 0}
const COSTS = [30, 25, 20, 35, 30]
const PLANTS = ["高产谷物", "豆科植物", "地表覆盖", "深根植物", "花卉植物", "速生作物"]

func _ready():
	for flag in ["--smoke-test", "--capture", "--test", "--walkthrough", "--verify-build"]:
		if flag in OS.get_cmdline_user_args():
			save_path = "user://verification.json"
			return
	load_game()

func stage() -> int:
	return int(restored.water) + int(restored.energy) + int(restored.bio)

func core_open() -> bool:
	return discovered and stage() == 3 and memories.size() >= 6

func water_valid(route: Array) -> bool:
	return route == ["过滤", "湿地"]

func power_total(values: Array) -> int:
	var total = 0
	for i in range(min(values.size(), COSTS.size())):
		if values[i]:
			total += COSTS[i]
	return total

func energy_valid(values: Array) -> bool:
	return values.size() == 5 and values[3] and values[4] and power_total(values) <= 100

func bio_valid(values: Array) -> bool:
	# Flowers supply pollinators; legumes or ground cover protect soil;
	# deep roots preserve access to water. More than one viable combination.
	return values.size() == 3 and 4 in values and 3 in values and (1 in values or 2 in values)

func complete(zone: String):
	restored[zone] = true
	save_game()
	changed.emit()

func collect(id: int):
	if id not in memories:
		memories.append(id)
		save_game()
		changed.emit()

func reset():
	restored = {"water": false, "energy": false, "bio": false}
	memories = []
	discovered = false
	ending = ""
	position = Vector3(0, 1, 15)
	water_route = ["直通", "直通"]
	power = [true, true, true, true, true]
	plants = []
	attempts = {"water": 0, "energy": 0, "bio": 0}
	elapsed = 0.0
	save_game()
	changed.emit()

func save_game():
	var data = {"version": 1, "restored": restored, "memories": memories, "discovered": discovered,
		"ending": ending, "position": [position.x, position.y, position.z], "water_route": water_route,
		"power": power, "plants": plants, "elapsed": elapsed, "attempts": attempts}
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func load_game():
	if not FileAccess.file_exists(save_path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary or data.get("version") != 1:
		return
	var zones = data.get("restored", {})
	if zones is Dictionary:
		for key in restored:
			restored[key] = zones.get(key, false) == true
	var ids = data.get("memories", [])
	if ids is Array:
		for id in ids:
			if id is float or id is int:
				if int(id) >= 0 and int(id) < 12 and int(id) not in memories:
					memories.append(int(id))
	discovered = data.get("discovered", false) == true
	if data.get("ending", "") in ["", "eden", "regeneration"]:
		ending = data.get("ending", "")
	var p = data.get("position", [])
	if p is Array and p.size() == 3:
		if p.all(func(v): return v is int or v is float):
			position = Vector3(clampf(p[0], -34, 34), 1, clampf(p[2], -34, 34))
	var route = data.get("water_route", [])
	if route is Array and route.size() == 2 and route.all(func(v): return v in ["直通", "过滤", "湿地"]):
		water_route = route
	var loads = data.get("power", [])
	if loads is Array and loads.size() == 5 and loads.all(func(v): return v is bool):
		power = loads
	var seeds = data.get("plants", [])
	if seeds is Array:
		for value in seeds:
			if (value is int or value is float) and int(value) >= 0 and int(value) < 6 and int(value) not in plants and plants.size() < 3:
				plants.append(int(value))
	if data.get("elapsed") is float or data.get("elapsed") is int:
		elapsed = maxf(0, data.elapsed)
