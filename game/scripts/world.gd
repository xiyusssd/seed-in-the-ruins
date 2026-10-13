extends Node3D
const PlayerScript = preload("res://scripts/player.gd")
const UIScript = preload("res://scripts/interface.gd")
const STONE = Color("536471")
const DARK = Color("263e49")
const RUST = Color("b78c62")
const TEAL = Color("72c7c0")
const GREEN = Color("9fbd76")
var player: CharacterBody3D
var ui: CanvasLayer
var environment: Environment
var sun: DirectionalLight3D
var seed: Node3D
var seed_stem: MeshInstance3D
var seed_glass: MeshInstance3D
var seed_leaves: Array = []
var seed_roots: Array = []
var greenery: Dictionary = {}
var waters: Array = []
var advertisements: Array = []
var ad_audio: AudioStreamPlayer
var ambient_audio: AudioStreamPlayer
var restored_audio: AudioStreamPlayer
var water_audio: AudioStreamPlayer
var target: Node3D
var clock = 0.0
var save_clock = 0.0
var smoke_test = false
var audio_cache = {}
var data: Array = []

func _ready():
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/memories.json"))
	build_environment()
	build_world()
	player = CharacterBody3D.new()
	player.set_script(PlayerScript)
	player.owner_world = self
	add_child(player)
	player.position = State.position
	ui = CanvasLayer.new()
	ui.set_script(UIScript)
	ui.world = self
	add_child(ui)
	State.changed.connect(refresh_world)
	build_audio()
	refresh_world()
	ui.menu()
	if "--verify-build" in OS.get_cmdline_user_args():
		await get_tree().create_timer(3).timeout
		print("EXPORTED_BUILD_OK: world, UI, font and audio loaded")
		await quit_game()
	elif "--smoke-test" in OS.get_cmdline_user_args():
		smoke_test = true
		run_smoke_test.call_deferred()
	elif "--walkthrough" in OS.get_cmdline_user_args():
		walkthrough.call_deferred()
	elif "--capture" in OS.get_cmdline_user_args():
		capture_gallery.call_deferred()

func mat(color: Color, emission = false) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if emission:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.3
	if color.a < 1:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid = true) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat(color)
	parent.add_child(node)
	node.position = pos
	if solid:
		var body = StaticBody3D.new()
		var collider = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		body.add_child(collider)
		node.add_child(body)
	return node

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat(color)
	parent.add_child(node)
	node.position = pos
	return node

func orb(parent: Node3D, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 12
	mesh.rings = 6
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat(color, true)
	parent.add_child(node)
	node.position = pos
	return node

func sign_at(text: String, pos: Vector3, size = 42, color = Color("d7e8e6")) -> Label3D:
	var label = Label3D.new()
	label.text = text
	label.font = load("res://assets/body_font.tres")
	label.font_size = size
	label.pixel_size = 0.007
	label.modulate = color
	label.outline_modulate = Color("233740")
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	label.position = pos
	return label

func build_environment():
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var material = ProceduralSkyMaterial.new()
	material.sky_top_color = Color("435b73")
	material.sky_horizon_color = Color("a1b5b8")
	material.ground_bottom_color = Color("253942")
	material.ground_horizon_color = Color("a1b5b8")
	sky.sky_material = material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a2bbc5")
	environment.ambient_light_energy = 0.65
	environment.fog_enabled = true
	environment.fog_light_color = Color("8aa5ae")
	environment.fog_density = 0.004
	var node = WorldEnvironment.new()
	node.environment = environment
	add_child(node)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -32, 0)
	sun.light_color = Color("f6d7ae")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

