extends Node
var checks=0
var failures=[]
var garden
func check(value: bool,message: String):
	checks+=1
	if not value:failures.append(message);push_error(message)
func _ready():run.call_deferred()
func run():
	Journey.save_path="user://isolated-exploration-v114.json";Journey.fresh()
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	await get_tree().physics_frame
	garden.playing=true;garden.capture=true;garden.ui.close_panel()
	garden.walker.set_physics_process(false);garden.companion.set_process(false);garden.tutorial.suppressed=true
	var broad=garden.nodes.arrival+Vector3(1.32,0,.85)
	check(not is_inf(garden.floor_at(broad)),"The real starting platform remains explorable outside the former small circle")
	var ray=PhysicsRayQueryParameters3D.create(broad+Vector3.UP*.5,broad-Vector3.UP*.5,1)
	check(not garden.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Expanded exploration is supported by an actual physical floor")
	check(is_inf(garden.floor_at(garden.nodes.arrival+Vector3(1.51,0,1.51))),"Capsule clearance still prevents stepping beyond the platform rim")
	check(is_inf(garden.floor_at(Vector3(-3,2.8,1))),"The closed rotary-bridge gap remains closed")
	garden.walker.position=garden.nodes.arrival+Vector3(.9,.055,-1.42);garden.walker.yaw=0
	var start=garden.walker.position;var supported=true
	for i in 35:
		garden.walker.move_direction(Vector2(-1,-1),.016);await get_tree().physics_frame
		supported=supported and not is_inf(garden.floor_at(garden.walker.position))
	check(supported and garden.walker.position.x<start.x-.5 and garden.walker.position.z>start.z-.05,"Diagonal movement slides along an edge without freezing or falling")
	garden.walker.position=garden.nodes.arrival+Vector3(-1.42,.055,1.10)
	for i in 5:
		garden.walker.move_direction(Vector2(-1,-1),.016);await get_tree().physics_frame
	check(not is_inf(garden.floor_at(garden.walker.position)),"Stone collision correction cannot push a player off the platform")
	for chapter in 3:
		Journey.chapter=chapter;Journey.lift=true;garden.build_chapter();await get_tree().physics_frame
		garden.walker.set_physics_process(false);garden.companion.set_process(false)
		for board in garden.puzzle_world.record_boards.values():
			var stone=board.get_node("BrokenInscriptionStone")
			var eye=board.get_meta("reading_position")+Vector3.UP*1.65
			var back=board.to_global(Vector3(0,1.25,-.20))
			var hit=garden.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,back,1))
			check(not hit.is_empty() and hit.collider.get_parent()==stone,"Stone is a real obstacle at its surviving inscription: "+board.name)
		var frame=garden.rotor.get_node("BridgeUnderframe")
		check(frame.find_children("*","MeshInstance3D",true,false).size()==11 and frame.find_children("*","CollisionObject3D",true,false).is_empty(),"Visible bridge bracing stays below the playable deck")
		if chapter==1:
			check(garden.geometry.find_child("LiftServiceShelf",true,false) is MeshInstance3D,"Upper inspection stone has a fixed physical service shelf")
			Journey.lift=false;garden.refresh()
			check(is_inf(garden.floor_at(garden.nodes.lift_high)),"The fixed shelf cannot invent a floor over the empty lift shaft")
	Journey.chapter=0;garden.build_chapter();await get_tree().physics_frame
	garden.walker.set_physics_process(false);garden.companion.set_process(false);garden.ui.close_panel()
	var board=garden.puzzle_world.record_boards.route
	garden.walker.position=board.get_meta("reading_position");garden.walker.yaw=board.rotation.y
	for i in 40:
		garden.walker.move_direction(Vector2(0,-1),.016);await get_tree().physics_frame
	var front=board.global_basis.z.normalized()
	check((garden.walker.position-board.global_position).dot(front)>.22,"A player walking into a stone stops in front of it")
	var old_path=Settings.path;var old_sensitivity=Settings.mouse_sensitivity
	Settings.path="user://isolated-exploration-settings.json"
	Settings.mouse_sensitivity=.5;var yaw=garden.walker.yaw;garden.walker.look(Vector2(40,0));var slow=absf(garden.walker.yaw-yaw)
	Settings.mouse_sensitivity=2.;yaw=garden.walker.yaw;garden.walker.look(Vector2(40,0));var fast=absf(garden.walker.yaw-yaw)
	check(is_equal_approx(fast,slow*4),"The mouse setting actually changes camera speed")
	Settings.save();Settings.mouse_sensitivity=.5;Settings._ready()
	check(Settings.mouse_sensitivity==2.,"Mouse sensitivity persists through settings reload")
	garden.ui.settings_menu();await get_tree().process_frame;await get_tree().process_frame
	var slider=garden.ui.content.find_child("MouseSensitivity",true,false)
	check(slider is HSlider and slider.min_value==.5 and slider.max_value==2.,"The setting can be adjusted in the real menu")
	var scroll=garden.ui.content.get_parent()
	check(scroll.get_v_scroll_bar().max_value<=scroll.get_v_scroll_bar().page+1,"All essential settings still fit on screen")
	Settings.path=old_path;Settings.mouse_sensitivity=old_sensitivity
	garden.queue_free();await get_tree().process_frame;await get_tree().process_frame
	print("EXPLORATION_FLOW: ",checks," checks; failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
