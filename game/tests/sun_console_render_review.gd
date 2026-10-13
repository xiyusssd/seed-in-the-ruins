extends Node
var garden
var captures=[]
var failures=[]
var baseline=false
func _ready():run.call_deferred()
func frames(count=2):
	for i in count:await RenderingServer.frame_post_draw
func colour(value):
	if garden.colour_tween and garden.colour_tween.is_valid():garden.colour_tween.kill()
	garden.set_recovery(value)
func shot(title):
	await frames()
	var image=get_viewport().get_texture().get_image()
	if image.is_empty() or image.save_png("/review/"+title+".png")!=OK:failures.append("Cannot save "+title)
	captures.append({"name":title,"camera":str(garden.camera.global_transform),"player":str(garden.walker.position),"fov":garden.camera.fov,"recovery":garden.recovery})
	print("SUN_CONSOLE_RENDER_FRAME ",title)
func key(code):
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true
	garden._unhandled_input(event)
func run():
	if DisplayServer.get_name()=="headless":push_error("Sun console review requires a real rasterizer");get_tree().quit(1);return
	Journey.save_path="user://isolated-sun-console-render.json";Journey.fresh();Journey.chapter=1
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	garden.capture=true;garden.playing=true;garden.ui.close_panel();garden.enter_first_person()
	garden.set_process(false);garden.walker.set_physics_process(false);garden.companion.set_process(false)
	garden.environment.volumetric_fog_temporal_reprojection_enabled=false
	baseline=garden.puzzle_world.get_node_or_null("S01InwardFacing")==null
	Engine.max_fps=10;await frames(4)
	colour(4.0/12.0)
	garden.aim_at(garden.nodes.arrival+Vector3(0,1,1.12))
	await shot("sun-01-module-rack")
	RenderingServer.set_render_loop_enabled(false);Engine.max_fps=60
	await get_tree().physics_frame;await get_tree().physics_frame
	garden.walker.yaw=-PI/2
	for i in 125:
		garden.walker.move_direction(Vector2(0,-1),.016)
		await get_tree().physics_frame
	if garden.walker.position.distance_to(garden.nodes.landing)>.15:failures.append("Continuous movement failed to reach the landing")
	garden.walker.yaw=0
	for i in 18:
		garden.walker.move_direction(Vector2(0,-1),.016)
		await get_tree().physics_frame
	if is_inf(garden.floor_at(garden.walker.position)):failures.append("Board viewing position is unsupported")
	RenderingServer.set_render_loop_enabled(true);Engine.max_fps=10
	garden.aim_at(garden.nodes.landing+Vector3(0,1.05,1.2))
	colour(0);await shot("sun-02-board-grayscale")
	colour(4.0/12.0);await shot("sun-03-board-chapter-colour")
	colour(1);await shot("sun-04-board-full-colour")
	if not baseline:
		var runner=load("res://scripts/puzzle_playthrough.gd").new(garden)
		for i in 3:
			var body=runner.target("puzzle","slot:%d"%i)
			garden.aim_at(body.global_position);await get_tree().physics_frame
			if garden.pick_at(get_viewport().get_visible_rect().size/2)!=body:failures.append("Operating-position ray cannot reach slot %d"%i)
		# Observe actual E/F updates at the same camera and eye height.
		Puzzles.data.fuse_hand=0
		garden.aim_at(runner.target("puzzle","slot:0").global_position);await get_tree().physics_frame;key(KEY_E)
		if Puzzles.data.fuses[0]!=0:failures.append("Real E failed to install a wrong module")
		garden.aim_at(garden.nodes.landing+Vector3(0,1.05,1.2))
		colour(4.0/12.0);await shot("sun-05-board-wrong-module")
		garden.aim_at(runner.target("puzzle","slot:0").global_position);await get_tree().physics_frame;key(KEY_F)
		if Puzzles.data.fuses[0]!=-1 or Puzzles.data.fuse_hand!=0:failures.append("Real F failed to retrieve the wrong module")
		for i in 3:
			Puzzles.data.fuse_hand=[2,0,1][i]
			garden.aim_at(runner.target("puzzle","slot:%d"%i).global_position);await get_tree().physics_frame;key(KEY_E)
		if not Puzzles.done("power"):failures.append("Real E interactions failed to power S-01")
		garden.aim_at(garden.nodes.landing+Vector3(0,1.05,1.2));colour(4.0/12.0)
		await shot("sun-06-board-powered")
	var report={"version":"1.12.0" if baseline else "1.12.2","renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),"approach":"125 continuous entrance steps and 18 steps toward the platform interior; actual player eye height; no teleport or guided walk", "captures":captures,"failures":failures}
	FileAccess.open("/review/sun-console-render-audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SUN_CONSOLE_RENDER_AUDIT: ",captures.size()," frames; failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