func build_world():
	box(self, Vector3(0, -0.3, 0), Vector3(76, 0.6, 76), STONE)
	# Courtyard paths remain open. Boundary blocks keep the player on the map.
	for pos in [Vector3(0, 2, -38), Vector3(0, 2, 38)]:
		box(self, pos, Vector3(76, 4, 1), DARK)
	for pos in [Vector3(-38, 2, 0), Vector3(38, 2, 0)]:
		box(self, pos, Vector3(1, 4, 76), DARK)
	var rng = RandomNumberGenerator.new()
	rng.seed = 404
	for i in 36:
		var angle = i * TAU / 36
		var radius = rng.randf_range(44, 56)
		var height = rng.randf_range(8, 26)
		var pos = Vector3(cos(angle) * radius, height / 2, sin(angle) * radius)
		box(self, pos, Vector3(rng.randf_range(4, 9), height, rng.randf_range(4, 8)), Color("354c5b"), false)
		for floor_index in range(2, int(height), 3):
			box(self, Vector3(pos.x, floor_index, pos.z + 4.1), Vector3(2.5, 0.12, 0.1), RUST, false)
	for x in [-6, 6]:
		box(self, Vector3(x, 0.025, 0), Vector3(0.1, 0.05, 65), RUST, false)
	for z in [-6, 6]:
		box(self, Vector3(0, 0.028, z), Vector3(65, 0.05, 0.1), RUST, false)
	for i in 22:
		var x = rng.randf_range(-10, 10)
		var z = rng.randf_range(8, 12)
		if absf(x) < 2:
			continue
		var debris = box(self, Vector3(x, 0.13, z), Vector3(0.8, 0.25, 0.55), DARK)
		debris.rotation.y = rng.randf_range(-1, 1)
	# Arrival gateway.
	for x in [-4, 4]:
		box(self, Vector3(x, 3, 18), Vector3(1, 6, 1), DARK)
	box(self, Vector3(0, 5.6, 18), Vector3(9, 0.8, 1), RUST)
	sign_at("EDEN—04\n一个从不向明天借取资源的城市", Vector3(0, 5.5, 17.3), 36)
	seed = Node3D.new()
	add_child(seed)
	seed.position = Vector3(0, 0, 0)
	cylinder(seed, Vector3(0, 0.3, 0), 1.5, 0.6, DARK)
	cylinder(seed, Vector3(0, 0.8, 0), 0.8, 0.5, RUST)
	seed_glass = cylinder(seed, Vector3(0, 1.9, 0), 0.72, 1.8, Color(0.55, 0.8, 0.83, 0.16))
	orb(seed, Vector3(0, 1.6, 0), 0.19, GREEN)
	for i in 4:
		var root = cylinder(seed, Vector3(0.08 * i, 1.25, 0), 0.025, 0.5, RUST)
		root.rotation.z = 0.25 * (i - 2)
		seed_roots.append(root)
	seed_stem = cylinder(seed, Vector3(0, 1.9, 0), 0.025, 0.5, GREEN)
	for i in 2:
		var leaf = orb(seed, Vector3(-0.17 if i == 0 else 0.17, 2.08 + i * 0.1, 0), 0.15, GREEN)
		leaf.scale = Vector3(1.6, 0.35, 0.65)
		leaf.rotation.z = -0.4 if i == 0 else 0.4
		seed_leaves.append(leaf)
	interactable(Vector3(0, 1.2, 1.1), "seed", "查看休眠种子")
	sign_at("REGENESIS / 生命信号", Vector3(0, 3.1, 0), 26, GREEN)
	build_water()
	build_energy()
	build_bio()
	build_core()
	# Three archives per area; reachable along the main courtyard paths.
	var positions = [Vector3(-4, 0, 8), Vector3(4, 0, 8), Vector3(-4, 0, 2), Vector3(-17, 0, 6), Vector3(-26, 0, 6), Vector3(-30, 0, -3), Vector3(17, 0, 6), Vector3(26, 0, 6), Vector3(30, 0, -3), Vector3(-7, 0, -20), Vector3(7, 0, -20), Vector3(7, 0, -29)]
	for i in positions.size():
		var p: Vector3 = positions[i]
		box(self, p + Vector3(0, 0.45, 0), Vector3(0.8, 0.9, 0.65), DARK)
		orb(self, p + Vector3(0, 1.1, 0), 0.09, RUST)
		interactable(p + Vector3(0, 0.9, 0), "memory", "读取记忆 · " + data[i].title, i)
		sign_at("◇ 记忆 %02d" % (i + 1), p + Vector3(0, 1.55, 0), 18, RUST)
	for key in ["water", "energy", "bio", "ending"]:
		var group = Node3D.new()
		add_child(group)
		greenery[key] = group
		var center = {"water": Vector3(-24, 0, 0), "energy": Vector3(24, 0, 0), "bio": Vector3(0, 0, -24), "ending": Vector3.ZERO}[key]
		for i in (45 if key == "ending" else 16):
			grow_plant(group, center + Vector3(rng.randf_range(-7, 7), 0, rng.randf_range(-5, 5)), rng.randf_range(0.4, 1.1), i % 4 == 0)

