extends "res://tests/later_visibility_flow.gd"
var captures=[]
func frames(count=1):
	for i in count:await RenderingServer.frame_post_draw
func colour(value):
	if garden.colour_tween and garden.colour_tween.is_valid():garden.colour_tween.kill()
	garden.set_recovery(value)
func shot(title):
	await frames()
	var pixels=get_viewport().get_texture().get_image()
	check(not pixels.is_empty() and pixels.save_png("/review/"+title+".png")==OK,"Raster capture saved: "+title)
	captures.append({"name":title,"chapter":Journey.chapter,"player":str(garden.walker.position),"camera":str(garden.camera.global_transform),"fov":garden.camera.fov,"recovery":garden.recovery,"panel":garden.ui.panel_kind,"supported":not is_inf(garden.floor_at(garden.walker.position))})
	print("LATER_VISIBILITY_RENDER_FRAME ",title)
func record(key_value: String,node: String,prefix: String,offset=Vector3.ZERO):
	stand(node,offset)
	var board=garden.puzzle_world.record_boards[key_value]
	garden.aim_at(board.global_position+Vector3(0,1.23,0))
	await shot(prefix+"-printed")
	await use("inspect",key_value)
	check(garden.ui.panel_kind=="record","Full instructions open: "+key_value)
	await shot(prefix+"-full-text")
	garden.ui.close_panel()
func run():
	if DisplayServer.get_name()=="headless":push_error("Later visibility review requires a real rasterizer");get_tree().quit(1);return
	Journey.save_path="user://isolated-later-visibility-render.json";Journey.fresh()
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	await get_tree().physics_frame
	runner=load("res://scripts/puzzle_playthrough.gd").new(garden)
	garden.set_process(false);Engine.max_fps=10
	prepare(0);garden.environment.volumetric_fog_temporal_reprojection_enabled=false
	Puzzles.data.solved=["water_route"];garden.puzzle_world.refresh();colour(2.0/12.0)
	stand("spring");garden.aim_at(garden.nodes.spring+Vector3(0,1.05,.98))
	await frames(4);await shot("later-01-pressure-initial")
	await use("puzzle","valve:0");await use("puzzle","valve:0");await use("puzzle","valve:1")
	check(Puzzles.done("pressure"),"Visible pressure controls solve W-02")
	garden.aim_at(garden.nodes.spring+Vector3(0,1.05,.98));colour(3.0/12.0)
	await shot("later-02-pressure-correct")
	await record("pressure","spring","later-03-pressure-record")
	prepare(1);garden.environment.volumetric_fog_temporal_reprojection_enabled=false
	Journey.lift=true;Puzzles.data.solved=["power"];garden.puzzle_world.refresh();colour(5.0/12.0)
	for i in 2:
		stand("lift_high" if i==0 else "sun")
		var base=garden.nodes["lift_high" if i==0 else "sun"]
		garden.aim_at(base+Vector3(.1,1.02,1.05));await shot("later-04-mirror-%d-initial"%i)
		for turn in [1,3][i]:await use("puzzle","mirror:%d"%i)
		garden.aim_at(base+Vector3(.1,1.02,1.05));await shot("later-05-mirror-%d-correct"%i)
	check(Puzzles.done("mirrors"),"Visible directions solve the two sunlight mirrors")
	await record("power","landing","later-06-power-record")
	await record("mirrors","lift_high","later-07-mirror-record")
	prepare(2);garden.environment.volumetric_fog_temporal_reprojection_enabled=false;colour(8.0/12.0)
	stand("landing");garden.aim_at(garden.nodes.landing+Vector3(-1.1,1,0))
	await shot("later-08-seed-rack")
	for i in 3:await use("puzzle","take_plant:%d"%i)
	check(Puzzles.data.plant_bag==[0,1,2],"All visible species enter the seedling satchel")
	garden.aim_at(garden.nodes.landing+Vector3(-1.1,1,0));await shot("later-09-collected-seedlings")
	await record("beds","landing","later-10-planting-record")
	Puzzles.data.solved=["planting"];Puzzles.data.beds=[0,1,2];garden.puzzle_world.refresh();colour(10.0/12.0)
	for i in 3:
		stand(["west","east","north"][i]);var base=garden.nodes[["west","east","north"][i]]
		garden.aim_at(base+Vector3(0,1,.8));await shot("later-11-bed-%d-initial"%i)
		for turn in i+1:await use("puzzle","irrigate:%d"%i)
		garden.aim_at(base+Vector3(0,1,.8));await shot("later-12-bed-%d-correct"%i)
	check(Puzzles.done("irrigation"),"Visible habitat marks and amounts solve all three beds")
	colour(11.0/12.0);stand("summit",Vector3(0,0,.7))
	garden.aim_at(garden.nodes.summit+Vector3(1.55,1.08,0));await shot("later-13-roots-initial")
	await use("puzzle","root:0");await use("puzzle","root:0");await use("puzzle","root:1")
	check(Puzzles.data.roots==[2,1],"Visible root directions reach their required configuration")
	garden.aim_at(garden.nodes.summit+Vector3(1.55,1.08,0));await shot("later-14-roots-correct")
	await record("roots","summit","later-15-root-record",Vector3(0,0,.7))
	var report={"version":"1.12.3","renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),"approach":"Actual first-person eye height at supported normal operating positions; visible controls operated by real E input; printed notes and full instruction panels captured", "checks":checks,"captures":captures,"failures":failures}
	report.source_sha256={}
	for script in ["garden.gd","puzzle_world.gd","worksite_details.gd","garden_ui.gd"]:
		report.source_sha256["scripts/"+script]=FileAccess.get_sha256("res://scripts/"+script)
	FileAccess.open("/review/later-visibility-render-audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("LATER_VISIBILITY_RENDER_AUDIT: ",captures.size()," frames; ",checks," checks; failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
