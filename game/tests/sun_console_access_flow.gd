extends Node
var checks=0
var failures=[]
var garden
var runner
func check(value: bool,message: String):
	checks+=1
	if not value:failures.append(message);push_error(message)
func key(code):
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true
	garden._unhandled_input(event)
func use(action: String,id: String,code=KEY_E):
	var body=runner.target(action,id)
	check(is_instance_valid(body),"Chapter two target exists: "+id)
	if not body:return
	garden.aim_at(body.global_position);await get_tree().physics_frame
	check(garden.valid_nearby_target(body) and garden.pick_at(get_viewport().get_visible_rect().size/2)==body,"Real player crosshair reaches chapter two target: "+id)
	key(code)
func plate(title: String) -> Label3D:
	for node in garden.puzzle_world.find_children("*","Label3D",true,false):
		if node.text==title:return node
	return null
func faces_player(node: Node3D) -> bool:
	return node.global_basis.z.dot(garden.walker.eye_position()-node.global_position)>0
func _ready():run.call_deferred()
func run():
	Journey.save_path="user://sun-console-access-suite.json";Journey.fresh();Journey.chapter=1
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	await get_tree().physics_frame
	garden.capture=true;garden.playing=true;garden.ui.close_panel();garden.enter_first_person()
	garden.walker.set_physics_process(false)
	runner=load("res://scripts/puzzle_playthrough.gd").new(garden)
	check(faces_player(plate("MODULES")),"Module rack faces the reachable entrance")
	await use("puzzle","take_fuse:0")
	check(Puzzles.data.fuse_hand==0,"Visible module can be picked up using E")
	garden.walker.yaw=-PI/2
	var supported=true
	for i in 125:
		garden.walker.move_direction(Vector2(0,-1),.016)
		await get_tree().physics_frame
		supported=supported and not is_inf(garden.floor_at(garden.walker.position))
	check(supported and garden.walker.position.distance_to(garden.nodes.landing)<.15,"Actual continuous entrance movement reaches S-01 safely")
	check(not Journey.lift and not Puzzles.done("power"),"S-01 is accessible before the lift has power")
	check(faces_player(plate("S-01")),"S-01 nameplate faces the platform interior")
	var screen_x=[]
	garden.aim_at(garden.nodes.landing+Vector3(0,1,1.2))
	for i in 3:
		var caption=garden.puzzle_world.labels["fuses%d"%i]
		check(faces_player(caption),"Shape and installed-module readout face the player: slot %d"%i)
		check(caption.text==["□","○","△"][i]+"\n—","Empty slot retains its required shape and empty indicator: %d"%i)
		check(caption.font.has_char(["□","○","△"][i].unicode_at(0)),"The font includes the required shape glyph: %d"%i)
		screen_x.append(garden.camera.unproject_position(caption.global_position).x)
		var body=runner.target("puzzle","slot:%d"%i)
		garden.aim_at(body.global_position);await get_tree().physics_frame
		check(garden.pick_at(get_viewport().get_visible_rect().size/2)==body,"S-01 slot %d is not intercepted by another target"%i)
		garden.aim_at(garden.nodes.landing+Vector3(0,1,1.2))
	check(screen_x[0]<screen_x[1] and screen_x[1]<screen_x[2],"Required shapes appear left to right as square, circle, triangle")
	check(faces_player(garden.puzzle_world.worksite.indicators.power[1]),"Power status sign faces the same accessible side")
	await use("inspect","power")
	check(garden.ui.panel_kind=="record" and "power" in Puzzles.data.records,"The visible maintenance record opens and is archived")
	garden.ui.close_panel()
	await use("puzzle","slot:0")
	check(Puzzles.data.fuses==[0,-1,-1] and not Puzzles.done("power"),"An incorrect visible module does not bypass the puzzle")
	check(garden.puzzle_world.labels.fuses0.text=="□\n○","The board displays both required and incorrectly installed shapes")
	Journey.save_journey();Journey.load_journey();garden.build_chapter();await get_tree().physics_frame
	garden.walker.set_physics_process(false)
	check(Puzzles.data.fuses==[0,-1,-1] and garden.puzzle_world.labels.fuses0.text=="□\n○" and faces_player(plate("S-01")),"A partial v4 save restores readable installed content and cabinet orientation")
	await use("puzzle","slot:0",KEY_F)
	check(Puzzles.data.fuses==[-1,-1,-1] and Puzzles.data.fuse_hand==0,"F retrieves the incorrectly installed visible module")
	for i in 3:
		check(await garden.walk("arrival",.01),"Return to the module rack is reachable: %d"%i)
		await use("puzzle","take_fuse:%d"%[2,0,1][i])
		check(await garden.walk("landing",.01),"Return to the visible power board is reachable: %d"%i)
		await use("puzzle","slot:%d"%i)
	check(Puzzles.done("power") and Puzzles.data.fuses==[2,0,1],"Real E interactions install all three shapes and power the lift")
	for i in 3:
		check(garden.puzzle_world.labels["fuses%d"%i].text==["□\n□","○\n○","△\n△"][i],"Completed board displays each matching shape pair: %d"%i)
	check(garden.puzzle_world.worksite.indicators.power[1].text=="S-01 ✓","Visible power status updates when the puzzle is solved")
	Journey.save_journey();Journey.load_journey();garden.build_chapter();await get_tree().physics_frame
	check(Puzzles.done("power") and faces_player(plate("S-01")),"Completed v4 save restores the powered inward-facing board")
	print("SUN_CONSOLE_ACCESS_FLOW: ",checks," checks; failures=",failures)
	garden.free();await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