func interactable(pos: Vector3, kind: String, hint: String, id = -1):
	var body = StaticBody3D.new()
	body.set_meta("kind", kind)
	body.set_meta("hint", hint)
	body.set_meta("id", id)
	add_child(body)
	body.position = pos
	var collider = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.25, 1.7, 1.25)
	collider.shape = shape
	body.add_child(collider)

func terminal(pos: Vector3, kind: String, title: String):
	box(self, pos + Vector3(0, 0.6, 0), Vector3(1.4, 1.2, 0.8), DARK)
	var screen = box(self, pos + Vector3(0, 1.4, -0.1), Vector3(1.3, 0.7, 0.1), TEAL, false)
	screen.material_override = mat(TEAL, true)
	interactable(pos + Vector3(0, 1, 0), kind, "打开" + title)
	sign_at(title, pos + Vector3(0, 2.3, 0), 25, TEAL)

func build_water():
	sign_at("01 / 水循环区\nWATER RECLAMATION", Vector3(-24, 5, 0), 44)
	for x in [-19, -27]:
		box(self, Vector3(x, 0.4, -1), Vector3(5, 0.8, 8), DARK)
		var water = box(self, Vector3(x, 0.85, -1), Vector3(4.5, 0.08, 7.5), Color("746946"), false)
		waters.append(water)
		for z in [-5, 3]:
			box(self, Vector3(x, 1, z), Vector3(5, 0.2, 0.2), RUST)
	for x in [-16, -31]:
		cylinder(self, Vector3(x, 1.5, -5), 1, 3, STONE)
		box(self, Vector3(x, 3, -2), Vector3(0.25, 0.25, 7), RUST, false)
	terminal(Vector3(-23, 0, 5), "water", "水路控制台")

func build_energy():
	sign_at("02 / 能源区\nFINITE ENERGY", Vector3(24, 5, 0), 44)
	for x in [18, 23, 28]:
		for z in [-2, -7]:
			box(self, Vector3(x, 1, z), Vector3(0.25, 2, 0.25), RUST)
			var panel = box(self, Vector3(x, 2.1, z), Vector3(4, 0.15, 3), Color("234959"), false)
			panel.rotation.x = -0.28
			for row in 4:
				box(panel, Vector3(0, 0.09, -1.2 + row * 0.7), Vector3(3.9, 0.02, 0.02), TEAL, false)
	for x in [-9, 9]:
		box(self, Vector3(x, 3, 11), Vector3(0.2, 6, 0.2), DARK)
		var ad = box(self, Vector3(x, 5, 11), Vector3(4.2, 2.4, 0.15), RUST, false)
		ad.material_override = mat(RUST, true)
		advertisements.append(ad)
		var label = sign_at("100% SUSTAINABLE\n明天，再买一个", Vector3(x, 5, 10.8), 28)
		advertisements.append(label)
	terminal(Vector3(23, 0, 5), "energy", "能源调度台")

func build_bio():
	sign_at("03 / 生物温室\nROOM FOR DIFFERENCE", Vector3(0, 5.3, -24), 44)
	for x in [-9, 9]:
		for z in [-18, -25, -32]:
			box(self, Vector3(x, 2.5, z), Vector3(0.3, 5, 0.3), RUST)
	for z in [-18, -25, -32]:
		box(self, Vector3(0, 4.8, z), Vector3(18, 0.25, 0.25), RUST)
	for x in [-4, 4]:
		for z in [-23, -28]:
			box(self, Vector3(x, 0.45, z), Vector3(4, 0.9, 3), DARK)
			for j in 6:
				cylinder(self, Vector3(x - 1.4 + j * 0.55, 1.3, z), 0.04, 0.9, Color("9c987b"))
	terminal(Vector3(0, 0, -18), "bio", "温室种植台")

