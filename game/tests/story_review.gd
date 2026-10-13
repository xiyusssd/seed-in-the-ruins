extends "res://tests/render_review.gd"
var layouts=[]
func record_layout(name):
	var ui=garden.ui
	var card=ui.menu_card.get_global_rect()
	var buttons={}
	for node_name in ["StoryPrevious","StoryNext","StorySkip"]:
		var node=ui.overlay.find_child(node_name,true,false)
		var bounds=node.get_global_rect()
		buttons[node_name]={"x":bounds.position.x,"y":bounds.position.y,"width":bounds.size.x,"height":bounds.size.y,"disabled":node.disabled}
		if not card.encloses(bounds):failures.append(name+": navigation outside card: "+node_name)
	var scroll:ScrollContainer=ui.content.get_parent()
	if get_window().size==Vector2i(1280,800) and scroll.get_v_scroll_bar().max_value>scroll.get_v_scroll_bar().page+1:failures.append(name+": normal page needs scrolling")
	layouts.append({"name":name,"card":str(card),"buttons":buttons,"scroll_max":scroll.get_v_scroll_bar().max_value,"scroll_page":scroll.get_v_scroll_bar().page})
func page_shot(page,name):
	garden.ui.prologue_screen(page,"title")
	garden.ui.story_art.freeze_at(2.0)
	await frames(6)
	record_layout(name)
	await ui_shot(name)
func run():
	if DisplayServer.get_name()=="headless":
		push_error("Story review requires a real rasterizer");get_tree().quit(1);return
	Engine.max_fps=10
	Journey.save_path="user://isolated-story-review.json";Journey.fresh()
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	garden.environment.volumetric_fog_temporal_reprojection_enabled=false
	await chapter(0)
	var robot=garden.companion
	var eye=robot.position+Vector3(1.3,.95,1.5)
	var target=robot.position+Vector3(0,.5,0)
	await shot("robot-animation-idle",eye,target)
	robot.command("wait")
	robot.trail.clear();robot.trail.append(robot.position+Vector3(0,0,.35))
	robot._process(.12)
	await shot("robot-animation-rolling",eye,target)
	if robot.belt_distance<=0 or robot.track_links.size()!=52:failures.append("Robot belts did not animate")
	colour(0)
	garden.camera.position=Vector3(-7,4.4,5);garden.camera.look_at(Vector3(-1,4,-3))
	for page in 3:await page_shot(page,"story-desktop-%d"%page)
	for seconds in [2.0,12.0,30.0]:
		garden.ui.story_art.freeze_at(seconds)
		await frames(2)
		await ui_shot("story-motion-%02d"%seconds)
	garden.ui.prologue_screen(0,"title")
	for seconds in [0.0,0.625,1.25]:
		garden.ui.story_art.freeze_at(seconds)
		await frames(6)
		await ui_shot("story-dissolve-%03d"%roundi(seconds*100))
	garden.ui.story_art.freeze_at(2.0)
	garden.ui.overlay.find_child("StoryNext",true,false).grab_focus()
	await ui_shot("story-next-focus")
	# Test real small layout coordinates, independent of desktop stretch scaling.
	get_window().content_scale_size=Vector2i.ZERO
	get_window().size=Vector2i(640,480)
	await frames(6)
	for page in 3:await page_shot(page,"story-small-%d"%page)
	var scroll:ScrollContainer=garden.ui.content.get_parent()
	scroll.scroll_vertical=400
	await frames(4);record_layout("story-small-scrolled")
	await ui_shot("story-small-scrolled")
	var report={"engine":Engine.get_version_info(),"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"captures":captures,"robot_belt_distance":robot.belt_distance,"robot_links":robot.track_links.size(),"layouts":layouts,"failures":failures}
	FileAccess.open(output.path_join("story-render-audit.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("STORY_RENDER_AUDIT: ",captures.size()," frames; failures=",failures)
	garden.queue_free();await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
