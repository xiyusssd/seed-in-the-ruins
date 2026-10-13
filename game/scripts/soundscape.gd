extends Node
var garden: Node3D
var music_players: Array[AudioStreamPlayer] = []
var sources: Array[AudioStreamPlayer3D] = []
var cooldown: Dictionary = {}
var effects: Array[AudioStreamPlayer3D] = []
var active_chapter = -1
var suspended = false
var playback_enabled = DisplayServer.get_name()!="headless"
var presentation_music: AudioStreamPlayer
var presentation_air: Array[AudioStreamPlayer] = []
var ui_players: Array[AudioStreamPlayer] = []
var presentation_kind = "title"
var story_page = 0
var presentation_gain = 0.0
var world_gain = 0.0
var page_gains = [0.0,0.0,0.0]
var ui_events: Dictionary = {}
var ambience_layers: Array=[]
var room_foley: AudioEffectReverb
var room_ambience: AudioEffectReverb
var occlusion_clock=0.0
var room_amount=0.0
var foot_index=0
var foot_streams: Dictionary={}
var foley_rng=RandomNumberGenerator.new()

func _ready():
	foley_rng.randomize()
	room_foley=room_bus("WorldFoley","Effects")
	room_ambience=room_bus("WorldAmbience","Ambience")
	for material in ["stone","metal"]:
		foot_streams[material]=[]
		for take in 4:foot_streams[material].append(load("res://audio/foot_%s_%d.wav"%[material,take]))
	presentation_music=AudioStreamPlayer.new()
	presentation_music.name="PrologueMusic"
	presentation_music.stream=loop_stream("prologue_score")
	presentation_music.bus="Music";presentation_music.volume_db=-80
	add_child(presentation_music)
	if playback_enabled:presentation_music.play()
	for page in 3:
		var player=AudioStreamPlayer.new();player.name="StoryAir%d"%page
		player.stream=loop_stream("prologue_air%d"%page)
		player.bus="Ambience";player.volume_db=-80
		add_child(player)
		if playback_enabled:player.play()
		presentation_air.append(player)

func room_bus(label: String,parent: String) -> AudioEffectReverb:
	var index=AudioServer.get_bus_index(label)
	if index<0:
		AudioServer.add_bus();index=AudioServer.bus_count-1;AudioServer.set_bus_name(index,label)
	AudioServer.set_bus_send(index,parent)
	var effect: AudioEffectReverb
	if AudioServer.get_bus_effect_count(index)>0:effect=AudioServer.get_bus_effect(index,0)
	else:
		effect=AudioEffectReverb.new();AudioServer.add_bus_effect(index,effect)
	effect.room_size=.62;effect.damping=.68;effect.spread=.7;effect.dry=1;effect.wet=.04
	return effect

func presentation(kind: String,page=0):
	presentation_kind=kind
	story_page=clampi(page,0,2)

func enable_review_audio():
	# Only used by the isolated mixer review, never written to settings.
	playback_enabled=true
	for player in [presentation_music]+presentation_air+music_players+sources:
		if not player.playing:player.play()

func ui_effect(key: String):
	var now=Time.get_ticks_msec()
	if now-int(cooldown.get(key,-1000))<70:return
	cooldown[key]=now
	ui_events[key]=int(ui_events.get(key,0))+1
	if not playback_enabled:return
	ui_players=ui_players.filter(func(n):return is_instance_valid(n))
	if ui_players.size()>=8:return
	var player=AudioStreamPlayer.new();player.stream=load("res://audio/"+key+".wav")
	player.bus="Effects";player.volume_db=-15 if key=="ui_hover" else -8
	add_child(player);ui_players.append(player)
	player.finished.connect(player.queue_free);player.play()

func amplitude_db(value: float) -> float:
	return linear_to_db(maxf(value,.0001))

func loop_stream(key: String) -> AudioStreamWAV:
	var stream = load("res://audio/"+key+".wav").duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length()*stream.mix_rate)
	return stream
