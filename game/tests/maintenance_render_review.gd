extends Node
var garden
var captures=[]
var failures=[]
var output="/review"
func _ready():run.call_deferred()
func frames(count=2):
	for i in count:await RenderingServer.frame_post_draw
func colour(value):
	if garden.colour_tween and garden.colour_tween.is_valid():garden.colour_tween.kill()
	garden.set_recovery(value)
func shot(name_value,extra={}):
	await frames()
	var image=get_viewport().get_texture().get_image()
	if image.is_empty() or image.save_png(output.path_join(name_value+".png"))!=OK:failures.append("Cannot save "+name_value)
	var entry={"name":name_value,"eye":str(garden.camera.global_position),"camera":str(garden.camera.global_transform),"player":str(garden.walker.position),"fov":garden.camera.fov,"recovery":garden.recovery,"width":image.get_width(),"height":image.get_height()}
	entry.merge(extra);captures.append(entry)
	print("MAINTENANCE_RENDER_FRAME ",name_value)
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-dir="):output=arg.trim_prefix("--review-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	if DisplayServer.get_name()=="headless":push_error("Record review requires a real rasterizer");get_tree().quit(1);return
	Engine.max_fps=10
	Journey.save_path="user://isolated-maintenance-render.json";Journey.fresh()
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	garden.environment.volumetric_fog_temporal_reprojection_enabled=false
	for chapter in 3:
		if chapter>0:Journey.chapter=chapter;Journey.lift=true;garden.build_chapter()
		garden.capture=true;garden.playing=true;garden.ui.close_panel();garden.enter_first_person()
		garden.set_process(false);garden.walker.set_physics_process(false);garden.companion.set_process(false)
		garden.tutorial.suppressed=true;garden.tutorial.poll()
		await frames(4)
		for key in garden.puzzle_world.record_boards:
			var board=garden.puzzle_world.record_boards[key]
			garden.walker.position=board.get_meta("reading_position");garden.avatar.position=garden.walker.position
			garden.aim_at(board.get_meta("reading_target"));await get_tree().physics_frame
			var hit=garden.pick_at(get_viewport().get_visible_rect().size/2)
			if not hit or hit.get_meta("id","")!=key or not garden.valid_nearby_target(hit):failures.append("Actual interaction ray misses "+key)
			if is_inf(garden.floor_at(garden.walker.position)):failures.append("Unsupported reading position "+key)
			var body: Label3D=board.get_node("Body")
			var center=board.to_global(body.position+Vector3(.45,0,0))
			var projected=garden.camera.unproject_position(center).distance_to(garden.camera.unproject_position(center+board.global_basis.y*body.font_size*body.pixel_size))
			# Compact waist-high stones carry close-up etchings; E still opens the
			# original full-size record. Measure the scaled glyphs in world space.
			if projected<12:failures.append("Stone instructions below 12 pixels at actual standing position: "+key)
			colour(1)
			await shot(key+"-world",{"key":key,"body":body.text,"body_projected_character_height":projected,"ray_reachable":true,"supported_walkway":true})
			if key=="route":
				colour(0);await shot("route-world-grayscale");colour(1)
			var event=InputEventKey.new();event.physical_keycode=KEY_E;event.pressed=true;garden._unhandled_input(event)
			await frames()
			if garden.ui.panel_kind!="record" or key not in Puzzles.data.records:failures.append("Real E input failed to open "+key)
			var copy=[]
			for child in garden.ui.content.get_children():
				if child is Label:copy.append(child.text)
				if child is Button and not get_viewport().get_visible_rect().encloses(child.get_global_rect()):failures.append("Return button is clipped in "+key)
			await shot(key+"-document",{"key":key,"printed_ui":copy,"archived":key in Puzzles.data.records})
			garden.ui.close_panel()
	var report={"version":"1.13.1","renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),"captures":captures,"failures":failures}
	FileAccess.open(output.path_join("maintenance-render-audit.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("MAINTENANCE_RENDER_AUDIT: ",captures.size()," frames; failures=",failures)
	garden.queue_free();await get_tree().process_frame
	await get_tree().create_timer(.15).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
