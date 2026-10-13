extends Node
var garden
var runner
var checks=0
var failures=[]
func check(value: bool,message: String):
	checks+=1
	if not value:failures.append(message);push_error(message)
func _ready():run.call_deferred()
func key(code):
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true
	garden._unhandled_input(event)
func stand(node: String,offset=Vector3.ZERO):
	garden.walker.position=garden.nodes[node]+offset+Vector3(0,.055,0)
	garden.avatar.position=garden.walker.position;Journey.node_id=node
	check(not is_inf(garden.floor_at(garden.walker.position)),"Reading position is on a real accessible platform: "+node)
func readable(caption: Label3D,description: String):
	var toward=garden.walker.eye_position()-caption.global_position
	check(caption.global_basis.z.dot(toward)>0,"Printed face points toward the player: "+description)
	garden.aim_at(caption.global_position)
	check(garden.camera.is_position_in_frustum(caption.global_position),"Readout is in the real player view: "+description)
	var height=garden.camera.unproject_position(caption.global_position).distance_to(garden.camera.unproject_position(caption.global_position+Vector3.UP*caption.font_size*caption.pixel_size))
	check(height>=18,"Readout has at least 18 projected pixels: "+description)
	var glyphs=true
	for char_value in caption.text:glyphs=glyphs and (char_value=="\n" or caption.font.has_char(char_value.unicode_at(0)))
	check(glyphs and not caption.text.is_empty(),"Readout uses available nonempty glyphs: "+description)
func left_to_right(captions: Array,description: String):
	var center=Vector3.ZERO
	for caption in captions:center+=caption.global_position
	garden.aim_at(center/captions.size())
	var previous=-INF;var ordered=true
	for caption in captions:
		var x=garden.camera.unproject_position(caption.global_position).x
		ordered=ordered and x>previous;previous=x
	check(ordered,"Visible left-to-right order matches the instructions: "+description)
func use(action: String,id: String,code=KEY_E):
	var body=runner.target(action,id)
	check(is_instance_valid(body),"Required target exists: "+action+":"+id)
	if not body:return
	garden.aim_at(body.global_position);await get_tree().physics_frame
	var hit=garden.pick_at(get_viewport().get_visible_rect().size/2)
	check(garden.valid_nearby_target(body) and hit==body,"Actual crosshair reaches the visible control: "+action+":"+id)
	if hit!=body:print("VISIBILITY_OCCLUSION: ",id," hit=",hit.get_meta("id","") if hit else "none")
	key(code)
func prepare(chapter: int):
	Journey.fresh();Journey.chapter=chapter;garden.build_chapter()
	garden.capture=true;garden.playing=true;garden.ui.close_panel();garden.enter_first_person()
	garden.walker.set_physics_process(false);garden.companion.set_process(false)
	garden.tutorial.suppressed=true;garden.tutorial.poll()
func plate(text_value: String) -> Label3D:
	for caption in garden.puzzle_world.find_children("*","Label3D",true,false):
		if caption.text==text_value:return caption
	return null
