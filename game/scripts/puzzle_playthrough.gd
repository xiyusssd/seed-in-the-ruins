extends RefCounted
var garden: Node3D
var failures: Array = []
var checks = 0
var recording = false
var snapshots: Array = []
func _init(g): garden=g
func check(value: bool, description: String):
	checks+=1
	if not value:
		failures.append(description)
		push_error(description)
func delay(seconds: float):
	await garden.get_tree().create_timer(seconds if recording else .025).timeout
func target(action: String,id: String) -> Node3D:
	for body in garden.pickables:
		if body.get_meta("action")==action and body.get_meta("id")==id: return body
	return null
func do_at(action: String,id: String,node: String):
	garden.ui.close_panel()
	check(await garden.walk(node,.01 if not recording else -1),"Reachable node: "+node)
	var body=target(action,id)
	check(is_instance_valid(body),"Scene target exists: "+action+":"+id)
	if not is_instance_valid(body): return
	garden.aim_at(body.global_position)
	await garden.get_tree().physics_frame
	await garden.get_tree().process_frame
	check(garden.valid_nearby_target(body),"Near-distance interaction: "+id)
	var hit=garden.pick_at(garden.get_viewport().get_visible_rect().size/2)
	check(hit==body,"Crosshair reaches unoccluded target: "+action+":"+id)
	if hit!=body:
		print("OCCLUSION: wanted=",id," hit=",hit.get_meta("action", "solid") if hit else "none"," / ",hit.get_meta("id", "") if hit else "", " position=",hit.global_position if hit else Vector3.ZERO)
		return
	garden.use_nearby_target()
	await delay(.7)
	if garden.busy:
		var until = Time.get_ticks_msec()+6000
		while garden.busy and Time.get_ticks_msec()<until:
			await garden.get_tree().create_timer(.05).timeout
	garden.ui.close_panel()
func op(name: String,index: int,node: String,count = 1):
	for i in count: await do_at("puzzle",name+":"+str(index),node)
func robot(task: String):
	garden.ui.companion_menu()
	var clicked=false
	for node in garden.ui.content.get_children():
		if node is Button and node.text.begins_with("协助："):
			node.pressed.emit();clicked=true;break
	check(clicked,"C command panel exposes cooperation")
	var deadline=Time.get_ticks_msec()+25000
	while Time.get_ticks_msec()<deadline and not garden.companion.ready_for(task):
		await garden.get_tree().create_timer(.08).timeout
	if not garden.companion.ready_for(task): print("ROBOT_DIAGNOSTIC: ",garden.companion.position," trail=",garden.companion.trail," cargo=",Puzzles.data.robot_cargo," task=",Puzzles.data.robot_task," stuck=",garden.companion.stuck)
	check(garden.companion.ready_for(task),"Robot physically arrives and keeps task: "+task)
func checkpoint(name: String):
	if recording:
		await delay(1.5)
		await garden.screenshot(name)
	elif "--polish-capture" in OS.get_cmdline_user_args():
		garden.ui.close_panel()
		await garden.walk(["landing","lift_high","center"][Journey.chapter],.4)
		if Journey.chapter==1:
			garden.walker.position+=Vector3(.3,0,-.6)
			garden.avatar.position=garden.walker.position
		garden.aim_at(garden.nodes[["altar","sun","summit"][Journey.chapter]]+Vector3(0,2.2,0))
		await garden.get_tree().create_timer(2.8).timeout
		garden.ui.close_panel()
		await garden.get_tree().process_frame
		await garden.screenshot(name)
	print("PUZZLE_CHECKPOINT: ",name," / solved=",Puzzles.data.solved)
func chapter(c: int):
	check(Puzzles.chapter_done(Journey.chapter),"Chapter gate requires all three puzzles")
	garden.ui.next_garden()
	check(Journey.chapter==c,"Chapter navigation passes solved gate")
	await delay(2.4)
	garden.ui.close_panel()
