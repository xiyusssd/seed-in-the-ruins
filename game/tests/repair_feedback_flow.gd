extends Node
var checks=0
var failures=[]
var garden
func check(value: bool,message: String):
	checks+=1
	if not value:failures.append(message);push_error(message)
func _ready():run.call_deferred()
func prepare(chapter: int):
	Journey.fresh();Journey.chapter=chapter;garden.build_chapter();garden.playing=true;garden.ui.close_panel()
	garden.repair_focus.allow_verification=true;garden.repair_focus.set_process(false)
	garden.companion.set_process(false);garden.walker.set_physics_process(false)
	garden.update_camera()
func solve(task: String):
	match task:
		"water_route":Puzzles.data.pipes=[1,3,1];Puzzles.operate("pipe",2)
		"pressure":Puzzles.data.valves=[2,0];Puzzles.operate("valve",1)
		"pump":Puzzles.operate("pump",0,true)
		"power":Puzzles.data.fuses=[2,0,-1];Puzzles.data.fuse_hand=1;Puzzles.operate("slot",2)
		"mirrors":Puzzles.data.mirrors=[1,2];Puzzles.operate("mirror",1)
		"roof":Puzzles.operate("roof",0,true)
		"planting":Puzzles.data.beds=[0,1,-1];Puzzles.data.plant_bag=[2];Puzzles.data.plant_hand=2;Puzzles.operate("bed",2)
		"irrigation":Puzzles.data.irrigation=[1,2,2];Puzzles.operate("irrigate",2)
		"life":Puzzles.data.roots=[2,1];Puzzles.data.battery=true;Puzzles.operate("life",0)
func run():
	Journey.save_path="user://repair-feedback-suite.json";Journey.fresh()
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	await get_tree().process_frame
	for chapter in 3:
		prepare(chapter)
		for task in Puzzles.TASKS[chapter]:
			var view=garden.camera.global_transform;var fov=garden.camera.fov
			var p=garden.walker.position;var yaw=garden.walker.yaw;var pitch=garden.walker.pitch
			check(not garden.restoration.groups[task].visible,"Unsolved result is absent: "+task)
			solve(task)
			check(Puzzles.done(task) and garden.repair_focus.queue==[task],"Real successful operation queues one reveal: "+task)
			Puzzles.finish(task)
			check(garden.repair_focus.queue.size()==1,"Repeated completion cannot duplicate the reveal: "+task)
			garden.repair_focus.advance(.65)
			check(garden.busy and garden.repair_focus.active and garden.repair_focus.banner.visible,"Repair takes temporary camera ownership with visible feedback: "+task)
			check(garden.camera.position.distance_to(garden.repair_focus.view_for(task)[0])<.001,"Authored camera frames the physical change: "+task)
			var directed=garden.camera.global_transform;garden.update_camera()
			check(garden.camera.global_transform.is_equal_approx(directed),"Normal FPS updates do not overwrite the reveal: "+task)
			garden.repair_focus.advance(.7)
			check(garden.restoration.groups[task].visible and garden.restoration.amounts[task]>.1 and garden.restoration.amounts[task]<.9,"Physical result grows while it is framed: "+task)
			garden.remember_player_position();Journey.save_journey()
			check(Journey.fps_position.is_equal_approx(p) and Journey.fps_yaw==yaw and Journey.fps_pitch==pitch,"Autosave stores the player rather than the reveal camera: "+task)
			garden.repair_focus.advance(5)
			check(not garden.busy and not garden.repair_focus.active and garden.repair_focus.queue.is_empty(),"Control returns when the reveal ends: "+task)
			check(garden.camera.global_transform.is_equal_approx(view) and is_equal_approx(garden.camera.fov,fov),"Exact camera and FOV restore: "+task)
			check(garden.walker.position.is_equal_approx(p) and garden.walker.yaw==yaw and garden.walker.pitch==pitch,"Player position and look remain unchanged: "+task)
			check(garden.restoration.amounts[task]==1 and garden.restoration.groups[task].visible,"Completed repair remains visible: "+task)
		check(garden.restoration.find_children("*","CollisionObject3D",true,false).is_empty(),"New result geometry never blocks walking or interaction")
		Journey.save_journey();Journey.load_journey();garden.build_chapter()
		check(garden.repair_focus.queue.is_empty() and not garden.repair_focus.active,"Loading a completed chapter does not replay cinematics")
		check(garden.restoration.amounts.values().all(func(v):return v==1.0),"All completed physical results restore from the existing save")
	prepare(0);Puzzles.operate("pump",0,false)
	check(garden.repair_focus.queue.is_empty(),"Failed prerequisite produces no misleading success reveal")
	solve("water_route");garden.repair_focus.advance(.9)
	var escape=InputEventKey.new();escape.physical_keycode=KEY_ESCAPE;escape.pressed=true
	garden._unhandled_input(escape)
	check(not garden.repair_focus.active and not garden.busy and garden.ui.panel_kind=="pause","Esc cleanly skips the reveal and opens the menu")
	check(garden.restoration.amounts.water_route==1,"Skipping keeps the successful physical result")
	garden.ui.close_panel();solve("pressure");garden.repair_focus.advance(.9)
	garden.ui.title_screen();garden.repair_focus.advance(.1)
	check(not garden.repair_focus.active and not garden.busy,"Returning to title cancels camera ownership")
	prepare(1);solve("power");garden.repair_focus.advance(.9)
	Journey.chapter=2;garden.build_chapter()
	check(not garden.repair_focus.active and garden.repair_focus.queue.is_empty() and not garden.busy,"Changing chapter cannot leave a stale camera or queued reveal")
	prepare(0);garden.capture=true;solve("water_route")
	check(garden.repair_focus.queue.is_empty() and garden.restoration.amounts.water_route==1,"Controlled render captures restore scenery without surprise camera cuts")
	garden.capture=false;prepare(1);solve("power");solve("mirrors")
	check(garden.repair_focus.queue==["power","mirrors"],"Rapid success events retain their order")
	garden.repair_focus.advance(5);garden.repair_focus.advance(.1)
	check(garden.repair_focus.task=="mirrors" and garden.repair_focus.active,"The next queued reveal starts after the previous camera restores")
	garden.repair_focus.cancel()
	print("REPAIR_FEEDBACK_FLOW: ",checks," checks; failures=",failures)
	garden.free();await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
