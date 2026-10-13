extends Node
var garden
var sound
var capture: AudioEffectCapture
var output="/review"
var samples=PackedVector2Array()
var segments=[]
var checks=0
var failures=[]
func _ready():run.call_deferred()
func check(value: bool,message: String):
	checks+=1
	if not value:failures.append(message);push_error(message)
func record(label: String,seconds: float,expect=true,foley_position=null):
	await get_tree().create_timer(.25).timeout
	capture.clear_buffer()
	if foley_position!=null:
		for take in 4:
			sound.footstep(foley_position)
			await get_tree().create_timer(seconds/4).timeout
	else:await get_tree().create_timer(seconds).timeout
	var buffer=capture.get_buffer(capture.get_frames_available())
	var energy=Vector2.ZERO;var peak=0.0
	for frame in buffer:
		energy+=frame*frame;peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
	var rms=sqrt((energy.x+energy.y)/maxi(1,buffer.size()*2))
	check(not buffer.is_empty() and peak<.98,label+": mix exists without clipping")
	check(rms>.0001 if expect else peak<.00001,label+": audible / muted as intended")
	var row={"name":label,"seconds":buffer.size()/AudioServer.get_mix_rate(),"peak":peak,"rms":rms,"left_energy":energy.x,"right_energy":energy.y}
	segments.append(row);samples.append_array(buffer);return row
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-dir="):output=arg.trim_prefix("--review-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	Journey.save_path="user://isolated-realism-audio.json";Journey.fresh()
	Settings.music=0;Settings.ambience=.8;Settings.effects=.8;Settings.apply_audio()
	capture=AudioEffectCapture.new();capture.buffer_length=8
	var capture_index=AudioServer.get_bus_effect_count(0);AudioServer.add_bus_effect(0,capture)
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	garden.capture=true;garden.set_process(false);sound=garden.soundscape
	sound.enable_review_audio()
	for chapter in 3:
		Journey.fresh();Journey.chapter=chapter;garden.build_chapter();garden.ui.close_panel();garden.playing=true
		garden.walker.set_physics_process(false);garden.companion.set_process(false)
		garden.camera.position=garden.nodes.arrival+Vector3(0,1.65,0)
		garden.camera.look_at(garden.camera.position+Vector3(0,0,-1))
		await get_tree().create_timer(.4).timeout
		if chapter==0:
			var pump_layer=sound.ambience_layers.filter(func(v):return v.task=="pump")[0]
			check(pump_layer.player.volume_db<-65,"Unrepaired pump stays silent")
			Puzzles.finish("water_route");Puzzles.finish("pump")
		check(sound.surface_at(garden.nodes.arrival)=="stone","Arrival uses stone footsteps in chapter %d"%chapter)
		if chapter==1:
			check(sound.surface_at(garden.elevator.global_position)=="metal","Lift footsteps match its steel deck")
			check(sound.shelter_at(Vector3(0,8,2))>.99 and sound.shelter_at(Vector3(-15,8,2))==0,"Indoor acoustics follow the glasshouse bounds")
			await get_tree().physics_frame
			check(sound.is_occluded(Vector3(9,3.5,0),Vector3(3,3.5,0)),"Actual solid pier occludes the ray")
			check(not sound.is_occluded(Vector3(-7,8,1),Vector3(-6,8,1)),"Clear line of sight stays unfiltered")
		await record("chapter-%d-environment"%chapter,2.1)
		var step_position=garden.nodes.lift_low if chapter==1 else garden.nodes.arrival
		garden.camera.position=step_position+Vector3(0,1.65,0)
		await record("chapter-%d-footsteps"%chapter,1.8,true,step_position)
	# Measure the engine's left/right mix using one original mono source.
	sound.set_process(false)
	for source in sound.sources+sound.music_players:source.stop()
	sound.presentation_music.stop()
	for player in sound.presentation_air:player.stop()
	await get_tree().create_timer(.7).timeout
	sound.room_foley.wet=0.0
	sound.room_ambience.wet=0.0
	garden.camera.position=Vector3(0,20,30);garden.camera.look_at(Vector3(0,20,29))
	sound.play_effect_stream(load("res://audio/coastal_wind.wav"),Vector3(-4,20,30),-6,1)
	var directional=sound.effects[-1]
	var left=await record("source-left",.8)
	directional.global_position=Vector3(4,20,30)
	var right=await record("source-right",.8)
	check(left.left_energy>left.right_energy*2 and right.right_energy>right.left_energy*2,"Mono sources pan toward their actual world positions")
	directional.global_position=Vector3(0,20,-5)
	await record("source-beyond-range",.7,false)
	directional.stop();sound.set_process(true)
	Settings.effects=0;Settings.ambience=0;Settings.apply_audio()
	for player in sound.sources:player.play()
	sound.footstep(garden.nodes.arrival)
	await record("all-parent-buses-muted",.6,false)
	var pcm=PackedByteArray();pcm.resize(samples.size()*4)
	for i in samples.size():
		pcm.encode_s16(i*4,roundi(clampf(samples[i].x,-1,1)*32767))
		pcm.encode_s16(i*4+2,roundi(clampf(samples[i].y,-1,1)*32767))
	var wav=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS
	wav.stereo=true;wav.mix_rate=roundi(AudioServer.get_mix_rate());wav.data=pcm
	check(wav.save_to_wav(output.path_join("realism-audio-preview.wav"))==OK,"Engine stereo preview saved")
	FileAccess.open(output.path_join("realism-audio-audit.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"segments":segments,"failures":failures},"\t"))
	AudioServer.remove_bus_effect(0,capture_index)
	print("REALISM_AUDIO: ",checks," checks; failures=",failures)
	garden.queue_free();await get_tree().process_frame
	await get_tree().create_timer(.15).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
