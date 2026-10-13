extends Node
var checks=0
var failures=[]
func check(value: bool,message: String):
	checks+=1
	if not value: failures.append(message);push_error(message)
func _ready(): run.call_deferred()
func run():
	Journey.save_path="user://wasteland-suite-v4.json";Journey.fresh()
	var garden=load("res://garden.tscn").instantiate();add_child(garden)
	await get_tree().physics_frame
	for chapter in 3:
		Journey.chapter=chapter;Journey.fps_valid=false;Journey.node_id="arrival";garden.build_chapter()
		garden.playing=true;garden.ui.close_panel()
		await get_tree().process_frame
		var field=garden.wind_field
		check(is_instance_valid(field) and field.foliage.size()>0,"Chapter %d has wind-driven vegetation"%chapter)
		check(field.find_children("*","CollisionObject3D",true,false).is_empty(),"Wind and cloth cannot obstruct the route in chapter %d"%chapter)
		var distance=field.drift_distance
		var monotonic=true
		for step in 100:
			field._process(.05)
			if field.drift_distance<=distance: monotonic=false
			distance=field.drift_distance
		check(monotonic,"Gust changes never reverse accumulated downwind travel")
		var clock=field.wind_clock
		garden.ui.pause_menu();field._process(.5)
		check(field.wind_clock==clock,"Wind, cloth and plant animation hold while menu is open")
		garden.ui.close_panel();field._process(.1)
		check(field.wind_clock>clock,"Wind resumes after closing menu")
		garden.set_recovery(0);field.update_visuals();var opening_opacity=field.dust_material.get_shader_parameter("opacity")
		garden.set_recovery(1);field.update_visuals()
		check(field.dust_material.get_shader_parameter("opacity")<opening_opacity,"Restored worlds retain wind with gentler dust")
		check(garden.soundscape.sources[0].bus=="Ambience" and garden.soundscape.sources[0].stream.get_length()>=30.0,"Coastal wind uses the independent ambience bus and a long loop")
		check(garden.geometry.find_children("DistantFactory*","Node3D",true,false).size()==5 and garden.geometry.find_children("ShoreHouse*","Node3D",true,false).size()==4,"Chapter skyline combines industrial ruins with the inhabited coast's original houses")
		var coast=garden.geometry.find_child("CoastalNeighbourhood",true,false)
		check(coast.find_children("*","CollisionObject3D",true,false).all(func(n):return n.collision_layer==0),"Coastal detail cannot intercept walking or puzzle rays")
		check(field.leaf_materials.size()>0 and is_equal_approx(field.leaf_materials[0].get_shader_parameter("wind_clock"),field.wind_clock),"Instanced leaf clusters use the paused shared wind clock")
	for asset in ["wasteland_surface","wind_dust","wind_cloth","coastal_foliage","tree_bark","ruins_water"]:
		var shader=load("res://shaders/"+asset+".gdshader")
		check(shader.get_shader_uniform_list().size()>0,"Godot shader-language compiler accepts "+asset)
	print("WASTELAND_TESTS: ",checks," checks; failures=",failures)
	garden.queue_free();await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
