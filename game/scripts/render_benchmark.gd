extends RefCounted
var garden: Node3D
func _init(g):garden=g
func percentile(values: Array,p: float) -> float:
	return values[clampi(int(values.size()*p),0,values.size()-1)]
func run():
	Engine.max_fps=60
	var report={"version":"1.6.1","renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),"viewport":"1280x800","mode":"Normal wall-clock rendering, 60 FPS cap; controlled completed-puzzle scenes, not player solve time.","chapters":[]}
	Journey.fresh()
	for tasks in Puzzles.TASKS:
		for task in tasks: Puzzles.finish(task)
	Puzzles.data.pipes=[1,3,2];Puzzles.data.valves=[2,1];Puzzles.data.fuses=[2,0,1];Puzzles.data.mirrors=[1,3];Puzzles.data.beds=[0,1,2];Puzzles.data.irrigation=[1,2,3];Puzzles.data.roots=[2,1];Puzzles.data.battery=true
	for c in 3:
		Journey.chapter=c;Journey.node_id=["landing","sun","landing"][c];Journey.fps_valid=false;Journey.bridge=1 if c!=1 else 0;Journey.lift=c==1
		garden.build_chapter();garden.playing=true;garden.ui.close_panel();garden.on_puzzle_update()
		garden.get_window().grab_focus()
		var start=Time.get_ticks_usec();var previous=start;var ms=[]
		var previous_draw=Engine.get_frames_drawn();var drawn=0
		while Time.get_ticks_usec()-start<33000000:
			await garden.get_tree().process_frame
			var now=Time.get_ticks_usec();var elapsed=float(now-start)/1000000.0
			garden.walker.yaw=sin(elapsed*.15)*.65;garden.walker.pitch=-.1+sin(elapsed*.22)*.12
			var frame_draw=Engine.get_frames_drawn()
			if elapsed>3:
				ms.append(float(now-previous)/1000.0)
				drawn+=frame_draw-previous_draw
			previous_draw=frame_draw
			previous=now
		ms.sort()
		var mean=0.0
		for v in ms:mean+=v
		mean/=maxi(1,ms.size())
		var item={"chapter":c+1,"samples":ms.size(),"frames_drawn":drawn,"draw_fraction":float(drawn)/maxi(1,ms.size()),"rendered_fps":drawn/30.0,"mean_fps":1000/mean,"median_frame_ms":percentile(ms,.5),"p95_frame_ms":percentile(ms,.95),"p99_frame_ms":percentile(ms,.99)}
		report.chapters.append(item);print("PERFORMANCE_CHAPTER: ",JSON.stringify(item))
	var method: String=report.renderer
	var file=FileAccess.open("res://../builds/performance-"+method+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	print("PERFORMANCE_COMPLETE: ",method)
	await garden.quit_game()
