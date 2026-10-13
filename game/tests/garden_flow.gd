extends Node
var count = 0
var errors: Array[String] = []
var garden: Node3D
var visible_target: Node3D

func check(value: bool, title: String):
	count += 1
	if not value:
		errors.append(title)
		push_error(title)

func _ready():
	run.call_deferred()

func visible_action(action: String) -> bool:
	# Real camera rays must see a clickable mechanism from at least one user-facing angle.
	for angle_index in 8:
		garden.angle = angle_index * TAU / 8
		garden.update_camera()
		await get_tree().physics_frame
		for body in garden.pickables:
			if body.get_meta("action") != action: continue
			var p = garden.camera.unproject_position(body.global_position)
			var query = PhysicsRayQueryParameters3D.create(garden.camera.project_ray_origin(p), garden.camera.project_ray_origin(p) + garden.camera.project_ray_normal(p) * 100)
			var hit = garden.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.get("collider") == body:
				visible_target = body
				return true
	return false

func run():
	Journey.save_path = "user://garden-suite.json"
	Journey.fresh()
	garden = load("res://garden.tscn").instantiate()
	add_child(garden)
	await get_tree().physics_frame
	garden.ui.close_panel()
	garden.playing = true
	check(garden.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "Camera preserves perspective depth")
	var initial_radius = garden.camera.position.distance_to(garden.focus)
	garden.distance -= 2
	garden.update_camera()
	check(garden.camera.position.distance_to(garden.focus) < initial_radius - 1, "Zoom moves the perspective camera through real space")
	garden.distance += 2
	garden.update_camera()
	garden.enter_follow_view()
	check(garden.follow_view and garden.ui.view_button.text == "总览 · V", "Follow view and view toggle agree")
	check(garden.camera.position.distance_to(garden.avatar.position) < 14, "Follow camera gives real close perspective")
	garden.avatar.position.x += 0.5
	garden._process(1.0)
	check(garden.follow_focus.distance_to(garden.avatar.position + Vector3(0,1.1,0)) < 0.02, "Follow camera tracks character position")
	garden.avatar.position.x -= 0.5
	garden.toggle_view()
	check(not garden.follow_view and garden.ui.view_button.text == "近景 · V", "Overview remains available for route planning")
	check(garden.ui.next_objective().contains("连接水源"), "Unaligned bridge has useful current objective")
	garden.ui.context_hint()
	check(not garden.ui.hud.visible and garden.ui.panel_kind == "hint", "Side panel hides competing HUD")
	garden.ui.close_panel()
	check(garden.nodes.size() == 4, "Water garden has four real path anchors")
	check(garden.route("arrival", "altar").is_empty(), "Unaligned water bridge blocks route")
	check(not await garden.walk("altar", 0.01), "Player cannot jump disconnected gap")
	check(Journey.node_id == "arrival", "Failed path does not move traveler")
	check(await visible_action("bridge"), "Water wheel visible to 3D camera ray")
	check(await visible_action("water"), "Water gate visible to 3D camera ray")
	check(await visible_action("bridge"), "Water bridge wheel found for click regression")
	garden.hovered = null
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = garden.camera.unproject_position(visible_target.global_position)
	garden._unhandled_input(click)
	await get_tree().create_timer(3.2).timeout
	check(Journey.bridge == 1, "Rapid click resolves present ray, even with no cached hover")
	check(Journey.node_id == "landing", "Bridge control automatically walks to safe landing")
	check(garden.ui.objective.text.contains("打开水闸"), "Bridge action updates next objective immediately")
	check(Journey.bridge == 1 and is_equal_approx(garden.rotor.rotation.y, PI / 2), "Bridge transform and path state agree")
	check(garden.route("arrival", "altar").size() == 4, "Connected water path uses bridge and stairs")
	check(await garden.walk("altar", 0.01), "Traveler crosses connected bridge and climbs stairs")
	check(garden.avatar.position.distance_to(garden.nodes.altar + Vector3(0, 0.04, 0)) < 0.01, "Traveler reaches true elevated coordinate")
	Journey.water = true
	Journey.finish_chapter()
	garden.refresh()
	check(garden.flow_root.visible and garden.living_root.visible, "Water appears and wetland grows")
	Journey.next_chapter()
	garden.build_chapter()
	await get_tree().physics_frame
	check(garden.route("arrival", "sun").is_empty(), "Upper sun terrace initially inaccessible")
	check(not await garden.turn_bridge(0.01), "Cannot operate upper bridge before lift")
	check(await visible_action("lift"), "Lift handle visible to 3D camera ray")
	check(await visible_action("shutters"), "Roof control visible to 3D camera ray")
	check(await garden.use_lift(0.01), "Lift operates from lower court")
	check(Journey.node_id == "lift_high" and Journey.lift, "Lift carries traveler to upper floor")
	check(garden.ui.objective.text.contains("连接温室"), "Lift action updates high bridge objective")
	check(garden.avatar.position.distance_to(garden.elevator.position + Vector3(0, 0.04, 0)) < 0.01, "Avatar stays on physical lift deck")
	check(await garden.turn_bridge(0.01), "Upper bridge aligns")
	check(await garden.walk("sun", 0.01), "Traveler walks across upper bridge")
	await garden.open_shutters(0.01)
	check(Journey.shutters and garden.shutter_panels[0].position.x == 3, "Roof really opens in 3D")
	check(garden.living_root.visible and garden.flow_root.visible, "Light shaft and plants appear")
	check(await garden.use_lift(0.01), "Can return from sun terrace and lower lift")
	check(await garden.walk("arrival", 0.01), "No soft lock after completing sun court")
	Journey.next_chapter()
	garden.build_chapter()
	await get_tree().physics_frame
	check(garden.route("arrival", "center").size() == 3, "Arrival reaches central rotating pivot")
	check(garden.route("arrival", "west").is_empty(), "Side habitats initially disconnected")
	check(garden.route("arrival", "summit").is_empty(), "Final staircase waits for all species")
	check(await visible_action("bridge"), "Central wheel visible to 3D camera ray")
	check(await visible_action("species"), "Living specimen visible to 3D camera ray")
	check(await garden.turn_bridge(0.01), "Central bridge rotates safely from entrance")
	check(await garden.walk("west", 0.01), "Flower habitat becomes reachable")
	Journey.species.append(0)
	check(await garden.walk("east", 0.01), "Opposite habitat reached across same bridge")
	Journey.species.append(1)
	check(await garden.turn_bridge(0.01), "Control returns traveler from wing before rotating")
	check(Journey.node_id == "center", "Traveler is not stranded on rotating wing")
	check(await garden.walk("north", 0.01), "Third habitat reachable after rotation")
	Journey.species.append(2)
	check(garden.route("north", "summit").size() == 2, "Complementary species unlock final steps")
	check(await garden.walk("summit", 0.01), "Traveler reaches seed summit")
	for id in 12: Journey.remember(id)
	Journey.remember(0)
	check(Journey.memories.size() == 12, "Twelve memories collect without duplicates")
	await garden.choose_ending("eden", 0.01)
	check(garden.old_shell.visible and not garden.living_root.visible, "Restart restores illuminated containment shell")
	await garden.choose_ending("regeneration", 0.01)
	check(not garden.old_shell.visible and garden.living_root.visible, "Regeneration releases growing habitat")
	Journey.save_journey()
	Journey.species = []
	Journey.ending = ""
	Journey.load_journey()
	check(Journey.species.size() == 3 and Journey.ending == "regeneration", "Spatial save roundtrip")
	garden.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("SPATIAL_TESTS: ", count, " checks; failures=", errors)
	get_tree().quit(0 if errors.is_empty() else 1)
