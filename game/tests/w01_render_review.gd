extends Node
var garden
var captures=[]
var failures=[]
var baseline=false
func _ready():run.call_deferred()
func frames(count=4):
	for i in count:await RenderingServer.frame_post_draw
func colour(value):
	if garden.colour_tween and garden.colour_tween.is_valid():garden.colour_tween.kill()
	garden.set_recovery(value)
func shot(name_value):
	await frames()
	var image=get_viewport().get_texture().get_image()
	if image.is_empty() or image.save_png("/review/"+name_value+".png")!=OK:failures.append("Cannot save "+name_value)
	captures.append({"name":name_value,"eye":str(garden.camera.global_position),"camera":str(garden.camera.global_transform),"player":str(garden.walker.position),"fov":garden.camera.fov,"recovery":garden.recovery,"width":image.get_width(),"height":image.get_height()})
	print("W01_RENDER_FRAME ",name_value)
func run():
	if DisplayServer.get_name()=="headless":push_error("W-01 review requires a real rasterizer");get_tree().quit(1);return
	Engine.max_fps=10
	baseline="--w01-baseline" in OS.get_cmdline_user_args()
	Journey.save_path="user://isolated-w01-render.json";Journey.fresh()
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	garden.environment.volumetric_fog_temporal_reprojection_enabled=false
	garden.capture=true;garden.playing=true;garden.ui.close_panel();garden.enter_first_person()
	garden.set_process(false);garden.walker.set_physics_process(false);garden.companion.set_process(false)
	garden.tutorial.suppressed=true;garden.tutorial.poll()
	await frames(12)
	colour(1);garden.walker.yaw=-PI/2;garden.walker.pitch=-.15;garden.update_camera()
	await shot("w01-01-entry")
	# Run the approach at the actual 60 Hz physics rate; software raster speed
	# must not change the measured standing position or produce unused frames.
	RenderingServer.set_render_loop_enabled(false);Engine.max_fps=60
	await get_tree().physics_frame;await get_tree().physics_frame
	for i in 100:
		garden.walker.move_direction(Vector2(0,-1),.016)
		await get_tree().physics_frame
	garden.walker.yaw=0
	for i in 9:
		garden.walker.move_direction(Vector2(0,-1),.016)
		await get_tree().physics_frame
	RenderingServer.set_render_loop_enabled(true);Engine.max_fps=10
	if garden.walker.position.distance_to(garden.nodes.landing)>.5 or is_inf(garden.floor_at(garden.walker.position)):failures.append("Actual movement did not reach the landing")
	garden.aim_at(garden.nodes.landing+Vector3(0,.95,1.13))
	colour(0);await shot("w01-02-player-grayscale")
	colour(1.0/12.0);await shot("w01-03-player-early-colour")
	colour(1);await shot("w01-04-player-full-colour")
	if not baseline:
		var runner=load("res://scripts/puzzle_playthrough.gd").new(garden)
		for i in 3:
			var target=runner.target("puzzle","pipe:%d"%i)
			garden.aim_at(target.global_position);await get_tree().physics_frame
			if garden.pick_at(get_viewport().get_visible_rect().size/2)!=target:failures.append("Player ray cannot reach dial %d"%i)
		garden.repair_focus.allow_verification=true;garden.repair_focus.set_process(false)
		Puzzles.data.pipes=[1,3,1];garden.puzzle_world.refresh()
		var view=garden.repair_focus.view_for("water_route")
		garden.camera.position=view[0];garden.camera.look_at(view[1]);garden.camera.fov=58
		await shot("w01-05-repair-before")
		garden.capture=false;Puzzles.operate("pipe",2);colour(1)
		garden.repair_focus.advance(.65);garden.repair_focus.advance(1.4)
		await shot("w01-06-repair-after")
		garden.repair_focus.advance(5)
	var report={"version":"1.11.0" if baseline else "1.11.1","renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),"approach":"100 continuous move_and_slide steps from the entrance, then 9 steps back for the full cabinet; 60 Hz physics with raster drawing paused during transit; no guided walk or teleport", "captures":captures,"failures":failures}
	FileAccess.open("/review/w01-render-audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("W01_RENDER_AUDIT: ",captures.size()," frames; failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
