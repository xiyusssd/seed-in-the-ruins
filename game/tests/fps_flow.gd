extends Node
var count = 0
var failures = []
var garden: Node3D
func check(value: bool, message: String):
	count += 1
	if not value:
		failures.append(message)
		push_error(message)
func _ready(): run.call_deferred()
func run():
	Journey.save_path = "user://first-person-suite.json"
	Journey.fresh()
	garden = load("res://garden.tscn").instantiate()
	add_child(garden)
	await get_tree().physics_frame
	garden.playing = true
	garden.ui.close_panel()
	garden.enter_first_person()
	check(garden.first_person and not garden.avatar.visible, "Gameplay is first person without visible third person avatar")
	check(garden.camera.position.distance_to(garden.walker.eye_position()) < 0.001, "Camera sits at player eye height")
	check(garden.camera.fov == 76 and garden.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "First person field of view is perspective")
	check(garden.recovery == 0 and garden.colour_material.get_shader_parameter("recovery") == 0, "New journey starts in global grayscale")
	var yaw = garden.walker.yaw
	garden.walker.look(Vector2(50,20))
	check(garden.walker.yaw < yaw and garden.walker.pitch < -0.08, "Mouse changes first person yaw and pitch")
	garden.walker.look(Vector2(0,10000))
	check(garden.walker.pitch >= -1.4, "Mouse pitch has safe limit")
	garden.walker.pitch = 0
	garden.walker.yaw = -PI/2
	var start = garden.walker.position
	for i in 12:
		garden.walker.move_direction(Vector2(0,-1),0.016)
		await get_tree().physics_frame
	check(garden.walker.position.x > start.x + 0.2, "W moves continuously along the real starting bridge")
	check(absf(garden.walker.position.y-2.855) < 0.02, "Walking retains physical bridge height")
	check(is_inf(garden.floor_at(Vector3(-3,2.8,1))), "Unaligned bridge gap cannot be walked")
	check(is_inf(garden.floor_at(Vector3(-8.5,2.8,6.5))), "Outside walkway has no invented floor")
	var memory: Node3D
	for body in garden.pickables:
		if body.get_meta("action") == "memory" and body.get_meta("id") == "0": memory = body
	check(garden.valid_nearby_target(memory), "Nearby clue is interactable")
	garden.walker.position = Vector3(8,2.8,8)
	check(not garden.valid_nearby_target(memory), "Distant clue cannot be collected remotely")
	garden.walker.position = start
	garden.avatar.position = start
	garden.aim_at(memory.global_position)
	check(garden.pick_at(garden.get_viewport().get_visible_rect().size/2) == memory, "Center crosshair resolves real nearby clue with occlusion")
	garden.use_nearby_target()
	await get_tree().create_timer(0.2).timeout
	check(Journey.memories == [0], "E interaction records actual nearby clue")
	check(is_equal_approx(garden.recovery,1.0/12.0), "First clue restores exactly one twelfth of colour")
	check(garden.ui.panel_kind == "memory", "Clue shows readable memory panel")
	Journey.remember(0)
	check(Journey.memories.size() == 1 and is_equal_approx(garden.recovery,1.0/12.0), "Duplicate clue cannot inflate global colour")
	garden.ui.close_panel()
	garden.capture = true
	for pair in [[0,1],[1,3],[2,2]]:
		for i in pair[1]: Puzzles.operate("pipe",pair[0])
	await garden.walk("landing",0.01)
	check(await garden.turn_bridge(0.01), "First person journey still operates physical bridge")
	check(not is_inf(garden.floor_at(Vector3(-3,2.8,1))), "Aligned bridge provides actual continuous walkway")
	garden.walker.yaw = 0
	for i in 195:
		garden.walker.move_direction(Vector2(0,-1),0.016)
		await get_tree().physics_frame
	check(garden.walker.position.z < -2.0, "Continuous first person walking crosses entire physical rotary bridge")
	for i in 95:
		garden.walker.move_direction(Vector2(0,-1),0.016)
		await get_tree().physics_frame
	check(garden.walker.position.y > 4.95, "Continuous first person walking climbs real staircase without jumping")
	check(await garden.walk("altar",0.01), "Connected stairs lead to elevated water pavilion")
	check(garden.walker.position.distance_to(garden.avatar.position) < 0.01, "Guided mechanism movement keeps first person body synchronized")
	Journey.next_chapter()
	garden.build_chapter()
	check(is_equal_approx(garden.recovery,2.0/12.0), "Colour progress persists across chapters")
	check(is_inf(garden.floor_at(garden.nodes.lift_high)), "Raised landing has no imaginary floor before lift arrives")
	for pair in [[2,0],[0,1],[1,2]]:
		Puzzles.operate("take_fuse",pair[0]);Puzzles.operate("slot",pair[1])
	await garden.walk("lift_low",0.01)
	check(await garden.use_lift(0.01), "Lift carries first person player to real upper level")
	check(garden.walker.position.y > 6.9, "Player eye travels upward with lift")
	check(is_inf(garden.floor_at(garden.nodes.lift_low)), "Empty lift shaft cannot be walked when lift is raised")
	check(await garden.turn_bridge(0.01), "Upper bridge operates after lift")
	check(await garden.walk("sun",0.01), "Upper corridor reaches sunlight room")
	Puzzles.operate("mirror",0)
	for i in 3: Puzzles.operate("mirror",1)
	Puzzles.operate("roof",0,true)
	await garden.open_shutters(0.01)
	check(garden.shutter_panels[0].position.x == 3, "Sunlight roof physically opens")
	Journey.memories = [] # Controlled colour-unit setup, separate from the full interaction suite.
	for id in range(0,6): Journey.remember(id)
	check(is_equal_approx(garden.recovery,0.5), "Six unique clues restore half the entire world colour")
	garden.remember_player_position()
	Journey.save_journey()
	var saved_position = Journey.fps_position
	Journey.memories = []
	Journey.fps_valid = false
	Journey.load_journey()
	garden.on_clue_change()
	check(Journey.memories.size() == 6 and is_equal_approx(garden.recovery,0.5), "Reload restores clue count and saturation")
	check(Journey.fps_valid and Journey.fps_position.distance_to(saved_position) < 0.001, "Reload restores first person position")
	Journey.next_chapter()
	garden.build_chapter()
	garden.walker.yaw = 0
	for i in 125:
		garden.walker.move_direction(Vector2(0,-1),0.016)
		await get_tree().physics_frame
	check(garden.walker.position.y > 5.9, "Third garden entry staircase reaches physical upper landing continuously")
	check(await garden.walk("center",0.01), "Final garden reached in first person")
	await garden.turn_bridge(0.01)
	check(await garden.walk("west",0.01), "Western habitat is reachable")
	Journey.species.append(0)
	check(await garden.walk("east",0.01), "Eastern habitat is reachable")
	Journey.species.append(1)
	await garden.walk("center",0.01)
	await garden.turn_bridge(0.01)
	check(Journey.node_id == "center", "Bridge operation safely returns player from wing")
	check(await garden.walk("north",0.01), "Northern habitat is reachable")
	Journey.species.append(2)
	for i in 3:
		Puzzles.operate("take_plant",i);Puzzles.operate("bed",i)
	for i in 3:
		for j in i+1: Puzzles.operate("irrigate",i)
	garden.walker.position = garden.nodes.north + Vector3(0,0.055,-0.8)
	garden.avatar.position = garden.walker.position
	garden.walker.yaw = 0
	for i in 110:
		garden.walker.move_direction(Vector2(0,-1),0.016)
		await get_tree().physics_frame
	check(garden.walker.position.y > 8.45, "Final seed tower staircase reaches summit continuously")
	check(garden.walker.position.z < -9.0, "Player can enter seed pavilion without dome clipping the doorway")
	check(await garden.walk("summit",0.01), "Three species unlock final real staircase")
	for id in range(6,12): Journey.remember(id)
	check(garden.recovery == 1.0, "All twelve clues restore full colour")
	Puzzles.data.battery = true # Unit setup; delivery itself is checked by puzzle_flow.
	Puzzles.operate("root",0);Puzzles.operate("root",0);Puzzles.operate("root",1);Puzzles.operate("life")
	await garden.choose_ending("eden",0.01)
	check(garden.old_shell.visible and not garden.living_root.visible, "Containment ending retains physical shell")
	check(garden.old_shell.find_children("*","StaticBody3D",true,false).all(func(body):return body.collision_layer==0),"Ending decoration cannot leave invisible collision in front of the seed interaction")
	await garden.choose_ending("regeneration",0.01)
	check(not garden.old_shell.visible and garden.living_root.visible and garden.first_person, "Regeneration grows habitat while retaining first person camera")
	Journey.fresh()
	check(garden.recovery == 0, "Starting again resets the entire world to grayscale")
	for chapter in 3:
		Journey.chapter = chapter
		garden.build_chapter()
		garden.ui.chapter_opening()
		check((not garden.ui.panel_open()) if chapter==0 else (garden.ui.panel_kind == "chapter" and not garden.ui.closable), "First chapter starts in-place training; later chapters retain their letters")
		garden.ui.close_panel()
		check(garden.first_person and not garden.avatar.visible, "Chapter opening returns to first person exploration")
	check(garden.environment.fog_density > 0.012, "Grayscale world begins with a denser soft haze")
	garden.set_recovery(1.0)
	check(garden.environment.fog_density < 0.008 and garden.recovery_plants[0].scale.x > 0.44, "Colour recovery clears haze and grows plants beside machinery")
	garden.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("FIRST_PERSON_TESTS: ",count," checks; failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
