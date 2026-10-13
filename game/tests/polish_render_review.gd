extends Node
var garden
var output="/review"
var captures=[]
var failures=[]
var version="1.14.0"
func _ready():run.call_deferred()
func frames(count=2):
	for i in count:await RenderingServer.frame_post_draw
func shot(label: String,eye: Vector3,target: Vector3,player_view=false):
	garden.hovered=null;garden.camera.position=eye;garden.camera.look_at(target);garden.camera.fov=76 if player_view else 64
	if player_view:garden.walker.position=eye-Vector3.UP*1.65;garden.avatar.position=garden.walker.position
	await get_tree().physics_frame
	if player_view:garden.hovered=garden.pick_at(get_viewport().get_visible_rect().size/2)
	garden.ui._process(0)
	garden.ui.hud.visible=player_view
	await frames()
	var picture=get_viewport().get_texture().get_image()
	if picture.is_empty() or picture.save_png(output.path_join(label+".png"))!=OK:failures.append(label)
	captures.append({"name":label,"chapter":Journey.chapter,"camera":str(garden.camera.global_transform),"fov":garden.camera.fov,"player_view":player_view,"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)})
	print("POLISH_FRAME ",label)
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-dir="):output=arg.trim_prefix("--review-dir=")
		if arg.begins_with("--review-version="):version=arg.trim_prefix("--review-version=")
	DirAccess.make_dir_recursive_absolute(output)
	if DisplayServer.get_name()=="headless":push_error("Rasterizer required");get_tree().quit(1);return
	Engine.max_fps=12
	Journey.save_path="user://isolated-polish-render.json";Journey.fresh()
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	garden.environment.volumetric_fog_temporal_reprojection_enabled=false
	for chapter in 3:
		Journey.fresh();Journey.chapter=chapter;Journey.lift=true;garden.build_chapter()
		garden.capture=true;garden.playing=true;garden.ui.close_panel();garden.enter_first_person()
		garden.set_process(false);garden.walker.set_physics_process(false);garden.companion.set_process(false)
		garden.ui.set_process(false)
		garden.tutorial.suppressed=true;garden.tutorial.poll()
		if garden.colour_tween and garden.colour_tween.is_valid():garden.colour_tween.kill()
		garden.set_recovery(1)
		await frames(3)
		match chapter:
			0:
				await shot("01-pump-arcade",Vector3(-6,4.45,-1),Vector3(-3,7,-5.4))
				await shot("02-entry",garden.nodes.arrival+Vector3(0,1.705,0),garden.nodes.landing+Vector3(0,.9,0),true)
				await shot("03-bridge-structure",Vector3(-5.6,1.7,3.5),Vector3(-3,2.4,1))
				garden.walker.position=garden.nodes.spring+Vector3(0,.055,0)
				await shot("04-pressure",garden.nodes.spring+Vector3(0,1.705,1.1),garden.nodes.spring+Vector3(0,.9,-1.3),true)
				for body in garden.pickables:
					if body.get_meta("id","")=="valve:0":await shot("04-control-focus",garden.nodes.spring+Vector3(0,1.705,0),body.global_position,true);break
			1:
				await shot("05-greenhouse",Vector3(-9.2,3.3,.5),Vector3(0,7,-1))
				await shot("06-lift-shelf",Vector3(-4.7,5.25,1),Vector3(-2,7.1,-.9))
				await shot("07-upper-bridge",garden.nodes.lift_high+Vector3(0,1.705,.2),garden.nodes.sun+Vector3(0,1,0),true)
				garden.set_recovery(0)
				await shot("08-monochrome",Vector3(-9.2,3.3,.5),Vector3(0,7,-1))
			2:
				await shot("09-garden",Vector3(0,7.65,4.5),Vector3(0,9,-8))
				await shot("10-seed-entry",garden.nodes.entry_step+Vector3(0,1.705,0),garden.nodes.center+Vector3(0,1,0),true)
				await shot("11-tower",garden.nodes.summit_step+Vector3(0,1.705,0),garden.nodes.summit+Vector3(0,1,0),true)
				garden.ui.settings_menu();await frames(3)
				garden.ui._process(0);await frames(1)
				var image=get_viewport().get_texture().get_image()
				if image.save_png(output.path_join("12-settings.png"))!=OK:failures.append("settings")
				var scroll=garden.ui.content.get_parent()
				if scroll.get_v_scroll_bar().max_value>scroll.get_v_scroll_bar().page+1:failures.append("Settings require scrolling")
				captures.append({"name":"12-settings","chapter":chapter,"menu":"settings"})
	FileAccess.open(output.path_join("polish-render-audit.json"),FileAccess.WRITE).store_string(JSON.stringify({"version":version,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"display":DisplayServer.get_name(),"captures":captures,"failures":failures},"\t"))
	print("POLISH_RENDER_REVIEW: ",captures.size()," frames; failures=",failures)
	garden.queue_free();await get_tree().process_frame;await get_tree().create_timer(.15).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
