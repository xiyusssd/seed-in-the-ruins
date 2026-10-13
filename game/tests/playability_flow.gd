extends Node
var checks=0
var failures=[]
func check(value: bool, message: String):
	checks+=1
	if not value:failures.append(message);push_error(message)
func key(garden,code):
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true
	garden._unhandled_input(event)
func _ready():run.call_deferred()
func run():
	Journey.save_path="user://playability-suite-v4.json";Journey.fresh()
	var garden=load("res://garden.tscn").instantiate();add_child(garden)
	await get_tree().physics_frame
	garden.playing=true;garden.ui.close_panel()
	var runner=load("res://scripts/puzzle_playthrough.gd").new(garden)
	var target=runner.target("puzzle","pipe:0")
	check(await garden.walk("landing",.01),"Water console is reachable for real reverse interaction")
	garden.aim_at(target.global_position);await get_tree().physics_frame
	key(garden,KEY_F)
	check(Puzzles.data.pipes[0]==3,"Real F input reverses zero to gear three")
	Puzzles.remember_record("route");garden.tutorial.poll()
	check("F" in garden.tutorial.keys.text,"First-level training explains reverse gear beside the actual machinery")
	key(garden,KEY_E)
	check(Puzzles.data.pipes[0]==0,"Real E input reverses the previous F turn")
	key(garden,KEY_E)
	check(Puzzles.feedback("water_route").begins_with("通路 1 / 3"),"Partial water routing identifies the first remaining leak")
	garden.walker.position=garden.nodes.arrival;garden.avatar.position=garden.walker.position
	garden.aim_at(target.global_position);await get_tree().physics_frame
	var position=garden.walker.position;var before=Puzzles.data.pipes.duplicate()
	key(garden,KEY_F)
	check(Puzzles.data.pipes==before and garden.walker.position==position,"Distant F input cannot turn a console or move the player there")
	garden.ui.inspect_record("route")
	check(Puzzles.data.records==["route"] and Journey.memories.is_empty(),"Reading a maintenance note archives it without awarding colour")
	garden.ui.close_panel();garden.ui.journal()
	var note_button: Button
	for child in garden.ui.content.get_children():
		if child is Button and child.text=="水路出口图":note_button=child
	check(is_instance_valid(note_button),"Tab journal contains the observed water-route note")
	if note_button:note_button.pressed.emit()
	check(garden.ui.panel_kind=="record" and Puzzles.data.records.size()==1,"Journal reopens the saved note without duplicate records")
	Journey.save_journey();Puzzles.reset_all();Journey.load_journey()
	check(Puzzles.data.records==["route"],"v4 saves persist observed maintenance records")
	Puzzles.reset_all()
	for i in 3:
		for turn in [1,3,2][i]:Puzzles.operate("pipe",i)
	check(Puzzles.done("water_route"),"Forward controls still solve the original pipe combination")
	for i in 2:
		for turn in 3:Puzzles.operate("valve",i)
	check(not Puzzles.done("pressure") and "核对" in Puzzles.feedback("pressure"),"An equal net water level cannot bypass two individual valve marks")
	Puzzles.operate("valve_back",0);Puzzles.operate("valve_back",1);Puzzles.operate("valve_back",1)
	check(Puzzles.done("pressure"),"Reverse controls can complete the pressure puzzle")
	var valves=Puzzles.data.valves.duplicate();Puzzles.operate("valve_back",0)
	check(Puzzles.data.valves==valves,"Completed machinery cannot be broken by reverse interaction")
	Puzzles.reset_all()
	for i in 3:Puzzles.operate("take_plant",i)
	check(Puzzles.data.plant_bag==[0,1,2] and Puzzles.data.plant_hand==2,"Three seedlings coexist in the satchel")
	Puzzles.operate("take_plant",2)
	check(Puzzles.data.plant_bag.size()==3,"Repeated pickup cannot duplicate a seedling")
	Journey.chapter=2;Journey.bridge=1;garden.build_chapter();garden.playing=true;garden.ui.close_panel()
	key(garden,KEY_Q)
	check(Puzzles.data.plant_hand==0,"Real Q input cycles the selected carried plant")
	garden.ui.pause_menu();key(garden,KEY_Q)
	check(Puzzles.data.plant_hand==0,"Menu input cannot change the selected plant")
	garden.ui.close_panel()
	Journey.save_journey();Puzzles.reset_all();Journey.load_journey()
	check(Puzzles.data.plant_bag==[0,1,2] and Puzzles.data.plant_hand==0,"Saving while carrying three seedlings preserves inventory and selection")
	Puzzles.operate("bed",1)
	check(Puzzles.data.beds==[-1,0,-1] and Puzzles.data.plant_bag==[1,2],"Incorrect planting removes exactly one seedling from the bag")
	check(garden.puzzle_world.plants[1].visible and garden.puzzle_world.plants[1].scale.x<.5,"Wrong habitat produces an observable plant-growth response")
	check(garden.puzzle_world.plants[1] in garden.wind_field.foliage,"Newly planted seedlings join the shared wind field")
	await garden.walk("center",.01)
	if Journey.bridge!=0:await garden.turn_bridge(.01)
	check(await garden.walk("east",.01),"The wrongly planted eastern bed remains physically reachable")
	var bed_target=runner.target("puzzle","bed:1")
	garden.aim_at(bed_target.global_position);await get_tree().physics_frame
	check(garden.pick_at(garden.get_viewport().get_visible_rect().size/2)==bed_target,"The crosshair reaches the actual wrong-plant retrieval target")
	key(garden,KEY_F)
	check(Puzzles.data.beds==[-1,-1,-1] and Puzzles.data.plant_bag.size()==3 and Puzzles.data.plant_hand==0,"A wrongly placed plant can be retrieved while other seedlings remain carried")
	for i in 3:Puzzles.operate("bed",i)
	check(Puzzles.done("planting") and Puzzles.data.beds==[0,1,2] and Puzzles.data.plant_bag.is_empty(),"One supply visit supports all three correct beds without duplicates")
	Puzzles.restore({"beds":[0,-1,-1],"plant_hand":1})
	check(Puzzles.data.plant_bag==[1] and Puzzles.data.plant_hand==1,"Legacy v4 single-plant saves migrate into the bag")
	Puzzles.restore({"beds":[0,-1,-1],"plant_hand":0,"plant_bag":[0,1,1,2,9]})
	check(Puzzles.data.plant_bag==[1,2] and Puzzles.data.plant_hand==1,"Corrupt bags are normalized without duplicating installed seedlings")
	Puzzles.remember_record("beds");Puzzles.reset_chapter(2)
	check(Puzzles.data.plant_bag.is_empty() and Puzzles.data.records==["beds"],"Chapter reset clears plants but retains observed notes")
	var reply=Puzzles.operate("slot",0)
	check("先去工具架" in reply and Puzzles.data.fuses[0]==-1 and Puzzles.data.fuse_hand==-1,"Empty interactions direct the player to supply without fabricating modules")
	var font=load("res://assets/title_font.tres")
	check(font.get_font_name()=="ZCOOL QingKe HuangYou","Headings use the new geometric Chinese typeface")
	check(font.has_char("水".unicode_at(0)) and font.has_char("芽".unicode_at(0)),"Display typeface supports key Chinese chapter and companion glyphs")
	var mono=load("res://assets/telemetry_font.tres")
	check(is_equal_approx(mono.get_string_size("0000").x,mono.get_string_size("1111").x),"Telemetry digits keep equal character widths")
	await get_tree().process_frame;await get_tree().process_frame
	garden.ui.inventory_menu()
	check(garden.ui.panel_kind=="inventory" and garden.ui.content.get_children().any(func(n):return n is Button and n.text=="返回菜单"),"Third chapter inventory remains accessible through the menu")
	garden.ui.settings_menu();await get_tree().process_frame;await get_tree().process_frame
	var scroll: ScrollContainer=garden.ui.content.get_parent()
	check(scroll.get_v_scroll_bar().max_value<=scroll.get_v_scroll_bar().page+1,"Essential settings and return button fit without scrolling")
	Journey.chapter=1;garden.build_chapter();garden.ui.close_panel()
	check(garden.puzzle_world.relay_position.x>garden.puzzle_world.visuals.mirrors0.position.x,"The visible relay actually lies east of mirror one")
	check(garden.nodes.sun.x<garden.puzzle_world.visuals.mirrors1.position.x,"The seedling receiver actually lies west of mirror two")
	print("PLAYABILITY_TESTS: ",checks," checks; failures=",failures)
	garden.queue_free();await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