func chapter(chapter_id: int):
	if active_chapter == chapter_id: return
	active_chapter = chapter_id
	for node in music_players+sources: node.stream_paused=false;node.stop();node.queue_free()
	music_players.clear();sources.clear();ambience_layers.clear()
	for suffix in ["base","warm"]:
		var player = AudioStreamPlayer.new()
		player.stream = loop_stream("chapter%d_%s"%[chapter_id,suffix])
		player.bus = "Music"
		player.volume_db = -80
		add_child(player)
		if playback_enabled: player.play()
		music_players.append(player)
	var wind = spatial_loop("coastal_wind",garden.nodes.arrival,-22)
	wind.bus="Ambience";wind.set_meta("wind_bed",true)
	wind.max_distance = 40
	if chapter_id == 0:
		spatial_loop("channel_flow",garden.nodes.spring+Vector3(0,.55,0),-14,"water_route")
		spatial_loop("pump_mechanism",garden.nodes.altar+Vector3(0,1.2,0),-12,"pump")
	elif chapter_id == 1:
		spatial_loop("greenhouse_drips",Vector3(11.1,1.9,7.4),-13)
		spatial_loop("greenhouse_drips",Vector3(-10.1,2.2,7.4),-17)
		spatial_loop("canopy_rustle",Vector3(8.6,3.4,2),-20)
	else:
		for id in ["west","east","north"]:spatial_loop("canopy_rustle",garden.nodes[id]+Vector3(0,1.2,0),-18)
		spatial_loop("channel_flow",garden.nodes.north+Vector3(0,.45,0),-22,"irrigation")
	for side in [-1,1]:
		var sea=spatial_loop("coastal_surf",Vector3(side*17,-.3,7),-13)
		sea.unit_size=9;sea.max_distance=80;sea.panning_strength=.55
func surface_at(p: Vector3) -> String:
	if is_instance_valid(garden.elevator) and Journey.chapter==1:
		var local=garden.elevator.to_local(p)
		if absf(local.x)<1.22 and absf(local.z)<1.22 and absf(local.y)<.25:return "metal"
	if is_instance_valid(garden.rotor) and Journey.chapter<2:
		var local=garden.rotor.to_local(p)
		if absf(local.x)<4 and absf(local.z)<.72 and absf(local.y)<.25:return "metal"
	return "stone"
func footstep(p: Vector3,fast=false):
	var material=surface_at(p);var take=foot_index%4;foot_index+=1
	if not playback_enabled:return
	play_effect_stream(foot_streams[material][take],p+Vector3(0,.09,0),-13 if fast else -17,foley_rng.randf_range(.96,1.04))

func spatial_loop(key: String, p: Vector3, volume: float,task="") -> AudioStreamPlayer3D:
	var player = AudioStreamPlayer3D.new()
	player.stream = loop_stream(key)
	player.bus = "WorldAmbience"
	player.volume_db = -80
	player.max_distance = 25
	player.unit_size = 5
	player.attenuation_filter_cutoff_hz=6500;player.attenuation_filter_db=-16
	player.max_db=0
	add_child(player)
	player.global_position = p
	if playback_enabled: player.play(fmod(sources.size()*7.31,player.stream.get_length()))
	sources.append(player)
	ambience_layers.append({"player":player,"asset":key,"level":volume,"task":task,"blocked":false,"gain":0.0})
	return player
func effect(key: String, p: Vector3, volume = -19):
	if not playback_enabled:return
	var now = Time.get_ticks_msec()
	if now-int(cooldown.get(key,-1000)) < 130: return
	cooldown[key] = now
	var pitch=foley_rng.randf_range(.96,1.04) if key in ["valve","module","mirror","robot_tread"] else 1.0
	play_effect_stream(load("res://audio/"+key+".wav"),p,volume,pitch)
func play_effect_stream(stream: AudioStream,p: Vector3,volume: float,pitch: float):
	effects = effects.filter(func(n):return is_instance_valid(n))
	if effects.size() >= 14: return
	var player = AudioStreamPlayer3D.new()
	player.stream = stream;player.pitch_scale=pitch
	player.bus = "WorldFoley"
	player.volume_db = volume
	player.unit_size = 4
	player.max_distance = 30
	player.attenuation_filter_cutoff_hz=6200;player.max_db=0
	add_child(player)
	player.global_position = p
	player.finished.connect(player.queue_free)
	effects.append(player)
	player.play()
