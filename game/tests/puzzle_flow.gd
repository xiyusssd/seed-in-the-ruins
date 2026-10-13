extends Node
func _ready(): run.call_deferred()
func run():
	Journey.save_path="user://puzzle-suite-v4.json"
	var garden=load("res://garden.tscn").instantiate()
	add_child(garden)
	await get_tree().physics_frame
	var runner=load("res://scripts/puzzle_playthrough.gd").new(garden)
	var errors: Array = await runner.run(false)
	# Persistence and reversible inventory, without changing the successful walkthrough.
	var snap=Puzzles.snapshot()
	Journey.save_journey();Puzzles.reset_all();Journey.load_journey()
	runner.check(Puzzles.data.solved==snap.solved and Puzzles.data.battery,"v4 save restores solved tasks and battery")
	Puzzles.reset_chapter(1)
	runner.check(not Puzzles.done("power") and Journey.memories.size()==12,"Reset preserves earned colour while restoring chapter mechanisms")
	Puzzles.operate("take_fuse",0);Puzzles.operate("slot",0)
	Puzzles.operate("take_fuse",1);Puzzles.operate("slot",0)
	runner.check(Puzzles.data.fuses[0]==1 and Puzzles.data.fuse_hand==0,"Wrong module can be swapped back into hand")
	Puzzles.operate("slot",0)
	runner.check(Puzzles.data.fuses[0]==0 and Puzzles.data.fuse_hand==1,"Module swap is reversible without losing an object")
	Journey.save_journey()
	Puzzles.reset_all();Journey.load_journey()
	runner.check(Puzzles.data.fuses==[0,-1,-1] and Puzzles.data.fuse_hand==1,"Mid-puzzle save restores installed and held modules")
	Puzzles.restore({"fuses":[0,0,7],"fuse_hand":0})
	runner.check(Puzzles.data.fuses==[0,-1,-1] and Puzzles.data.fuse_hand==-1,"Corrupt inventory is normalized without duplicates")
	Puzzles.reset_all()
	var first=Puzzles.hint(0);var second=Puzzles.hint(0,true);var third=Puzzles.hint(0,true)
	runner.check(not "1、3、2" in first and "1、3、2" in third and first!=second,"Three hint tiers reveal the solution only when requested")
	garden.companion.command("wait")
	var pos=garden.companion.position
	await get_tree().create_timer(.2).timeout
	runner.check(garden.companion.position==pos,"Companion wait command keeps a stable position")
	garden.companion.command("follow")
	runner.check(Puzzles.data.robot_mode=="follow" and Puzzles.data.robot_task=="","Recalling companion clears the cooperation task")
	garden.playing=true
	garden.ui.pause_menu()
	await get_tree().process_frame;await get_tree().process_frame
	runner.check(garden.soundscape.suspended and (DisplayServer.get_name()=="headless" or garden.soundscape.music_players.all(func(player):return player.stream_paused)),"Menu pauses music without duplicating streams")
	garden.ui.close_panel();await get_tree().process_frame;await get_tree().process_frame
	runner.check(garden.soundscape.music_players.all(func(player):return not player.stream_paused),"Closing menu resumes existing chapter music")
	runner.check(AudioServer.get_bus_index("Music")>=0 and AudioServer.get_bus_index("Effects")>=0 and AudioServer.get_bus_index("Ambience")>=0,"Music, effects and ambience use separate volume buses")
	print("PUZZLE_TESTS: ",runner.checks," checks; failures=",runner.failures)
	garden.queue_free();await get_tree().process_frame
	get_tree().quit(0 if runner.failures.is_empty() else 1)
