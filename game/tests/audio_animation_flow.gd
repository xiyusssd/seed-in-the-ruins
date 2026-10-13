extends Node
var checks=0
var failures=[]
func check(value: bool,message: String):
	checks+=1
	if not value:failures.append(message);push_error(message)
func settle():
	await get_tree().process_frame
	await get_tree().process_frame
func _ready():run.call_deferred()
func run():
	Journey.save_path="user://audio-animation-suite-v4.json";Journey.fresh()
	var garden=load("res://garden.tscn").instantiate();add_child(garden)
	await settle()
	var sound=garden.soundscape
	if DisplayServer.get_name()!="headless":sound.enable_review_audio()
	check(sound.presentation_music.bus=="Music" and sound.presentation_music.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"Presentation has its own looping Music stream")
	check(is_equal_approx(sound.presentation_music.stream.get_length(),51.2),"Presentation carries the complete 16-bar score")
	check(sound.presentation_air.size()==3 and sound.presentation_air.all(func(n):return n.bus=="Ambience"),"Three scene beds use the separate Ambience bus")
	var music_id=sound.presentation_music.get_instance_id()
	garden.ui.prologue_screen(0,"title");sound._process(1.0)
	check(sound.presentation_kind=="prologue" and sound.presentation_gain>.8 and not sound.presentation_music.stream_paused,"Story opens an audible independent music layer")
	check(sound.suspended and (not sound.playback_enabled or sound.music_players.all(func(n):return n.stream_paused)),"Story pauses hidden gameplay audio while its score continues")
	check(sound.page_gains[0]>.8 and sound.page_gains[1]==0,"First scene selects the tide ambience")
	garden.ui.prologue_screen(1,"title");sound._process(.2)
	check(sound.presentation_music.get_instance_id()==music_id,"Turning a page keeps the same musical phrase")
	check(sound.page_gains[0]>0 and sound.page_gains[1]>0,"Scene ambience crossfades rather than cutting off")
	for i in 15:sound._process(.2)
	check(sound.page_gains[1]>.99 and sound.page_gains[0]<.01,"Ambience crossfade reaches the selected page")
	var film=garden.ui.story_art
	film._process(.5);var before=film.elapsed
	film.motion_paused=true;film._process(.5)
	check(film.elapsed==before and film.transition_elapsed>=1.0,"Motion pause freezes all atmosphere while transitions can finish")
	check(film.film.get_shader_parameter("page")==1,"Shader receives the character scene for lens animation")
	film.motion_paused=false;film._process(.5)
	check(film.elapsed>before,"Motion resumes from the held clock")
	var next=garden.ui.overlay.find_child("StoryNext",true,false);next.pressed.emit()
	check(sound.ui_events.get("ui_page",0)>0 and sound.story_page==2,"Next page triggers its foley and selects the next environment")
	garden.ui.finish_prologue();sound._process(.2)
	check(garden.ui.panel_kind=="title" and sound.presentation_gain>.8,"Title retains music after the story")
	garden.playing=true;garden.ui.close_panel();sound._process(.3)
	check(sound.presentation_gain>0 and sound.world_gain>0,"Entering the world crossfades score layers")
	for i in 20:sound._process(.2)
	check(sound.presentation_gain<.001 and (not sound.playback_enabled or sound.presentation_music.stream_paused),"Presentation settles to silence while exploring")
	check(sound.music_players.all(func(n):return not n.stream_paused),"Gameplay resumes the existing chapter players")
	for chapter in 3:
		Journey.chapter=chapter;Journey.fps_valid=false;garden.build_chapter()
		check(sound.music_players.size()==2 and sound.music_players.all(func(n):return n.bus=="Music" and is_equal_approx(n.stream.get_length(),51.2)),"Chapter %d has matching long base and warm layers"%chapter)
		check(sound.music_players.all(func(n):return n.stream.loop_end==roundi(n.stream.get_length()*n.stream.mix_rate)),"Chapter %d loops at its true sample boundary"%chapter)
	var volumes=[Settings.music,Settings.effects,Settings.ambience]
	Settings.music=0;Settings.effects=0;Settings.ambience=0;Settings.apply_audio()
	for bus in ["Music","Effects","Ambience"]:check(AudioServer.is_bus_mute(AudioServer.get_bus_index(bus)),"Zero volume independently mutes "+bus)
	Settings.music=volumes[0];Settings.effects=volumes[1];Settings.ambience=volumes[2];Settings.apply_audio()
	Journey.chapter=0;Journey.fps_valid=false;garden.build_chapter();garden.playing=true;garden.ui.close_panel()
	var robot=garden.companion
	robot.command("wait")
	check(robot.track_links.size()==52,"Robot has two complete articulated tread belts")
	var original=robot.track_links[0].position
	robot.belt_distance=.08;robot.update_tracks()
	check(robot.track_links[0].position.distance_to(original)>.05,"Travel distance rolls links around the belt")
	robot.belt_distance=2*(.44+PI*.10);robot.update_tracks()
	check(robot.track_links[0].position.distance_to(original)<.001,"Belt wrap is continuous")
	var distance=robot.belt_distance;robot._process(.1)
	check(is_equal_approx(robot.belt_distance,distance),"Waiting does not spin stationary tracks")
	robot.arrived=true;Puzzles.data.robot_mode="assist";Puzzles.data.robot_task="pump"
	var arm_before=robot.arm.rotation.x;robot._process(.05)
	check(robot.arm.rotation.x>-.7 and robot.arm.rotation.x<arm_before,"Arriving eases the arm into operating position")
	var clock=robot.clock;var arm=robot.arm.rotation
	garden.ui.pause_menu();robot._process(.5)
	check(robot.clock==clock and robot.arm.rotation==arm,"Pause holds the complete companion animation")
	print("AUDIO_ANIMATION_TESTS: ",checks," checks; failures=",failures)
	garden.queue_free();await get_tree().process_frame
	await get_tree().create_timer(.15).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
