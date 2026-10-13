extends Node
var checks=0
var failures=[]
func check(value: bool,message: String):
	checks+=1
	if not value:failures.append(message);push_error(message)
func settle():
	await get_tree().process_frame
	await get_tree().process_frame
func key(world,code):
	var e=InputEventKey.new();e.physical_keycode=code;e.pressed=true;world._unhandled_input(e)
func use(world,node,reverse=false):
	world.aim_at(node.global_position)
	await get_tree().physics_frame
	world.use_nearby_target(reverse)
	await settle()
func _ready():run.call_deferred()
func run():
	Journey.save_path="user://tutorial-suite-v4.json";Journey.fresh()
	var world=load("res://garden.tscn").instantiate();add_child(world);await settle()
	world.ui.start_new();world.ui.finish_prologue();world.capture=true;await settle()
	var lesson=world.tutorial
	check(not world.ui.panel_open() and world.playing and lesson.view.visible,"First chapter starts directly in the playable tutorial")
	check(lesson.stage=="movement" and "W A S D" in lesson.keys.text,"Initial training explains movement before any mechanism")
	world.ui.pause_menu();await settle();check(not lesson.view.visible,"Tutorial hides while a menu is open")
	world.ui.close_panel();world.walker.yaw=-PI/2
	for i in 24:
		world.walker.move_direction(Vector2(0,-1),.05);await get_tree().physics_frame
	world.walker.look(Vector2(15,0));await settle()
	check(lesson.stage=="letter" and "E" in lesson.keys.text,"Real movement and mouse look advance to investigation")
	check(world.valid_nearby_target(lesson.target),"First letter remains within walking reach")
	await use(world,lesson.target);check(Journey.memories==[0] and world.ui.panel_kind=="memory","Investigating the real first letter advances colour and opens its text")
	world.ui.close_panel();await settle();check(lesson.stage=="route" and lesson.target.get_meta("action")=="inspect","Lesson points to the route note before teaching controls")
	await world.walk("arrival",.01)
	await use(world,lesson.target);check("route" in Puzzles.data.records,"Tutorial note is a real archived world interaction")
	world.ui.close_panel();await settle();check("E" in lesson.keys.text and "F" in lesson.keys.text,"Operation lesson teaches both directions without revealing the combination")
	await world.walk("landing",.01)
	var runner=load("res://scripts/puzzle_playthrough.gd").new(world)
	await use(world,runner.target("puzzle","pipe:0"))
	await use(world,runner.target("puzzle","pipe:1"),true)
	await use(world,runner.target("puzzle","pipe:2"));await use(world,runner.target("puzzle","pipe:2"))
	check(lesson.stage=="bridge" and not world.ui.panel_open(),"Solving routing advances the in-place lesson to the physical bridge")
	check("reverse" in Journey.tutorial_steps,"Real reverse interaction records the learned skill")
	await world.turn_bridge(.01);await settle();check(lesson.stage=="pressure","Turning the real bridge advances toward pressure training")
	await world.walk("spring",.01);await use(world,lesson.target)
	check("pressure" in Puzzles.data.records,"Pressure training reaches and archives the actual inspection note")
	world.ui.close_panel();await settle()
	await use(world,runner.target("puzzle","valve:0"),true);await use(world,runner.target("puzzle","valve:0"),true)
	await use(world,runner.target("puzzle","valve:1"))
	check(lesson.stage=="partner" and "C" in lesson.keys.text,"Correct pressure introduces companion cooperation")
	key(world,KEY_C);check(world.ui.panel_kind=="companion","Real C opens companion commands")
	for b in world.ui.content.get_children():
		if b is Button and b.text.begins_with("协助："):b.pressed.emit();break
	var deadline=Time.get_ticks_msec()+20000
	while not world.companion.ready_for("pump") and Time.get_ticks_msec()<deadline:await get_tree().create_timer(.08).timeout
	check(world.companion.ready_for("pump") and "partner" in Journey.tutorial_steps,"Companion physically reaches its task and persists the cooperation skill")
	await world.walk("altar",.01);await use(world,runner.target("water",""))
	await get_tree().create_timer(1.4).timeout;await settle()
	check(lesson.stage=="complete" and Puzzles.chapter_done(0),"Actual first-level cooperation completes the tutorial and original puzzles")
	Journey.save_journey();var saved=Journey.tutorial_steps.duplicate();Journey.tutorial_steps.clear();Journey.load_journey()
	check(Journey.tutorial_steps==saved,"Learned controls survive save and reload")
	world.ui.next_garden();world.ui.close_panel();await settle()
	check(Journey.chapter==1 and not lesson.view.visible,"Completed tutorial releases the player into chapter two without another help panel")
	var old_path=Settings.path;var old_fps=Settings.fps_limit;var old_vsync=Settings.vsync
	Settings.path="user://tutorial-video-settings.json";Settings.fps_limit=60;Settings.cycle_fps()
	check(Settings.fps_limit==120 and Engine.max_fps==120,"Frame cap can increase from 60 to 120 without restarting")
	Settings.cycle_fps();check(Engine.max_fps==144,"144 FPS cap is applied")
	Settings.cycle_fps();check(Engine.max_fps==0,"Uncapped rendering is selectable")
	Settings.path=old_path;Settings.fps_limit=old_fps;Settings.vsync=old_vsync;Settings.apply_video()
	print("TUTORIAL_TESTS: ",checks," checks; failures=",failures)
	world.queue_free();await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
