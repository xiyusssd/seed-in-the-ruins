extends Node
# Run only in an isolated Xvfb display through tools/render_background.py.
var garden
var output="/review"
var captures: Array=[]
var inventory: Array=[]
var light_inventory: Array=[]
var reflection_inventory: Array=[]
var mesh_checks: Dictionary={}
var structural_inventory: Array=[]
var failures: Array=[]
func _ready():run.call_deferred()
func colour(value: float):
	if garden.colour_tween and garden.colour_tween.is_valid():garden.colour_tween.kill()
	garden.set_recovery(value)
func frames(count=3):
	for i in count:await RenderingServer.frame_post_draw
func shot(name: String,eye: Vector3,target: Vector3,fov=64.0):
	garden.camera.position=eye
	garden.camera.look_at(target)
	garden.camera.fov=fov
	await frames(4)
	var image=get_viewport().get_texture().get_image()
	if image.is_empty():failures.append("Empty render: "+name);return
	var error=image.save_png(output.path_join(name+".png"))
	if error!=OK:failures.append("Cannot save: "+name)
	captures.append({"name":name,"chapter":Journey.chapter,"eye":str(eye),"target":str(target),"width":image.get_width(),"height":image.get_height(),"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)})
	print("RENDER_FRAME ",name)
func ui_shot(name: String):await shot(name,garden.camera.position,garden.camera.position-garden.camera.global_basis.z)
func material_name(material):
	if material is ShaderMaterial:return material.shader.resource_path
	if material is StandardMaterial3D:
		return "PBR / "+(material.albedo_texture.resource_path if material.albedo_texture else str(material.albedo_color))
	return "missing"
func audit():
	var capture=garden.geometry.find_child("CoastalReflectionCapture",true,false)
	if not capture or (capture.cull_mask & garden.water_mesh.layers)!=0 or (capture.reflection_mask & garden.water_mesh.layers)==0:
		failures.append("Invalid coastal reflection visibility masks")
	else:
		reflection_inventory.append({"chapter":Journey.chapter,"restored":Puzzles.chapter_done(Journey.chapter),"size":str(capture.size),"intensity":capture.intensity,"shadows":capture.enable_shadows,"cull_mask":capture.cull_mask,"reflection_mask":capture.reflection_mask,"water_layers":garden.water_mesh.layers})
	# MultiMesh transform retrieval requires a real rasterizer; the dummy headless
	# renderer returns zero matrices, so support checks belong in this audit.
	var city=garden.geometry.find_child("CinematicRuins",true,false)
	var frame=city.find_child(["PumpServiceMembers","RoofTrussMembers","OrangeryRoofMembers"][Journey.chapter],true,false)
	var endpoints=frame.get_meta("member_endpoints")
	var valid_members=0
	for i in endpoints.size():
		var tr=frame.multimesh.get_instance_transform(i)
		if (tr*Vector3(0,-.5,0)).distance_to(endpoints[i][0])<.0001 and (tr*Vector3(0,.5,0)).distance_to(endpoints[i][1])<.0001:valid_members+=1
		else:failures.append("Structural section does not contact its actual end joints")
	structural_inventory.append({"chapter":Journey.chapter,"members":endpoints.size(),"contacts_verified":valid_members,"material":material_name(frame.material_override)})
	var piles=city.find_child("QuayTimber",true,false);var submerged_piles=0
	for i in piles.multimesh.instance_count:
		var tr=piles.multimesh.get_instance_transform(i)
		if (tr*Vector3(0,-.5,0)).y<-2:submerged_piles+=1
	if submerged_piles!=18:failures.append("Timber pier supports terminate above the sea")
	if Journey.chapter==1:
		var supports=[];var supported=0
		for arch in city.find_children("*","MultiMeshInstance3D",true,false):
			if arch.multimesh.mesh.get_aabb().size.is_equal_approx(Vector3(3.5,.1,.17)):
				for i in arch.multimesh.instance_count:supports.append(arch.multimesh.get_instance_transform(i))
		for pot in city.find_children("*","MeshInstance3D",true,false).filter(func(n):return n.material_override is StandardMaterial3D and n.material_override.albedo_texture and "generated_garden/terracotta" in n.material_override.albedo_texture.resource_path):
			if pot.position.y<2:continue
			supported+=1;var contact=false
			for support in supports:
				var local=support.affine_inverse()*pot.position
				if absf(local.x)<1.75 and absf(local.z)<.085 and absf(local.y-.05)<.001:contact=true
			if not contact:failures.append("Raised pot lacks a table surface beneath it")
		if supported!=8:failures.append("Missing raised greenhouse pots")
	for n in garden.geometry.find_children("*","Light3D",true,false):
		light_inventory.append({"chapter":Journey.chapter,"restored":Puzzles.chapter_done(Journey.chapter),"path":str(n.get_path()),"type":n.get_class(),"energy":n.light_energy,"color":str(n.light_color),"shadows":n.shadow_enabled,"range":n.spot_range if n is SpotLight3D else n.omni_range if n is OmniLight3D else 0.0})
	for n in garden.geometry.find_children("*","GeometryInstance3D",true,false):
		if not (n is MeshInstance3D or n is MultiMeshInstance3D):continue
		var mesh=n.mesh if n is MeshInstance3D else n.multimesh.mesh if n.multimesh else null
		if not mesh:failures.append("Missing mesh: "+str(n.get_path()));continue
		var materials=[]
		for surface in mesh.get_surface_count():
			var mat=n.material_override
			if not mat and n is MeshInstance3D:mat=n.get_surface_override_material(surface)
			if not mat:mat=mesh.surface_get_material(surface)
			materials.append(material_name(mat))
			if not mat:failures.append("Missing material: "+str(n.get_path()))
		var id=mesh.get_instance_id()
		if id not in mesh_checks:
			var vertices=0;var invalid=0;var no_normals=0
			for surface in mesh.get_surface_count():
				var arrays=mesh.surface_get_arrays(surface)
				var positions=arrays[Mesh.ARRAY_VERTEX]
				var normals=arrays[Mesh.ARRAY_NORMAL]
				vertices+=positions.size()
				for p in positions:if not p.is_finite():invalid+=1
				if normals==null:no_normals+=1
			mesh_checks[id]={"vertices":vertices,"nonfinite_vertices":invalid,"surfaces_without_normals":no_normals}
			if invalid or no_normals:failures.append("Invalid vertex data: "+str(n.get_path()))
		if not n.global_transform.origin.is_finite():failures.append("Nonfinite transform: "+str(n.get_path()))
		inventory.append({"chapter":Journey.chapter,"restored":Puzzles.chapter_done(Journey.chapter),"path":str(n.get_path()),"visible":n.is_visible_in_tree(),"materials":materials,"mesh":mesh_checks[id],"instances":n.multimesh.instance_count if n is MultiMeshInstance3D else 1})
func chapter(index: int):
	Journey.fresh();Journey.chapter=index;garden.build_chapter()
	garden.capture=true;garden.playing=true;garden.set_process(false)
	garden.walker.set_physics_process(false);garden.companion.set_process(false)
	garden.ui.close_panel();garden.tutorial.suppressed=true;colour(1.0)
	# UPDATE_ONCE fills six cubemap faces before its roughness mip chain.
	await frames(12)
	audit()
	if RenderingServer.get_current_rendering_method()=="forward_plus":save_model_scene(index)
func run():
	if DisplayServer.get_name()=="headless":
		push_error("Render audit requires a real rasterizer inside Xvfb, not dummy headless");get_tree().quit(1);return
	Engine.max_fps=10
	Journey.save_path="user://isolated-render-review.json"
	Journey.fresh()
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	# Remove history across the inspection camera cuts; gameplay keeps reprojection.
	garden.environment.volumetric_fog_temporal_reprojection_enabled=false
	await chapter(0)
	await reference_tide()
	await shot("render-01-coastal-reflections",Vector3(22,.8,16),Vector3(-14,8,-14))
	await shot("01-pump-overview",Vector3(14,14,21),Vector3(-2,3,-4))
	await horizon_shots()
	await shot("cg-01-town",Vector3(-12,12,26),Vector3(-43,12,-26))
	await shot("cg-02-quay",Vector3(11,3.1,10),Vector3(7,1.8,-3))
	await shot("cg-03-city-wall",Vector3(-28,4.4,5),Vector3(-32.9,4.7,7))
	await shot("detail-01-jetty",Vector3(20,4.0,12),Vector3(15.5,1.3,7.1))
	await shot("detail-02-roof-damage",Vector3(-40,16,-59),Vector3(-37.3,11.5,-55.4))
	await shot("cg-04-wet-paving",Vector3(9,2.35,5.3),Vector3(9,1.38,3))
	await shot("02-pump-machinery",Vector3(-.5,7,-2),Vector3(-3,6,-8))
	await shot("02b-tank-fasteners",Vector3(7,4,-1),Vector3(4.5,3,-6))
	await shot("03-pipe-controls",Vector3(-3,4.6,4.35),Vector3(-3,3.9,6.0))
	await shot("04-pressure-gauge",Vector3(-.4,4.7,-.3),Vector3(-3,3.9,-2))
	await shot("05-yaya",garden.companion.position+Vector3(1.3,.95,1.5),garden.companion.position+Vector3(0,.5,0))
	for i in 4:
		var house=garden.geometry.find_child("ShoreHouse%d"%i,true,false)
		await shot("06-house-%d"%i,house.to_global(Vector3(11,6,-16)),house.to_global(Vector3(0,3.4,0)))
	var h=garden.geometry.find_child("ShoreHouse0",true,false)
	await plant_details(h)
	await shot("ai-01-plaster-close",h.to_global(Vector3(-4.05,4.65,-4.6)),h.to_global(Vector3(-4.05,4.5,-3)))
	await shot("08-tiles-balcony",h.to_global(Vector3(2,7,-11)),h.to_global(Vector3(0,4.5,-2)))
	await shot("08b-side-windows",h.to_global(Vector3(10,4,-1)),h.to_global(Vector3(4.1,3.8,0)))
	await shot("shore-01-soil-bank",h.to_global(Vector3(10,3.1,-7)),h.to_global(Vector3(5.9,-.1,-2.8)))
	await shot("shore-02-tidal-water",h.to_global(Vector3(10,1.7,-2)),h.to_global(Vector3(7.9,-.65,0)))
	await shot("shore-03-meadow",h.to_global(Vector3(6.9,1.25,-3.8)),h.to_global(Vector3(5.4,.4,-1.3)))
	await shot("09-sea",Vector3(-9,2.6,14),Vector3(-6,-1,50))
	await shot("shore-04-ripples",Vector3(-9,.6,14),Vector3(-7,-1.3,23))
	await shot("ai-02-concrete-close",garden.nodes.landing+Vector3(-.8,1.1,.75),garden.nodes.landing+Vector3(-.8,0,.4))
	await shot("10-ground-bridge",Vector3(-5,4.2,1),Vector3(-3,2.8,-1))
	Puzzles.data.pipes=[1,3,2];Puzzles.data.valves=[2,1]
	for task in Puzzles.TASKS[0]:Puzzles.finish(task)
	Journey.water=true;Journey.bridge=1;garden.refresh();garden.puzzle_world.refresh();colour(1)
	await frames(4);audit()
	await shot("10b-restored-water",Vector3(2,7,3),Vector3(-2,4,-4))
	colour(0);await shot("11-monochrome",Vector3(-7,4.4,5),Vector3(-1,4,-3))
	colour(.5);await ui_shot("12-half-colour")
	colour(1);await ui_shot("13-full-colour")
	colour(0)
	garden.ui.title_screen();await ui_shot("ui-title")
	for i in 3:
		garden.ui.prologue_screen(i,"title");await frames(5);await ui_shot("ui-story-%d"%i)
	garden.playing=true;garden.ui.pause_menu();await ui_shot("ui-pause")
	var resume_button=garden.ui.content.get_children().filter(func(n):return n is Button)[0]
	resume_button.grab_focus();await ui_shot("ui-pause-focus");resume_button.release_focus()
	garden.ui.settings_menu();await ui_shot("ui-settings")
	garden.ui.inspect_record("route");await ui_shot("ui-record")
	garden.ui.memory(0);await ui_shot("ui-letter")
	await chapter(1)
	await reference_spring()
	await shot("render-02-greenhouse-morning",Vector3(-9.2,3.3,.5),Vector3(0,7,-1))
	await shot("render-05-nursery-canopy",Vector3(6.9,2.8,5.5),Vector3(9.2,3.0,2.0))
	await shot("20-greenhouse-overview",Vector3(21,15,18),Vector3(0,6,1))
	await shot("21-greenhouse-glass",Vector3(-5,10,-9),Vector3(1,9,0))
	await shot("model-01-roof-truss",Vector3(6.8,10.2,5.3),Vector3(2,12.4,1.8))
	await shot("cg-05-greenhouse-floor",Vector3(-8,3.1,-6.8),Vector3(-3,2.2,-2.5))
	await shot("detail-03-potting-bench",Vector3(-5.0,3.2,-.7),Vector3(-7,2.6,-2.7))
	await shot("detail-04-fern-close",Vector3(-5.9,2.9,-1.4),Vector3(-6.6,2.8,-2.7))
	await shot("cg-06-terracotta",Vector3(-6.9,2.1,-1.1),Vector3(-5.8,1.65,-2.7))
	await shot("22-fuse-controls",Vector3(-1.7,5.2,8.5),Vector3(-2,4,6.1))
	await shot("23-lift-mirrors",Vector3(-5,9,3),Vector3(2,8.4,0))
	await shot("24-roof-vent",Vector3(12,12,6),Vector3(6,10,0))
	Puzzles.data.fuses=[2,0,1];Puzzles.data.mirrors=[1,3]
	for task in Puzzles.TASKS[1]:Puzzles.finish(task)
	Journey.shutters=true;Journey.lift=true;Journey.bridge=1
	garden.refresh();garden.puzzle_world.refresh()
	await frames(3);colour(1);audit()
	await shot("25-restored-greenhouse",Vector3(2,9,5),Vector3(6,8,0))
	await chapter(2)
	await reference_garden()
	await shot("30-regrowth-overview",Vector3(17,17,22),Vector3(0,5,-3))
	await shot("model-02-orangery-bracing",Vector3(10,10.8,7),Vector3(6,12,-2))
	await shot("31-planter-flora",Vector3(-3.5,8,3.5),Vector3(-5,6.8,0))
	var leaf=garden.geometry.find_children("*","MeshInstance3D",true,false).filter(func(n):return n.material_override is ShaderMaterial and n.material_override.shader.resource_path.ends_with("botanical_leaf.gdshader") and not n.material_override.get_shader_parameter("petal"))[0]
	var leaf_center=leaf.to_global(leaf.mesh.get_aabb().get_center())
	await shot("ai-03-leaf-close",leaf_center+Vector3(.18,.35,.4),leaf_center)
	await shot("32-irrigation",Vector3(7.2,7.7,3),Vector3(5,6.5,.5))
	await shot("33-seed-dome-tree",Vector3(5,11,-4),Vector3(.6,9.7,-10))
	await shot("34-wind-tower-controls",Vector3(0,10.4,-6.5),Vector3(0,9.5,-8.5))
	Puzzles.data.beds=[0,1,2];Puzzles.data.irrigation=[1,2,3];Puzzles.data.roots=[2,1];Puzzles.data.battery=true
	for task in Puzzles.TASKS[2]:Puzzles.finish(task)
	Journey.ending="eden";garden.refresh();garden.puzzle_world.refresh();colour(1)
	await shot("34b-containment",Vector3(0,10.1,-11.2),Vector3(0,9.2,-10))
	Journey.ending="regeneration";garden.refresh();colour(1);audit()
	await shot("35-restored-garden",Vector3(0,10.6,-12),Vector3(0,9.25,-10))
	garden.ui.ending_card();await ui_shot("ui-ending")
	await tutorial_shots()
	await repair_result_shots()
	await small_story_shots()
	var report={"engine":Engine.get_version_info(),"display":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"composition":"Controlled cameras and completed-state fixtures; separate puzzle_flow checks actual playthrough","captures":captures,"renderables":inventory,"lights":light_inventory,"environment":{"ssao":garden.environment.ssao_enabled,"ssil":garden.environment.ssil_enabled,"ssr":garden.environment.ssr_enabled,"volumetric_fog":garden.environment.volumetric_fog_enabled,"sun_energy":garden.get_node("CoastalSun").light_energy,"sun_rotation":str(garden.get_node("CoastalSun").rotation_degrees)},"unique_meshes":mesh_checks.size(),"failures":failures}
	report["reflections"]=reflection_inventory
	report["structural_members"]=structural_inventory
	report["environment"]["sky_shader"]=garden.environment.sky.sky_material.shader.resource_path
	report["environment"]["sky_panorama"]=garden.environment.sky.sky_material.get_shader_parameter("panorama").resource_path
	FileAccess.open(output.path_join("model-render-audit.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("MODEL_RENDER_AUDIT: ",captures.size()," frames; ",inventory.size()," renderables; failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func plant_details(h: Node3D):
	await shot("07-trees-grass-rocks",h.to_global(Vector3(-8.8,2.7,6.4)),h.to_global(Vector3(-5.6,1.9,1.5)))
	await shot("07b-grass-and-flowers",h.to_global(Vector3(8.6,1.9,-4.8)),h.to_global(Vector3(5.2,.65,-2.1)))

func tutorial_shots():
	await chapter(0);garden.ui.feedback_log.clear();garden.tutorial.suppressed=false;colour(0)
	var tutor=garden.tutorial
	garden.camera.position=garden.walker.eye_position();garden.camera.look_at(garden.nodes.landing+Vector3(0,1,0))
	tutor.poll();await ui_shot("tutorial-01-movement")
	Journey.tutorial_steps.assign(["move","look"]);tutor.poll()
	garden.camera.look_at(tutor.target.global_position);await ui_shot("tutorial-02-letter")
	Journey.memories=[0];Puzzles.remember_record("route");tutor.poll()
	garden.walker.position=garden.nodes.landing+Vector3(0,.055,0);garden.avatar.position=garden.walker.position
	garden.camera.position=garden.walker.eye_position();garden.camera.look_at(tutor.target.global_position)
	await ui_shot("tutorial-03-route")
	Puzzles.finish("water_route");Journey.bridge=1;garden.refresh();Puzzles.remember_record("pressure")
	garden.walker.position=garden.nodes.spring+Vector3(0,.055,0);garden.avatar.position=garden.walker.position
	tutor.poll();garden.camera.position=garden.walker.eye_position();garden.camera.look_at(tutor.target.global_position)
	await ui_shot("tutorial-04-pressure")
	Puzzles.finish("pressure");tutor.poll();garden.camera.look_at(tutor.target.global_position)
	await ui_shot("tutorial-05-partner")
	garden.tutorial.suppressed=true
func small_story_shots():
	get_window().content_scale_size=Vector2i.ZERO;get_window().size=Vector2i(640,480)
	await frames(5)
	for i in 3:
		garden.ui.prologue_screen(i,"title");await frames(6);await ui_shot("ui-story-small-%d"%i)

func reference_tide():
	await shot("reference-01-tidal-palazzo",Vector3(8,3.8,12),Vector3(-10,7.0,-12))
	await shot("reference-02-open-arcades",Vector3(-14,3.7,3),Vector3(-5,6.3,-8))
	await shot("reference-03-yaya-seedling",garden.companion.position+Vector3(-1.1,1.1,2.4),garden.companion.position+Vector3(.65,.65,-.2))
func reference_spring():
	await shot("reference-04-greenhouse-interior",Vector3(6.3,3.25,7.0),Vector3(0,5.0,-.3))
	await shot("reference-05-greenhouse-gallery",Vector3(8.6,8.7,5.5),Vector3(-2,8,0))
func reference_garden():
	await shot("reference-06-orangery",Vector3(11,7.2,7),Vector3(0,7.4,-5))

func save_model_scene(index: int):
	var city=garden.geometry.find_child("CinematicRuins",true,false)
	for child in city.find_children("*","Node",true,false):child.owner=city
	var packed=PackedScene.new()
	var error=packed.pack(city)
	if error!=OK:failures.append("Cannot pack reconstructed 3D model scene");return
	DirAccess.make_dir_recursive_absolute(output.path_join("models"))
	error=ResourceSaver.save(packed,output.path_join("models/chapter-%d.tscn"%index))
	if error!=OK:failures.append("Cannot save reconstructed 3D model scene")

func horizon_shots():
	await shot("render-03-mountain-ridges",Vector3(-25,17,24),Vector3(-111,22,-26))
	var harbour=garden.geometry.find_child("DistantFactory0",true,false)
	await shot("render-04-harbour-shell",harbour.to_global(Vector3(13,5,14)),harbour.to_global(Vector3(0,3,0)))

func operate_repair(task: String):
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
func repair_result_shots():
	for index in 3:
		await chapter(index)
		garden.repair_focus.set_process(false);garden.repair_focus.allow_verification=true
		for task in Puzzles.TASKS[index]:
			var view=garden.repair_focus.view_for(task)
			await shot("repair-"+task+"-before",view[0],view[1],58)
			garden.capture=false;operate_repair(task);colour(1)
			garden.repair_focus.advance(.65);garden.repair_focus.advance(1.4)
			if not garden.repair_focus.active or garden.repair_focus.task!=task:failures.append("Repair camera did not follow real success: "+task)
			await shot("repair-"+task+"-after",view[0],view[1],58)
			if task=="water_route":
				colour(float(Journey.memories.size())/12.0)
				await shot("repair-water_route-play",view[0],view[1],58)
				colour(1)
			garden.repair_focus.advance(5);garden.capture=true
		garden.repair_focus.allow_verification=false
		audit()
