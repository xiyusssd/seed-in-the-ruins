extends Node
var garden
var output="/review"
var captures=[]
var failures=[]
var only_chapter=-1
func _ready():run.call_deferred()
func frames(count):
	for i in count:await RenderingServer.frame_post_draw
func shot(label: String,eye: Vector3,target: Vector3):
	garden.camera.position=eye;garden.camera.look_at(target);garden.camera.fov=64
	await frames(4)
	var picture=get_viewport().get_texture().get_image()
	if picture.is_empty() or picture.save_png(output.path_join(label+".png"))!=OK:failures.append(label)
	captures.append({"name":label,"chapter":Journey.chapter,"eye":str(eye),"target":str(target),"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)})
	print("REALISM_FRAME ",label)
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-dir="):output=arg.trim_prefix("--review-dir=")
		if arg.begins_with("--review-chapter="):only_chapter=int(arg.trim_prefix("--review-chapter="))
	DirAccess.make_dir_recursive_absolute(output)
	Engine.max_fps=12
	Journey.save_path="user://isolated-realism-render.json";Journey.fresh()
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	garden.environment.volumetric_fog_temporal_reprojection_enabled=false
	for chapter in 3:
		if only_chapter>=0 and only_chapter!=chapter:continue
		Journey.fresh();Journey.chapter=chapter;garden.build_chapter()
		garden.capture=true;garden.playing=true;garden.set_process(false)
		garden.walker.set_physics_process(false);garden.companion.set_process(false)
		garden.ui.close_panel();garden.tutorial.suppressed=true
		if garden.colour_tween and garden.colour_tween.is_valid():garden.colour_tween.kill()
		garden.set_recovery(1.0)
		await frames(12)
		match chapter:
			0:
				await shot("01-pump-arcade",Vector3(-6,4.45,-1),Vector3(-3,7,-5.4))
				await shot("02-harbor",Vector3(8,3.8,12),Vector3(-10,7,-12))
				await shot("03-wet-stone",Vector3(9,2.35,5.3),Vector3(9,1.38,3))
			1:
				await shot("04-greenhouse",Vector3(-9.2,3.3,.5),Vector3(0,7,-1))
				await shot("05-stone-pier",Vector3(8.6,3.0,2.6),Vector3(6,3.5,0))
				await shot("06-glass-drain",Vector3(8.4,3.25,5.9),Vector3(11,4.1,7.4))
			2:
				await shot("07-garden",Vector3(0,7.65,4.5),Vector3(0,9,-8))
				await shot("08-bed-contact",Vector3(-7.1,7.6,2),Vector3(-5,6.2,0))
				garden.set_recovery(0.0)
				await shot("09-monochrome",Vector3(0,7.65,4.5),Vector3(0,9,-8))
	FileAccess.open(output.path_join("realism-render-audit.json"),FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"captures":captures,"failures":failures},"\t"))
	print("REALISM_RENDER: ",captures.size()," frames; failures=",failures)
	garden.queue_free();await get_tree().process_frame
	await get_tree().create_timer(.15).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
