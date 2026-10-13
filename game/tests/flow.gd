extends Node
var checks = 0
var failures: Array[String] = []

func check(value: bool, name: String):
	checks += 1
	if not value:
		failures.append(name)
		push_error(name)

func _ready():
	run.call_deferred()

func run():
	State.reset()
	var world = load("res://main.tscn").instantiate()
	add_child(world)
	world.smoke_test = true
	await get_tree().physics_frame
	check(not State.core_open(), "Core closed at start")
	world.ui.interact("water", -1)
	check(not State.restored.water, "Cannot solve before seed discovery")
	world.ui.interact("seed", -1)
	check(State.discovered, "Seed discovery persisted")
	check(not State.water_valid(["湿地", "过滤"]), "Reversed water order rejected")
	world.ui.water_view()
	world.ui.try_water()
	check(not State.restored.water, "Dirty bypass rejected")
	State.water_route = ["过滤", "湿地"]
	world.ui.try_water()
	check(State.restored.water and State.stage() == 1, "Water grows roots")
	world.ui.energy_view()
	world.ui.try_energy()
	check(not State.restored.energy, "Overload rejected")
	check(not State.energy_valid([false, false, false, false, true]), "Missing greenhouse rejected")
	State.power = [false, true, false, true, true]
	world.ui.try_energy()
	check(State.restored.energy and State.stage() == 2, "Valid dispatch grows shoot")
	check(not world.advertisements[0].visible, "Ads extinguished")
	check(State.energy_valid([true, false, false, true, true]), "Alternative energy allocation accepted")
	world.ui.bio_view()
	State.plants = [0, 1, 5]
	world.ui.try_bio()
	check(not State.restored.bio, "Yield-only ecosystem rejected")
	State.plants = [1, 3, 4]
	world.ui.try_bio()
	check(State.stage() == 3, "Ecological combination unfolds leaves")
	check(State.bio_valid([2, 3, 4]), "Alternative soil protection accepted")
	check(not State.core_open(), "Six memories required despite three repairs")
	for i in 6:
		world.ui.memory_view(i)
	check(State.core_open(), "Core opens with six memories")
	State.collect(0)
	check(State.memories.size() == 6, "Memory collection idempotent")
	# Check actual world colliders using the same ray protocol as the player.
	for item in [[Vector3(-23, 1.6, 8), Vector3(-23, 1, 5.3), "water"], [Vector3(23, 1.6, 8), Vector3(23, 1, 5.3), "energy"], [Vector3(0, 1.6, -15), Vector3(0, 1, -17.7), "bio"], [Vector3(0, 1.6, 24), Vector3(0, 1, 27.3), "core"]]:
		var query = PhysicsRayQueryParameters3D.create(item[0], item[1])
		var hit = world.get_world_3d().direct_space_state.intersect_ray(query)
		check(hit.has("collider") and hit.collider.get_meta("kind", "") == item[2], "Reachable terminal: " + item[2])
	world.ui.close()
	world.player.position = Vector3(0, 1, 15)
	var key = InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	for i in 30:
		await get_tree().physics_frame
	key.pressed = false
	Input.parse_input_event(key)
	check(world.player.position.z < 14, "W key moves player in real physics")
	check(world.player.position.y > 0, "Ground collision prevents falling")
	await world.ui.choose_ending("eden")
	check(State.ending == "eden" and world.seed_glass.visible and world.advertisements[0].visible, "EDEN ending shows glass and advertisements")
	await world.ui.choose_ending("regeneration")
	check(State.ending == "regeneration" and not world.seed_glass.visible and world.greenery.ending.visible, "Regeneration ending releases plants")
	State.save_game()
	State.memories = []
	State.restored = {"water": false, "energy": false, "bio": false}
	State.load_game()
	check(State.memories.size() == 6 and State.stage() == 3 and State.ending == "regeneration", "Save roundtrip preserves final state")
	for i in 12:
		State.collect(i)
	check(State.memories.size() == 12, "All twelve archives collectible")
	State.reset()
	check(State.stage() == 0 and State.memories.is_empty() and State.ending == "", "New journey resets progress")
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("FLOW_TESTS: ", checks, " checks; failures=", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
