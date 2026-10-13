extends Node
var checks=0
var failures=[]
func check(value: bool,message: String):
	checks+=1
	if not value:failures.append(message);push_error(message)
func settle():
	await get_tree().process_frame
	await get_tree().process_frame
func click(ui,text: String):
	for item in ui.overlay.find_children("*","Button",true,false):
		if item is Button and item.text==text:
			item.pressed.emit()
			return true
	return false
func key(garden,code):
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true
	garden._unhandled_input(event)
func centered(ui) -> bool:
	return ui.menu_card.get_global_rect().get_center().distance_to(ui.root.get_global_rect().get_center())<1
func _ready():run.call_deferred()
func run():
	Journey.save_path="user://menu-suite-v4.json";Journey.fresh()
	Settings.path="user://menu-suite-settings.json";Settings.story_seen=true
	var garden=load("res://garden.tscn").instantiate();add_child(garden)
	await settle()
	var ui=garden.ui
	check(ui.panel_kind=="title" and centered(ui),"Startup menu is centered before exploration")
	check(not ui.overlay.find_children("*","Button",true,false).any(func(n):return "帮助" in n.text),"Startup removes the standalone help entry")
	click(ui,"设置");await settle();key(garden,KEY_ESCAPE);await settle()
	check(ui.panel_kind=="title","Escape from startup Settings returns to the startup menu")
	garden.playing=true;ui.close_panel();garden.capture=true
	key(garden,KEY_ESCAPE);await settle()
	check(ui.panel_kind=="pause" and centered(ui),"Escape opens a centered game menu")
	check(not ui.overlay.find_children("*","Button",true,false).any(func(n):return "帮助" in n.text),"Pause menu removes help and puzzle-help entries")
	key(garden,KEY_ESCAPE);await settle()
	check(not ui.panel_open() and ui.hud.visible,"Escape from the menu resumes exploration")
	ui.say("尚未接通。请检查维护刻痕。")
	garden.hovered=load("res://scripts/puzzle_playthrough.gd").new(garden).target("puzzle","pipe:0")
	await settle()
	check(ui.hud.find_children("*","Label",true,false).is_empty() and not ui.panel_open(),"Hover and operation feedback do not create text overlays or automatic popups")
	ui.journal();await settle()
	check(ui.content.get_children().any(func(n):return n is Label and "尚未接通" in n.text),"Removed toasts remain available when the player requests records")
	ui.close_panel();ui.chapter_complete();await settle()
	check(not ui.panel_open(),"Completing a chapter does not automatically cover the restored world")
	Journey.chapter=2;Journey.fps_valid=false;garden.build_chapter()
	Puzzles.data.plant_bag=[0,1,2];Puzzles.data.plant_hand=0
	ui.pause_menu();click(ui,"随身物品");await settle()
	check(ui.panel_kind=="inventory" and centered(ui) and click(ui,"豆科"),"Menu inventory allows selecting a carried seedling")
	check(Puzzles.data.plant_hand==1 and Puzzles.data.plant_bag==[0,1,2],"Selecting in the menu preserves all carried items")
	Journey.save_journey();Puzzles.reset_all();Journey.load_journey()
	check(Puzzles.data.plant_hand==1 and Puzzles.data.plant_bag==[0,1,2],"Menu item selection survives save and reload")
	ui.root.size=Vector2(960,600);ui.pause_menu();await settle()
	var bounds=ui.menu_card.get_global_rect()
	check(centered(ui) and bounds.position.y>=0 and bounds.end.y<=ui.root.size.y,"Menus remain centered and within a smaller viewport")
	ui.root.size=Vector2(1280,800);ui.start_new();await settle()
	check(ui.panel_kind=="prologue" and not ui.hud.visible and Journey.chapter==0,"A new journey opens its background story before exploration")
	for page in 3:
		ui.prologue_screen(page);await settle()
		check(centered(ui) and ui.menu_card.size==ui.root.size and ui.story_art.size==ui.root.size,"Prologue page %d fills the complete viewport"%page)
		check(ui.story_art.clip_contents,"Cinematic panorama clips to the viewport on page %d"%page)
		var story_scroll: ScrollContainer=ui.content.get_parent()
		check(story_scroll.get_v_scroll_bar().max_value<=story_scroll.get_v_scroll_bar().page+1,"Prologue page %d and its navigation fit without scrolling"%page)
		var previous=ui.overlay.find_child("StoryPrevious",true,false)
		var next=ui.overlay.find_child("StoryNext",true,false)
		var skip=ui.overlay.find_child("StorySkip",true,false)
		var card=ui.menu_card.get_global_rect()
		check(previous.get_global_rect().position.x<card.get_center().x and previous.get_global_rect().position.y>card.get_center().y,"Previous page sits at bottom left")
		check(next.get_global_rect().end.x>card.get_center().x and next.get_global_rect().position.y>card.get_center().y,"Next page sits at bottom right")
		check(skip.get_global_rect().end.x>card.get_center().x and skip.get_global_rect().position.y<card.get_center().y,"Skip sits at top right")
		check(previous.disabled==(page==0),"First page cannot navigate before the beginning")
	ui.prologue_screen(0);check(click(ui,"下一页"),"Next page advances the story");await settle()
	check(ui.content.get_children().any(func(n):return n is Label and n.text==ui.PROLOGUE[1][0]),"Next opens the second story page")
	check(click(ui,"上一页"),"Previous page returns to the story");await settle()
	check(ui.content.get_children().any(func(n):return n is Label and n.text==ui.PROLOGUE[0][0]),"Previous opens the first story page")
	ui.prologue_screen(0)
	check(garden.camera.cull_mask==0,"Full-screen story suspends hidden 3D drawing")
	var clock=ui.story_art.elapsed
	click(ui,"静止画面");await settle()
	check(ui.story_art.motion_paused and is_equal_approx(clock,ui.story_art.elapsed),"Static picture pauses camera without advancing the story")
	click(ui,"下一页");await settle()
	check(ui.story_art.page==1 and ui.story_art.motion_paused and ui.story_art.transition_elapsed>0,"Paused camera still completes page transitions")
	click(ui,"继续镜头");await settle()
	check(not ui.story_art.motion_paused and ui.story_art.elapsed>0,"Continue resumes the camera")
	click(ui,"跳过");await settle()
	check(garden.camera.cull_mask>0,"Leaving the story restores the 3D camera")
	check(not ui.panel_open() and garden.playing and garden.first_person,"Skipping the story still enters the first chapter normally")
	ui.title_screen();ui.prologue_screen(2,"title");click(ui,"返回菜单");await settle()
	check(ui.panel_kind=="title" and not garden.playing,"Re-reading the background story returns to the menu without starting or resetting progress")
	var settings_path=Settings.path;var seen=Settings.story_seen
	Settings.path="user://story-verification-settings.json";Settings.story_seen=false
	var memories=Journey.memories.duplicate();var puzzles=Puzzles.snapshot()
	ui.prologue_screen(0,"arrival");await settle()
	check(ui.panel_kind=="prologue" and not garden.playing and ui.layer>20,"First arrival keeps the story illustration in colour above the grayscale world")
	ui.finish_prologue();await settle()
	var saved=JSON.parse_string(FileAccess.get_file_as_string(Settings.path))
	check(saved.story_seen and ui.panel_kind=="title" and not garden.playing,"Finishing or skipping the first arrival is saved and returns to the launch menu")
	check(Journey.memories==memories and Puzzles.snapshot()==puzzles,"Reading the first arrival does not reset a returning player's save")
	Settings.path=settings_path;Settings.story_seen=seen
	ui.root.size=Vector2(640,480);ui.prologue_screen(1,"title");await settle()
	check(centered(ui) and ui.menu_card.get_global_rect().end.y<=480,"Small windows keep the story card and scrollable navigation on screen")
	var small_scroll: ScrollContainer=ui.content.get_parent()
	small_scroll.scroll_vertical=200;await settle()
	check(small_scroll.get_v_scroll_bar().is_visible_in_tree() and small_scroll.get_v_scroll_bar().size.x>=5,"Small-window story exposes a visible scroll indicator")
	for name in ["StoryPrevious","StoryNext","StorySkip"]:
		var nav=ui.overlay.find_child(name,true,false)
		check(ui.menu_card.get_global_rect().encloses(nav.get_global_rect()) and not small_scroll.is_ancestor_of(nav),"Small-window navigation stays visible outside the text scroll: "+name)
	print("MENU_TESTS: ",checks," checks; failures=",failures)
	garden.queue_free();await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
