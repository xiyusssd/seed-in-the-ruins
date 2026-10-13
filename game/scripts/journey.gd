extends Node
signal changed
var save_path = "user://ruins-first-person-v4.json"
var chapter = 0
var node_id = "arrival"
var bridge = 0
var water = false
var lift = false
var shutters = false
var species: Array = []
var completed: Array = []
var memories: Array = []
var ending = ""
var elapsed = 0.0
var muted = false
var fps_position = Vector3.ZERO
var fps_valid = false
var fps_yaw = -PI / 4
var fps_pitch = -0.08
var tutorial_steps: Array[String] = []

func _ready():
	for flag in ["--garden-test", "--puzzle-test", "--playability-test", "--performance-test", "--wasteland-test", "--garden-capture", "--garden-film", "--verify-build", "--offscreen-capture"]:
		if flag in OS.get_cmdline_user_args():
			save_path = "user://garden-verification.json"
			return
	load_journey()

func fresh():
	Puzzles.reset_all()
	tutorial_steps.clear()
	chapter = 0
	node_id = "arrival"
	bridge = 0
	water = false
	lift = false
	shutters = false
	species = []
	completed = []
	memories = []
	fps_valid = false
	ending = ""
	elapsed = 0.0
	save_journey()
	changed.emit()

func next_chapter():
	Puzzles.data.robot_mode = "follow"
	Puzzles.data.robot_task = ""
	Puzzles.data.robot_position = []
	Puzzles.data.robot_cargo = false
	chapter = mini(chapter + 1, 2)
	node_id = "arrival"
	fps_valid = false
	bridge = 1
	lift = false
	save_journey()
	changed.emit()

func remember(id: int):
	if id not in memories:
		memories.append(id)
		changed.emit()
		save_journey()

func finish_chapter():
	if chapter not in completed:
		completed.append(chapter)
		save_journey()
		changed.emit()

func save_journey():
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"version": 4, "chapter": chapter, "node": node_id,
			"puzzles":Puzzles.snapshot(), "tutorial":tutorial_steps, "bridge": bridge, "water": water, "lift": lift, "shutters": shutters,
			"species": species, "completed": completed, "memories": memories,
			"ending": ending, "elapsed": elapsed, "muted": muted,
			"fps_valid":fps_valid, "fps_position":[fps_position.x,fps_position.y,fps_position.z], "fps_yaw":fps_yaw,"fps_pitch":fps_pitch}))

func load_journey():
	if not FileAccess.file_exists(save_path): return
	var value = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not value is Dictionary or value.get("version") != 4: return
	var c = value.get("chapter", 0)
	if not (c is int or c is float) or c < 0 or c > 2: return
	Puzzles.restore(value.get("puzzles",{}))
	tutorial_steps.clear()
	var lessons=value.get("tutorial",[])
	if lessons is Array:
		for skill in lessons:
			if skill in ["move","look","inspect","operate","reverse","partner"] and skill not in tutorial_steps:tutorial_steps.append(skill)
	chapter = int(c)
	var id = value.get("node", "arrival")
	if id in ["arrival", "landing", "spring", "altar", "lift_low", "lift_high", "sun", "center", "west", "east", "north", "summit", "stair_top", "entry_step", "summit_step"]:
		node_id = id
	var bridge_value = value.get("bridge",1)
	bridge = clampi(int(bridge_value),0,1) if bridge_value is float or bridge_value is int else 1
	water = value.get("water") == true
	lift = value.get("lift") == true
	shutters = value.get("shutters") == true
	for pair in [["species", species, 3], ["completed", completed, 3], ["memories", memories, 12]]:
		var values = value.get(pair[0], [])
		if values is Array:
			for item in values:
				if (item is int or item is float) and item >= 0 and item < pair[2] and int(item) not in pair[1]:
					pair[1].append(int(item))
	ending = value.get("ending", "") if value.get("ending", "") in ["", "eden", "regeneration"] else ""
	elapsed = maxf(0, value.get("elapsed", 0)) if (value.get("elapsed") is int or value.get("elapsed") is float) else 0
	muted = value.get("muted", false) == true

	var pos = value.get("fps_position", [])
	if pos is Array and pos.size() == 3 and pos.all(func(v): return (v is float or v is int) and is_finite(v)):
		fps_position = Vector3(pos[0],pos[1],pos[2])
		fps_valid = value.get("fps_valid") == true
	var yaw = value.get("fps_yaw", -PI / 4)
	var pitch = value.get("fps_pitch", -0.08)
	fps_yaw = float(yaw) if (yaw is float or yaw is int) and is_finite(yaw) else -PI / 4
	fps_pitch = clampf(float(pitch),-1.4,1.4) if (pitch is float or pitch is int) and is_finite(pitch) else -0.08
