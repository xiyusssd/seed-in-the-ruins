extends Node
var checks=0
var failures=[]
func check(value: bool,message: String):
	checks+=1
	if not value:failures.append(message);push_error(message)
func _ready():run.call_deferred()
func run():
	Journey.save_path="user://isolated-maintenance-record-tests.json";Journey.fresh()
	var garden=load("res://garden.tscn").instantiate();add_child(garden)
	await get_tree().physics_frame
	for chapter in 3:
		if chapter>0:Journey.chapter=chapter;Journey.lift=true;garden.build_chapter();await get_tree().physics_frame
		garden.playing=true;garden.capture=true;garden.ui.close_panel();garden.enter_first_person()
		garden.set_process(false);garden.walker.set_physics_process(false);garden.companion.set_process(false)
		garden.tutorial.suppressed=true
		for key in garden.puzzle_world.record_boards:
			var board=garden.puzzle_world.record_boards[key]
			var body: Label3D=board.get_node("Body")
			var printed=board.find_children("*","Label3D",true,false)
			check(body.text.split("\n").size()>=5 and printed.size()==4,"Record "+key+" has a title, device code, actual instructions and read prompt")
			var fits=true;var supported=true
			for line in printed:
				for row in line.text.split("\n"):
					fits=fits and line.font.get_string_size(row,HORIZONTAL_ALIGNMENT_LEFT,-1,line.font_size).x*line.pixel_size<=.98
					for char_value in row:supported=supported and line.font.has_char(char_value.unicode_at(0))
			check(fits and supported,"All inscription lines fit the surviving stone and have real glyphs in "+key)
			var stone: MeshInstance3D=board.get_node("BrokenInscriptionStone")
			var outline: PackedVector2Array=stone.get_meta("broken_outline")
			var inside=true
			for point in [Vector2(-.49,.90),Vector2(.49,.90),Vector2(-.49,1.40),Vector2(.49,1.40),Vector2(-.42,1.69),Vector2(.42,1.69)]:inside=inside and Geometry2D.is_point_in_polygon(point,outline)
			check(stone.mesh.get_aabb().size.z>.25 and Geometry2D.decompose_polygon_in_convex(outline).size()>1 and inside and body.shaded,"Broken stone has actual thickness and missing edges while retaining the readable clues in "+key)
			var inscription=JSON.parse_string(FileAccess.get_file_as_string("res://assets/inscriptions/manifest.json")).assets[key]
			var depth_map: Texture2D=stone.material_override.get_shader_parameter("inscription_depth")
			check(depth_map.get_width()==1024 and inscription.body==body.text and inscription.title==board.get_node("Title").text and not printed.any(func(n):return n.visible),"Visible clues use matching worn engraving depth maps instead of floating printed lettering in "+key)
			garden.walker.position=board.get_meta("reading_position");garden.avatar.position=garden.walker.position
			check(not is_inf(garden.floor_at(garden.walker.position)),"Reading position is supported by the actual walkway for "+key)
			var face=board.get_meta("reading_target")
			var toward=garden.walker.position-face;toward.y=0
			check(board.global_basis.z.normalized().dot(toward.normalized())>.99,"Printed face points toward the approachable platform in "+key)
			garden.aim_at(face);await get_tree().physics_frame
			var hit=garden.pick_at(garden.get_viewport().get_visible_rect().size/2)
			check(hit and hit.get_meta("action","")=="inspect" and hit.get_meta("id","")==key and garden.valid_nearby_target(hit),"Actual player ray reaches record "+key)
			var colours=Journey.memories.duplicate()
			var event=InputEventKey.new();event.physical_keycode=KEY_E;event.pressed=true;garden._unhandled_input(event)
			check(garden.ui.panel_kind=="record" and key in Puzzles.data.records and Journey.memories==colours,"Real E input opens and archives "+key+" without awarding puzzle completion")
			check(garden.ui.content.get_children().any(func(n):return n is Label and n.text==garden.puzzle_world.NOTES[key].split("\n\n",true,1)[1]),"Opened record contains the full original maintenance instructions")
			garden.ui.close_panel()
	Journey.save_journey();Puzzles.reset_all();Journey.load_journey()
	check(Puzzles.data.records.size()==6,"All six records persist in the existing save format")
	garden.queue_free();await get_tree().process_frame
	print("MAINTENANCE_RECORD_FLOW: ",checks," checks; failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