func build_core():
	for x in [-5, 5]:
		box(self, Vector3(x, 2.5, 28), Vector3(0.7, 5, 6), DARK)
	box(self, Vector3(0, 5, 28), Vector3(10, 0.7, 6), DARK)
	box(self, Vector3(0, 2.5, 31), Vector3(10, 5, 0.6), DARK)
	terminal(Vector3(0, 0, 27), "core", "再生计划 / 核心档案")
	sign_at("REGENESIS\n给后来者的礼物", Vector3(0, 5.9, 27), 36, GREEN)

func grow_plant(parent: Node3D, p: Vector3, height: float, flower: bool):
	cylinder(parent, p + Vector3(0, height / 2, 0), 0.035, height, GREEN)
	for side in [-1, 1]:
		var leaf = orb(parent, p + Vector3(side * height * 0.2, height * 0.7, 0), height * 0.2, GREEN)
		leaf.scale = Vector3(1.5, 0.25, 0.65)
		leaf.rotation.z = side * 0.4
	if flower:
		orb(parent, p + Vector3(0, height, 0), 0.085, Color("f0c590"))

func build_audio():
	if DisplayServer.get_name() == "headless":
		return
	ambient_audio = audio_loop("wind", -23)
	ad_audio = audio_loop("advert", -25)
	restored_audio = audio_loop("life", -80)
	water_audio = audio_loop("water", -80)

func audio_loop(key: String, volume: float) -> AudioStreamPlayer:
	var node = AudioStreamPlayer.new()
	node.stream = load("res://audio/" + key + ".wav")
	node.volume_db = volume
	add_child(node)
	node.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	node.stream.loop_end = int(node.stream.get_length() * node.stream.mix_rate)
	node.play()
	return node

func play_sound(key: String, volume = -14):
	if smoke_test:
		return
	var node = AudioStreamPlayer.new()
	node.stream = load("res://audio/" + key + ".wav")
	node.volume_db = volume
	add_child(node)
	node.finished.connect(node.queue_free)
	node.play()

func refresh_world():
	for key in greenery:
		greenery[key].visible = State.restored.get(key, false) if key != "ending" else State.ending == "regeneration"
	for water in waters:
		water.material_override = mat(TEAL if State.restored.water else Color("746946"))
	for node in seed_roots:
		node.visible = State.stage() >= 1
	seed_stem.visible = State.stage() >= 2
	for i in seed_leaves.size():
		seed_leaves[i].visible = State.stage() >= i + 2
	seed_glass.visible = State.ending != "regeneration"
	var ads_on = State.ending == "eden" or (State.ending != "regeneration" and State.power[0])
	for node in advertisements:
		node.visible = ads_on
	if ad_audio:
		ad_audio.volume_db = -25 if ads_on else -80
	if water_audio:
		water_audio.volume_db = -27 if State.restored.water else -80
	if restored_audio:
		restored_audio.volume_db = -28 if State.stage() > 0 else -80
	var light_energy = 1.1 + State.stage() * 0.12
	var tween = create_tween()
	tween.tween_property(sun, "light_energy", light_energy, 2)
	if ui:
		ui.update_hud()

func _process(delta):
	clock += delta
	if seed:
		seed.get_child(3).position.y = 1.6 + sin(clock * 1.8) * 0.04
	if not player or not player.active:
		return
	save_clock += delta
	if save_clock > 8:
		save_clock = 0
		State.save_game()
	var camera = player.camera
	var query = PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * 4)
	query.exclude = [player.get_rid()]
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	target = hit.get("collider")
	if target and target.has_meta("kind"):
		ui.hint.text = "E  ·  " + target.get_meta("hint")
	else:
		target = null
		ui.hint.text = ""
	ui.update_location(player.position)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if player.active:
				ui.pause_menu()
			elif ui.can_close:
				ui.close()
		elif player.active and event.physical_keycode == KEY_E and target:
			play_sound("interact")
			ui.interact(target.get_meta("kind"), target.get_meta("id"))
		elif player.active and event.physical_keycode == KEY_TAB:
			ui.journal()
		elif player.active and event.physical_keycode == KEY_M:
			ui.map_view()

