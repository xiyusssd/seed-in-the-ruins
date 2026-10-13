extends Node
var checks=0
var failures=[]
func check(value: bool,message: String):
	checks+=1
	if not value:failures.append(message);push_error(message)
func _ready():run.call_deferred()
func run():
	Journey.save_path="user://polish-suite-v4.json";Journey.fresh()
	var garden=load("res://garden.tscn").instantiate();add_child(garden)
	await get_tree().physics_frame
	for chapter in 3:
		Journey.chapter=chapter;Journey.fps_valid=false;Journey.node_id="arrival";garden.build_chapter()
		garden.playing=true;garden.ui.close_panel()
		var details=garden.puzzle_world.worksite
		check(is_instance_valid(details),"Chapter %d has independent worksite details"%chapter)
		check(details.find_children("*","CollisionObject3D",true,false).is_empty(),"New worksite decoration cannot obstruct chapter %d routes or rays"%chapter)
		check(details.work_lights.size()<=2 and details.work_lights.all(func(n):return not n.shadow_enabled),"Chapter %d stays within the two unshadowed work-light budget"%chapter)
		garden.ui.chapter_opening();await get_tree().process_frame;await get_tree().process_frame
		var scroll: ScrollContainer=garden.ui.content.get_parent()
		check(scroll.get_v_scroll_bar().max_value<=scroll.get_v_scroll_bar().page+1,"Chapter %d opening and enter button fit without scrolling"%chapter)
		garden.ui.close_panel()
	Journey.chapter=0;Journey.fps_valid=false;garden.build_chapter();garden.ui.close_panel()
	var water=garden.puzzle_world.worksite
	check(not water.level_water.visible and water.wet_surfaces.all(func(n):return not n.visible),"Unrepaired pump has no fictitious water column or puddles")
	for i in 3:
		for turn in [1,3,2][i]:Puzzles.operate("pipe",i)
	Puzzles.operate("valve",0);Puzzles.operate("valve",0);Puzzles.operate("valve",1)
	check(is_equal_approx(water.level_water.scale.y,.5),"Pressure level three fills half the six-mark tube")
	check("✓" in water.indicators.pressure[1].text,"Physical status plaque acknowledges restored pressure")
	Puzzles.reset_chapter(0)
	check(not water.level_water.visible and "○" in water.indicators.water_route[1].text,"Reset returns tube and plaques to their inactive states")
	garden.hovered=null;await get_tree().process_frame
	check(garden.ui.hud.find_children("*","Label",true,false).is_empty(),"Exploration has no diagnostic or instruction text")
	var runner=load("res://scripts/puzzle_playthrough.gd").new(garden)
	var target=runner.target("puzzle","pipe:0")
	garden.hovered=target
	garden.ui.say("水路接通。\n芽芽：水会记住你接上的这段路。")
	garden.ui._process(0);await get_tree().process_frame
	check(not garden.ui.panel_open() and garden.ui.hud.find_children("*","Label",true,false).is_empty() and not garden.ui.feedback_log.is_empty(),"Equipment hover and feedback stay in the record without covering the world")
	check(garden.ui.REPAIR_NOTES.size()==12,"Every earned letter has a matching repair archive line")
	check(garden.repair_feedback("已稳定",Puzzles.data.solved.size())=="已稳定","Repeated interaction does not pretend to earn another partner reaction")
	print("POLISH_TESTS: ",checks," checks; failures=",failures)
	garden.queue_free();await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
