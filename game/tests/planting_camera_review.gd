extends "res://tests/render_review.gd"
func run():
	Engine.max_fps=10;Journey.save_path="user://isolated-planting-camera-review.json";Journey.fresh();Journey.chapter=2
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	garden.capture=true;garden.playing=true;garden.set_process(false);garden.ui.close_panel();garden.tutorial.suppressed=true
	garden.walker.set_physics_process(false);garden.companion.set_process(false)
	garden.environment.volumetric_fog_temporal_reprojection_enabled=false
	for task in Puzzles.TASKS[2]:operate_repair(task)
	garden.refresh();garden.puzzle_world.refresh();colour(1);await frames(12)
	var view=garden.repair_focus.view_for("planting")
	await shot("repair-planting-after",view[0],view[1],58)
	print("PLANTING_CAMERA: 1 frame; failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