func run():
	Journey.save_path="user://later-visibility-suite.json";Journey.fresh()
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	await get_tree().physics_frame
	runner=load("res://scripts/puzzle_playthrough.gd").new(garden)
	prepare(0);Puzzles.data.solved=["water_route"];garden.puzzle_world.refresh()
	stand("spring")
	readable(plate("W-02"),"pressure cabinet nameplate")
	readable(garden.puzzle_world.labels.gauge,"pressure gauge")
	left_to_right([garden.puzzle_world.labels.valves0,garden.puzzle_world.labels.valves1],"inlet then return valve")
	for i in 2:
		readable(garden.puzzle_world.labels["valves%d"%i],"pressure valve %d"%i)
		await use("puzzle","valve:%d"%i);check(Puzzles.data.valves[i]==1,"Visible valve responds to E: %d"%i)
		await use("puzzle","valve:%d"%i,KEY_F);check(Puzzles.data.valves[i]==0,"Visible valve responds to F: %d"%i)
	prepare(1);Journey.lift=true;Puzzles.data.solved=["power"];garden.puzzle_world.refresh()
	for i in 2:
		stand("lift_high" if i==0 else "sun")
		readable(garden.puzzle_world.labels["mirrors%d"%i],"sunlight mirror %d direction"%i)
		await use("puzzle","mirror:%d"%i);check(Puzzles.data.mirrors[i]==1,"Visible mirror responds to E: %d"%i)
		await use("puzzle","mirror:%d"%i,KEY_F);check(Puzzles.data.mirrors[i]==0,"Visible mirror responds to F: %d"%i)
	stand("lift_high");await use("inspect","mirrors")
	check(garden.ui.panel_kind=="record" and "mirrors" in Puzzles.data.records,"Mirror instructions open from the real upper landing")
	garden.ui.close_panel()
	prepare(2)
	garden.walker.yaw=0
	var supported=true
	for i in 125:
		garden.walker.move_direction(Vector2(0,-1),.016);await get_tree().physics_frame
		supported=supported and not is_inf(garden.floor_at(garden.walker.position))
	check(supported and garden.walker.position.y>5.9,"Continuous entry-stair movement reaches the seed rack")
	stand("landing")
	readable(plate("SEEDS"),"seed rack nameplate")
	left_to_right([plate("花卉"),plate("豆科"),plate("深根")],"flower, legume, deep-root seedlings")
	for i in 3:
		readable(plate(["花卉","豆科","深根"][i]),"seed species %d"%i)
		await use("puzzle","take_plant:%d"%i)
	check(Puzzles.data.plant_bag==[0,1,2],"All three visible seedlings can be taken on one visit")
	await use("memory","8")
	check(garden.ui.panel_kind=="memory" and 8 in Journey.memories,"Relocated seed-rack letter remains readable and collectible")
	garden.ui.close_panel()
	await use("inspect","beds");check(garden.ui.panel_kind=="record","Planting instructions open from the entrance landing")
	garden.ui.close_panel();Puzzles.data.solved=["planting"];Puzzles.data.beds=[0,1,2];garden.puzzle_world.refresh()
	for i in 3:
		stand(["west","east","north"][i])
		readable(garden.puzzle_world.labels["beds%d"%i],"habitat and water requirement %d"%i)
		readable(garden.puzzle_world.labels["irrigation%d"%i],"irrigation amount %d"%i)
		await use("puzzle","irrigate:%d"%i);check(Puzzles.data.irrigation[i]==1,"Visible irrigation control responds to E: %d"%i)
		await use("puzzle","irrigate:%d"%i,KEY_F);check(Puzzles.data.irrigation[i]==0,"Visible irrigation control responds to F: %d"%i)
	Puzzles.data.solved.append("irrigation");garden.puzzle_world.refresh()
	stand("north")
	readable(garden.puzzle_world.labels.beds2,"mature deep-root bed requirement")
	readable(garden.puzzle_world.labels.irrigation2,"mature deep-root bed water amount")
	var mature=garden.puzzle_world.plants[2]
	var leaf_front=-INF
	for mesh in mature.find_children("*","MeshInstance3D",true,false):
		var box=mesh.mesh.get_aabb()
		for x in [box.position.x,box.end.x]:
			for y in [box.position.y,box.end.y]:
				for z in [box.position.z,box.end.z]:leaf_front=maxf(leaf_front,mesh.to_global(Vector3(x,y,z)).z)
	check(leaf_front<garden.walker.position.z,"Mature northern foliage remains behind the real readout-viewing position")
	stand("summit",Vector3(0,0,.7))
	readable(plate("L-03"),"root console nameplate")
	readable(plate("启动"),"wind tower start button")
	left_to_right([garden.puzzle_world.labels.roots0,garden.puzzle_world.labels.roots1],"left and right root connector")
	for i in 2:
		readable(garden.puzzle_world.labels["roots%d"%i],"root connector %d direction"%i)
		await use("puzzle","root:%d"%i);check(Puzzles.data.roots[i]==1,"Visible root connector responds to E: %d"%i)
		await use("puzzle","root:%d"%i,KEY_F);check(Puzzles.data.roots[i]==0,"Visible root connector responds to F: %d"%i)
	await use("inspect","roots");check(garden.ui.panel_kind=="record","Root and battery instructions open from the actual summit")
	garden.ui.close_panel();await use("puzzle","life:0")
	check(not Puzzles.done("life"),"Visible tower button still enforces connected roots and delivered battery")
	var before=Puzzles.snapshot();Journey.save_journey();Journey.load_journey();garden.build_chapter();await get_tree().physics_frame
	garden.walker.set_physics_process(false)
	check(Puzzles.data.roots==before.roots and Puzzles.data.records==before.records,"Later-stage controls and observed instructions persist in existing saves")
	stand("summit",Vector3(0,0,.7));readable(plate("L-03"),"root console after reloading")
	print("LATER_VISIBILITY_FLOW: ",checks," checks; failures=",failures)
	garden.free();await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
