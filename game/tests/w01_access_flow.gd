extends Node
var checks=0
var failures=[]
var garden
func check(value: bool,message: String):
	checks+=1
	if not value:failures.append(message);push_error(message)
func key(code):
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true
	garden._unhandled_input(event)
func _ready():run.call_deferred()
func run():
	Journey.save_path="user://w01-access-suite.json";Journey.fresh()
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	await get_tree().physics_frame
	garden.playing=true;garden.ui.close_panel();garden.enter_first_person()
	garden.capture=true;garden.walker.set_physics_process(false)
	garden.walker.yaw=-PI/2
	var start=garden.walker.position
	var supported=true
	for i in 100:
		garden.walker.move_direction(Vector2(0,-1),.016)
		await get_tree().physics_frame
		supported=supported and not is_inf(garden.floor_at(garden.walker.position))
	check(start.distance_to(garden.nodes.arrival)<.1,"W-01 approach starts at the saved chapter entrance")
	check(supported and garden.walker.position.distance_to(garden.nodes.landing)<.15,"Real continuous movement reaches W-01 without teleporting or opening the rotary bridge")
	check(Journey.bridge==0 and not Puzzles.done("water_route"),"W-01 access requires no previously completed puzzle")
	var plate: Label3D
	for n in garden.puzzle_world.find_children("*","Label3D",true,false):
		if n.text=="W-01":plate=n;break
	check(is_instance_valid(plate),"The first cabinet retains its W-01 nameplate")
	if plate:
		check(plate.global_basis.z.dot(garden.walker.eye_position()-plate.global_position)>0,"W-01 nameplate faces the reachable landing rather than the water")
		garden.aim_at(plate.global_position)
		check(not garden.camera.is_position_behind(plate.global_position),"W-01 nameplate is in front of the actual player camera")
	var runner=load("res://scripts/puzzle_playthrough.gd").new(garden)
	for i in 3:
		var body=runner.target("puzzle","pipe:%d"%i)
		var dial=garden.puzzle_world.visuals["pipes%d"%i]
		var caption=garden.puzzle_world.labels["pipes%d"%i]
		check(dial.global_basis.z.dot(garden.walker.eye_position()-dial.global_position)>0,"Reachable side shows dial %d"%i)
		check(caption.global_basis.z.dot(garden.walker.eye_position()-caption.global_position)>0,"Reachable side shows direction label %d"%i)
		check(body.global_position.distance_to(dial.global_position)<.2,"Interaction volume follows the visible dial %d"%i)
		garden.aim_at(body.global_position);await get_tree().physics_frame
		check(garden.valid_nearby_target(body) and garden.pick_at(get_viewport().get_visible_rect().size/2)==body,"Actual center ray reaches dial %d from the landing"%i)
		key(KEY_E);check(Puzzles.data.pipes[i]==1,"E turns the visible dial %d"%i)
		key(KEY_F);check(Puzzles.data.pipes[i]==0,"F reverses the visible dial %d"%i)
	check(await garden.walk("landing",.01),"Saved landing waypoint still reaches the same operating position")
	for i in 3:
		var body=runner.target("puzzle","pipe:%d"%i)
		garden.aim_at(body.global_position);await get_tree().physics_frame
		check(garden.pick_at(get_viewport().get_visible_rect().size/2)==body,"The result stone does not intercept dial %d from the exact saved waypoint"%i)
	var indicator=garden.puzzle_world.worksite.indicators.water_route
	check(indicator[1].global_basis.z.dot(garden.walker.eye_position()-indicator[1].global_position)>0,"Worksite sign and lamp turn with the W-01 cabinet")
	var before=garden.walker.position
	garden.repair_focus.allow_verification=true;garden.repair_focus.set_process(false);garden.capture=false
	Puzzles.data.pipes=[1,3,1]
	var final_dial=runner.target("puzzle","pipe:2")
	garden.aim_at(final_dial.global_position);await get_tree().physics_frame;key(KEY_E)
	check(Puzzles.done("water_route") and garden.repair_focus.queue==["water_route"],"The last real E interaction completes W-01 and queues its reveal")
	garden.repair_focus.advance(.65)
	check(plate.global_basis.z.dot(garden.camera.global_position-plate.global_position)>0,"Repair camera frames the new inward-facing W-01 front")
	garden.repair_focus.advance(1.4)
	var streams=garden.restoration.groups.water_route.find_children("*","MeshInstance3D",true,false)
	check(streams.size()==3 and streams.all(func(n):return n.global_position.z<garden.nodes.landing.z+1.13),"All three restored water streams remain on the visible console front")
	garden.repair_focus.advance(5)
	check(garden.walker.position.is_equal_approx(before) and not garden.busy,"The reveal returns control at the same reachable standing position")
	Journey.save_journey();Journey.load_journey();garden.build_chapter();await get_tree().physics_frame
	check(Puzzles.done("water_route") and garden.restoration.amounts.water_route==1,"Existing v4 save restores the solved inward-facing console")
	print("W01_ACCESS_FLOW: ",checks," checks; failures=",failures)
	garden.free();await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