func run_smoke_test():
	ui.close()
	ui.interact("seed", -1)
	ui.close()
	for i in 12:
		ui.interact("memory", i)
		ui.close()
	for kind in ["water", "energy", "bio", "core"]:
		ui.interact(kind, -1)
		ui.close()
	print("WORLD_SMOKE_OK: built courtyard, 12 memories, all terminals; nodes=", get_tree().get_node_count())
	get_tree().quit()

func capture_gallery():
	State.reset()
	ui.close()
	player.active = false
	player.position = Vector3(0, 1, 15)
	player.camera.rotation.x = -0.07
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(1).timeout
	get_viewport().get_texture().get_image().save_png("res://../builds/courtyard.png")
	ui.menu()
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png("res://../builds/menu.png")
	ui.close()
	ui.seed_view()
	ui.interact("water", -1)
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png("res://../builds/water.png")
	await quit_game()

func stop_audio():
	for node in [ambient_audio, ad_audio, restored_audio, water_audio]:
		if is_instance_valid(node):
			node.stop()
			node.stream = null

func hold(seconds: float):
	await get_tree().create_timer(seconds).timeout

func travel(pos: Vector3, look: Vector3, seconds: float):
	ui.close()
	player.active = false
	player.look_at(Vector3(look.x, player.position.y, look.z))
	player.camera.rotation.x = -0.02
	var tween = create_tween()
	tween.tween_property(player, "position", pos, seconds).set_trans(Tween.TRANS_SINE)
	await tween.finished

func shot(name: String):
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../builds/" + name + ".png")

func walkthrough():
	# Automated, uncut walkthrough of real game states, not a trailer or claimed user study.
	State.reset()
	player.position = Vector3(0, 1, 15)
	await hold(3)
	await travel(Vector3(0, 1, 3.5), Vector3.ZERO, 4)
	ui.seed_view()
	await hold(4)
	for i in 6:
		State.collect(i)
	ui.memory_view(6)
	await hold(4)
	await travel(Vector3(-23, 1, 8), Vector3(-23, 1, 5), 3)
	ui.water_view()
	await hold(3)
	ui.set_route(0, "过滤")
	await hold(1)
	ui.set_route(1, "湿地")
	await hold(1)
	ui.try_water()
	await hold(3)
	await travel(Vector3(-24, 1, 9), Vector3(-24, 1, 0), 2)
	await shot("water-restored")
	await hold(2)
	await travel(Vector3(23, 1, 8), Vector3(23, 1, 5), 4)
	ui.energy_view()
	await hold(3)
	ui.toggle_power(0)
	await hold(1)
	ui.toggle_power(2)
	await hold(1)
	ui.try_energy()
	await hold(3)
	await travel(Vector3(0, 1, -15), Vector3(0, 1, -20), 4)
	ui.bio_view()
	await hold(3)
	for i in [1, 3, 4]:
		ui.toggle_plant(i)
		await hold(0.7)
	ui.try_bio()
	await hold(3)
	await travel(Vector3(0, 1, -17), Vector3(0, 1, -28), 2)
	await shot("greenhouse-restored")
	await travel(Vector3(0, 1, 23), Vector3(0, 1, 28), 4)
	ui.core_view()
	await hold(6)
	await ui.choose_ending("regeneration")
	await shot("seed-card")
	await ui.save_card()
	await hold(1)
	ui.ending_card()
	await hold(4)
	ui.close()
	player.active = false
	await travel(Vector3(0, 1, 6), Vector3.ZERO, 2)
	await shot("regeneration")
	await hold(4)
	print("WALKTHROUGH_COMPLETE")
	await quit_game()

func _exit_tree():
	stop_audio()

func quit_game():
	State.save_game()
	stop_audio()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