func shelter_at(p: Vector3) -> float:
	var boundary=-10.0
	if Journey.chapter==0:
		boundary=minf(minf(p.x+9.9,3.9-p.x),minf(p.z+11.5,-4.9-p.z))
		if p.y>12.3:return 0.0
	elif Journey.chapter==1:
		boundary=minf(minf(p.x+10.0,11.0-p.x),minf(p.z+3.8,7.4-p.z))
		if p.y>13.4:return 0.0
	return smoothstep(-.65,.9,boundary)*(0.65 if Journey.chapter==1 and Puzzles.done("roof") else 1.0)
func is_occluded(eye: Vector3,source: Vector3) -> bool:
	if eye.distance_to(source)<.6:return false
	var ray=PhysicsRayQueryParameters3D.create(eye,source,1)
	var hit=garden.get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and hit.position.distance_to(source)>.35
func update_environment_audio(delta: float):
	var eye=garden.camera.global_position
	var shelter=shelter_at(eye)
	room_amount=lerpf(room_amount,shelter,1.-exp(-delta*2.5))
	room_foley.wet=lerpf(.025,.22,room_amount)
	room_ambience.wet=lerpf(.025,.13,room_amount)
	occlusion_clock+=delta
	var trace=occlusion_clock>=.15 and not suspended
	if trace:occlusion_clock=0
	for layer in ambience_layers:
		var player=layer.player
		var level:float=layer.level
		if player.has_meta("wind_bed"):
			if is_instance_valid(garden.wind_field):
				player.global_position=eye-garden.wind_field.direction*5
				level=lerpf(-23,-17,garden.wind_field.gust)
			level-=shelter*8
		else:
			if trace:layer.blocked=is_occluded(eye,player.global_position)
			if layer.blocked:level-=7
			if layer.asset=="coastal_surf":level-=shelter*6
		if not layer.task.is_empty() and not Puzzles.done(layer.task):level=-72
		layer.gain=lerpf(layer.gain,db_to_linear(level),1.-exp(-delta*3.5))
		player.volume_db=amplitude_db(layer.gain*world_gain)
		var cutoff=1800.0 if layer.blocked else lerpf(6500,3500,shelter) if player.has_meta("wind_bed") else 6500.0
		player.attenuation_filter_cutoff_hz=lerpf(player.attenuation_filter_cutoff_hz,cutoff,1.-exp(-delta*4.0))
func _process(delta):
	if not garden or music_players.is_empty(): return
	var paused = not garden.playing or (garden.ui and garden.ui.panel_open())
	suspended=paused
	# World audio pauses with simulation; the separate presentation score stays alive.
	for player in music_players+sources+effects.filter(func(n):return is_instance_valid(n)): player.stream_paused = paused
	var blend=1.0-exp(-delta*2.0)
	presentation_gain=lerpf(presentation_gain,1.0 if paused else 0.0,blend)
	world_gain=lerpf(world_gain,0.0 if paused else 1.0,blend)
	presentation_music.volume_db=(-1 if presentation_kind=="prologue" else -8)+amplitude_db(presentation_gain)
	presentation_music.stream_paused=presentation_gain<.001 and not paused
	for page in 3:
		var wanted=1.0 if paused and story_page==page else 0.0
		page_gains[page]=lerpf(page_gains[page],wanted,blend)
		presentation_air[page].volume_db=(-11 if presentation_kind=="prologue" else -25)+amplitude_db(page_gains[page])
		presentation_air[page].stream_paused=page_gains[page]<.001 and wanted==0
	music_players[0].volume_db=-9+amplitude_db(world_gain)
	var warmth = clampf(garden.recovery*0.45+Puzzles.progress(Journey.chapter)*0.55,0,1)
	music_players[1].volume_db = lerpf(-30,-12,warmth)+amplitude_db(world_gain)
	update_environment_audio(delta)
