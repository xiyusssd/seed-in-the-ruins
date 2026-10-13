extends Node
var garden
var capture: AudioEffectCapture
var segments=[]
var samples=PackedVector2Array()
var failures=[]
func _ready():run.call_deferred()
func record(label: String,seconds: float,expect_sound=true):
	await get_tree().create_timer(.25).timeout
	capture.clear_buffer()
	await get_tree().create_timer(seconds).timeout
	var frames=capture.get_buffer(capture.get_frames_available())
	var energy=0.0;var peak=0.0
	for pair in frames:
		energy+=pair.length_squared()
		peak=maxf(peak,maxf(absf(pair.x),absf(pair.y)))
	var rms=sqrt(energy/maxi(1,frames.size()*2))
	if frames.is_empty() or peak>=.99:failures.append(label+": empty or clipped mix")
	if expect_sound and rms<.0001:failures.append(label+": expected audible mix")
	if not expect_sound and peak>.00001:failures.append(label+": muted buses leaked sound")
	segments.append({"name":label,"frames":frames.size(),"seconds":float(frames.size())/AudioServer.get_mix_rate(),"peak":peak,"rms":rms,"expected_sound":expect_sound})
	samples.append_array(frames)
func run():
	Journey.save_path="user://isolated-audio-mix-review.json";Journey.fresh()
	Settings.music=.75;Settings.effects=.8;Settings.ambience=.65;Settings.apply_audio()
	AudioServer.set_bus_mute(0,false)
	capture=AudioEffectCapture.new();capture.buffer_length=16
	var index=AudioServer.get_bus_effect_count(0);AudioServer.add_bus_effect(0,capture)
	garden=load("res://garden.tscn").instantiate();add_child(garden)
	garden.capture=true;garden.soundscape.enable_review_audio()
	for page in 3:
		garden.ui.prologue_screen(page,"title")
		await record("story-page-%d"%page,1.3)
	garden.ui.title_screen();await record("title-menu",1.0)
	for chapter in 3:
		Journey.chapter=chapter;Journey.fps_valid=false;garden.build_chapter()
		garden.playing=true;garden.ui.close_panel();garden.camera.cull_mask=0
		await record("chapter-%d"%chapter,1.1)
	Settings.music=0;Settings.ambience=0;Settings.apply_audio()
	await get_tree().create_timer(.3).timeout
	garden.soundscape.ui_effect("ui_page");await record("page-foley-only",.7)
	Settings.effects=0;Settings.apply_audio();garden.soundscape.ui_effect("ui_page")
	await record("all-three-buses-muted",.5,false)
	var pcm=PackedByteArray();pcm.resize(samples.size()*4)
	for i in samples.size():
		pcm.encode_s16(i*4,roundi(clampf(samples[i].x,-1,1)*32767))
		pcm.encode_s16(i*4+2,roundi(clampf(samples[i].y,-1,1)*32767))
	var wav=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.stereo=true;wav.mix_rate=roundi(AudioServer.get_mix_rate());wav.data=pcm
	if wav.save_to_wav("/review/audio-mix-preview.wav")!=OK:failures.append("Cannot save engine mix")
	FileAccess.open("/review/audio-mix-audit.json",FileAccess.WRITE).store_string(JSON.stringify({"segments":segments,"mix_rate":AudioServer.get_mix_rate(),"failures":failures},"\t"))
	print("AUDIO_MIX_REVIEW: ",segments.size()," segments; failures=",failures)
	AudioServer.remove_bus_effect(0,index)
	garden.queue_free();await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
