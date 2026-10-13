extends "res://tests/render_review.gd"
func save_model_scene(_index: int):pass
func audit():pass
func run():
	Engine.max_fps=10;Journey.save_path="user://isolated-repair-camera-review.json";Journey.fresh()
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	garden.environment.volumetric_fog_temporal_reprojection_enabled=false
	for index in 3:
		await chapter(index)
		for task in Puzzles.TASKS[index]:operate_repair(task)
		garden.refresh();garden.puzzle_world.refresh();colour(1)
		for task in (["pump"] if index==0 else ["mirrors"] if index==1 else ["planting","irrigation","life"]):
			var view=garden.repair_focus.view_for(task)
			await shot("repair-"+task+"-after",view[0],view[1],58)
		if index==1:await shot("render-05-nursery-canopy",Vector3(6.9,2.8,5.5),Vector3(9.2,3.0,2.0))
	FileAccess.open(output.path_join("repair-camera-audit.json"),FileAccess.WRITE).store_string(JSON.stringify({"captures":captures,"failures":failures},"\t"))
	print("REPAIR_CAMERA: ",captures.size()," frames; failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
