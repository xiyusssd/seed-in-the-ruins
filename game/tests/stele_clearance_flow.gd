extends Node
var garden
var checks=0
var failures=[]
var stones=[]
var output=""
func check(value: bool,message: String):
	checks+=1
	if not value:failures.append(message);push_error(message)
func _ready():run.call_deferred()
func separation(outline: PackedVector2Array,a: Vector2,b: Vector2) -> float:
	if Geometry2D.is_point_in_polygon(a,outline) or Geometry2D.is_point_in_polygon(b,outline):return 0.0
	var distance=INF
	for i in outline.size():
		var c=outline[i];var d=outline[(i+1)%outline.size()]
		if Geometry2D.segment_intersects_segment(a,b,c,d)!=null:return 0.0
		for point in [a,b]:distance=minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,c,d)))
		for point in [c,d]:distance=minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,a,b)))
	return distance
func footprint(board: Node3D) -> Dictionary:
	var points=PackedVector2Array();var height=0.0
	for mesh in board.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var world=mesh.to_global(vertex)
				points.append(Vector2(world.x,world.z));height=maxf(height,world.y-board.global_position.y)
	return {"outline":Geometry2D.convex_hull(points),"height":height}
func shot(label: String,eye: Vector3,target: Vector3):
	if output.is_empty():return
	garden.camera.position=eye;garden.camera.look_at(target)
	for i in 4:await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"Save real player view "+label)
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-dir="):output=arg.trim_prefix("--review-dir=")
	if not output.is_empty():DirAccess.make_dir_recursive_absolute(output)
	Journey.save_path="user://isolated-stele-clearance.json";Journey.fresh()
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	await get_tree().physics_frame
	for chapter in 3:
		Journey.fresh();Journey.chapter=chapter;Journey.lift=true;garden.build_chapter()
		garden.capture=true;garden.playing=true;garden.ui.close_panel();garden.enter_first_person()
		garden.set_process(false);garden.walker.set_physics_process(false);garden.companion.set_process(false)
		garden.tutorial.suppressed=true;garden.tutorial.poll()
		if garden.colour_tween and garden.colour_tween.is_valid():garden.colour_tween.kill()
		garden.set_recovery(1)
		for key in garden.puzzle_world.record_boards:
			var board=garden.puzzle_world.record_boards[key]
			var bounds=footprint(board);var clearance=INF
			# Reserve the whole one-metre walking strip plus the player's 22 cm
			# radius along every connection, including both bridge orientations.
			for edge in garden.edges:
				var a=garden.nodes[edge[0]];var b=garden.nodes[edge[1]]
				if board.position.y<minf(a.y,b.y)-.5 or board.position.y>maxf(a.y,b.y)+.5:continue
				if Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))<.1:continue
				clearance=minf(clearance,separation(bounds.outline,Vector2(a.x,a.z),Vector2(b.x,b.z)))
			check(bounds.height<=1.35,"Roadside stone stays below eye height: "+key)
			check(clearance>=.72,"Stone and debris leave the complete player corridor clear: "+key)
			stones.append({"key":key,"height_metres":bounds.height,"distance_from_path_metres":clearance})
			print("STELE_SPACE ",key," height=",bounds.height," clearance=",clearance)
		match chapter:
			0:
				await shot("01-entry-road",garden.nodes.arrival+Vector3(0,1.705,0),garden.nodes.landing+Vector3(0,.9,0))
				await shot("02-pressure-stairs",garden.nodes.spring+Vector3(0,1.705,.40),garden.nodes.altar+Vector3(0,.8,0))
			1:
				await shot("03-power-road",garden.nodes.landing+Vector3(0,1.705,.50),garden.nodes.lift_low+Vector3(0,1,0))
				await shot("04-upper-bridge",garden.nodes.lift_high+Vector3(0,1.705,.20),garden.nodes.sun+Vector3(0,1,0))
			2:
				await shot("05-seed-entry",garden.nodes.entry_step+Vector3(0,1.705,0),garden.nodes.center+Vector3(0,1,0))
				await shot("06-tower-arrival",garden.nodes.summit_step+Vector3(0,1.705,0),garden.nodes.summit+Vector3(0,1,0))
	if not output.is_empty():
		FileAccess.open(output.path_join("stele-clearance-audit.json"),FileAccess.WRITE).store_string(JSON.stringify({"version":"1.13.1","stones":stones,"renderer":RenderingServer.get_current_rendering_method(),"checks":checks,"failures":failures},"\t"))
	print("STELE_CLEARANCE_FLOW: ",checks," checks; failures=",failures)
	garden.queue_free();await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(.15).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