func run(film = false) -> Array:
	recording=film
	Journey.fresh();garden.build_chapter();garden.playing=true;garden.capture=true;garden.ui.close_panel();garden.enter_first_person()
	await delay(1)
	if recording: await garden.screenshot("fps-blackwhite")
	check(not await garden.turn_bridge(.01),"Water bridge cannot bypass plumbing")
	garden.ui.next_garden();check(Journey.chapter==0,"Unsolved chapter cannot advance")
	await do_at("memory","0","arrival")
	check(Journey.memories==[0],"Only environmental letter awards the first clue")
	await do_at("result","1","landing")
	check(Journey.memories==[0],"Result stones cannot bypass puzzle awards")
	await do_at("inspect","route","arrival")
	await op("pipe",0,"landing",1)
	await op("pipe",1,"landing",3)
	await op("pipe",2,"landing",2)
	check(Puzzles.done("water_route"),"Three pipe connections solve the filtration route")
	check(Journey.memories.size()==2,"Route completion awards one unique clue")
	await do_at("bridge","","landing")
	check(Journey.bridge==1,"Unlocked physical bridge rotates")
	await op("valve",0,"spring",2)
	await op("valve",1,"spring",1)
	check(Puzzles.done("pressure"),"Maintenance marks solve pressure")
	await do_at("water","","altar")
	check(not Puzzles.done("pump"),"Pump cannot start without a robot on the pedal")
	await robot("pump")
	await do_at("water","","altar")
	check(Puzzles.done("pump") and Journey.water,"Cooperation restores visible water and completes chapter")
	check(Journey.memories.size()==4,"First chapter has four earned clues")
	await checkpoint("puzzle-pump-restored")
	await chapter(1)
	check(Puzzles.data.robot_mode=="follow","Companion starts following in new chapter")
	await do_at("memory","4","arrival")
	await do_at("lift","","lift_low")
	check(not Journey.lift,"Unpowered lift cannot bypass module puzzle")
	await op("take_fuse",2,"arrival")
	await op("slot",0,"landing")
	await op("take_fuse",0,"arrival")
	await op("slot",1,"landing")
	await op("take_fuse",1,"arrival")
	await op("slot",2,"landing")
	check(Puzzles.done("power") and Puzzles.data.fuses==[2,0,1],"Physical modules fit shape-coded slots")
	if recording: await garden.screenshot("fps-midcolour")
	await do_at("lift","","lift_low")
	check(Journey.lift and garden.walker.position.y>6.9,"Powered lift carries player to upper floor")
	await op("mirror",0,"lift_high",1)
	await do_at("bridge","","lift_high")
	await op("mirror",1,"sun",3)
	check(Puzzles.done("mirrors"),"Two mirrors align the relay beam")
	await do_at("shutters","","sun")
	check(not Puzzles.done("roof"),"Roof needs the companion brake")
	await robot("roof")
	await do_at("shutters","","sun")
	check(Puzzles.done("roof") and Journey.shutters,"Partner holds brake while roof opens")
	check(Journey.memories.size()==8,"Second chapter earns four clues")
	await checkpoint("puzzle-greenhouse-restored")
	await chapter(2)
	await do_at("memory","8","landing")
	await op("take_plant",0,"landing")
	await op("take_plant",1,"landing")
	await op("take_plant",2,"landing")
	check(Puzzles.data.plant_bag.size()==3,"Satchel carries all three plants on one supply visit")
	var select=InputEventKey.new();select.physical_keycode=KEY_Q;select.pressed=true
	garden._unhandled_input(select)
	check(Puzzles.data.plant_hand==0,"Real Q input selects the flower from the satchel")
	await garden.walk("center",.01 if not recording else -1)
	await do_at("bridge","","center")
	await op("bed",0,"west")
	# The next remaining seedling becomes selected; no return trip to the rack.
	await op("bed",1,"east")
	await garden.walk("center",.01 if not recording else -1)
	await do_at("bridge","","center")
	await op("bed",2,"north")
	check(Puzzles.done("planting"),"Plants match three habitat conditions")
	await op("irrigate",2,"north",3)
	await garden.walk("center",.01 if not recording else -1)
	await do_at("bridge","","center")
	await op("irrigate",0,"west",1)
	await op("irrigate",1,"east",2)
	check(Puzzles.done("irrigation"),"Water allocation meets each bed's engraved requirement")
	await garden.walk("center",.01 if not recording else -1)
	await do_at("bridge","","center")
	await op("root",0,"summit",2)
	await op("root",1,"summit",1)
	await op("life",0,"summit")
	check(not Puzzles.done("life"),"Wind tower cannot start without battery")
	await robot("battery")
	await op("life",0,"summit")
	check(Puzzles.chapter_done(2) and Puzzles.data.battery,"Battery and connected roots restore the wind tower")
	check(Journey.memories.size()==12,"All twelve clues are earned through discovery and nine puzzles")
	await checkpoint("puzzle-garden-restored")
	await do_at("final","","summit")
	await garden.choose_ending("eden",.01 if not recording else -1)
	check(Journey.ending=="eden" and garden.old_shell.visible,"Containment ending is reachable after puzzles")
	garden.playing=true;garden.ui.close_panel()
	await garden.choose_ending("regeneration",.01 if not recording else -1)
	check(Journey.ending=="regeneration" and garden.living_root.visible,"Regeneration ending is reachable after puzzles")
	if not recording and "--polish-capture" in OS.get_cmdline_user_args():
		await garden.get_tree().create_timer(2.8).timeout;await garden.screenshot("garden-card")
	if recording:
		await delay(2.8);await garden.screenshot("garden-card");await garden.ui.save_card()
	print("PUZZLE_PLAYTHROUGH: ",checks," checks; failures=",failures)
	if film and failures.is_empty(): print("FIRST_PERSON_FILM_COMPLETE: 12 earned clues / 9 solved puzzles / full colour")
	return failures
