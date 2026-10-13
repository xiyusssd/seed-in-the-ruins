extends Node
var path = "user://ruins-settings.json"
var quality = "high"
var music = 0.75
var effects = 0.8
var ambience = 0.65
var story_seen = false
var fps_limit = 120
var vsync = true
var mouse_sensitivity = 1.0
func _ready():
	if FileAccess.file_exists(path):
		var value = JSON.parse_string(FileAccess.get_file_as_string(path))
		if value is Dictionary:
			story_seen = value.get("story_seen",false) == true
			quality = "compatible" if value.get("quality") == "compatible" else "high"
			fps_limit = int(value.get("fps_limit",120)) if value.get("fps_limit",120) in [0,60,120,144] else 120
			vsync = value.get("vsync",true)==true
			var sensitivity=value.get("mouse_sensitivity",1.0)
			if (sensitivity is float or sensitivity is int) and not is_nan(float(sensitivity)) and not is_inf(float(sensitivity)):
				mouse_sensitivity=clampf(float(sensitivity),.5,2.0)
			for key in ["music","effects","ambience"]:
				var v = value.get(key,0.75)
				if v is float or v is int: set(key,clampf(float(v),0,1))
	for name in ["Music","Effects","Ambience"]:
		if AudioServer.get_bus_index(name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,name)
	apply_audio()
	apply_video()
func apply_video():
	Engine.max_fps=fps_limit
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
func cycle_fps():
	var limits=[60,120,144,0]
	fps_limit=limits[(limits.find(fps_limit)+1)%limits.size()]
	apply_video();save()
func apply_audio():
	for pair in [["Music",music],["Effects",effects],["Ambience",ambience]]:
		var index = AudioServer.get_bus_index(pair[0])
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(0.0001,pair[1])))
		AudioServer.set_bus_mute(index,pair[1] == 0)
func save():
	var file = FileAccess.open(path,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"quality":quality,"music":music,"effects":effects,"ambience":ambience,"story_seen":story_seen,"fps_limit":fps_limit,"vsync":vsync,"mouse_sensitivity":mouse_sensitivity}))
func verification() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg in ["--garden-test","--puzzle-test","--playability-test","--garden-capture","--garden-film","--verify-build","--performance-test","--wasteland-test","--offscreen-capture"]: return true
	return false
func restart_with_quality(next_quality: String):
	quality = next_quality
	save()
	Journey.save_journey()
	var args = ["--rendering-method","gl_compatibility" if quality == "compatible" else "forward_plus"]
	if OS.has_feature("editor"): args.append_array(["--path",ProjectSettings.globalize_path("res://")])
	OS.create_process(OS.get_executable_path(),args)
	get_tree().quit()
