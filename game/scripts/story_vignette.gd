extends Control
# Cinematic stills with a bounded camera move, not deforming picture vertices.
const FRAMES = [preload("res://assets/cinematics/tide.png"),preload("res://assets/cinematics/yaya.png"),preload("res://assets/cinematics/spring.png")]
const FILM = preload("res://shaders/story_film.gdshader")
var page = 0
var previous_page = -1
var previous_elapsed = 0.0
var elapsed = 0.0
var transition_elapsed = 0.0
var motion_paused = false
var review_time = -1.0
var image: TextureRect
var film: ShaderMaterial

func _ready():
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	image = TextureRect.new()
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture = FRAMES[page]
	film = ShaderMaterial.new();film.shader = FILM
	film.set_shader_parameter("previous_frame",FRAMES[page if previous_page<0 else previous_page])
	film.set_shader_parameter("previous_time",previous_elapsed)
	film.set_shader_parameter("direction",-1.0 if page==1 else 1.0)
	film.set_shader_parameter("previous_direction",-1.0 if previous_page==1 else 1.0)
	film.set_shader_parameter("has_previous",previous_page>=0)
	film.set_shader_parameter("page",page)
	film.set_shader_parameter("previous_page",previous_page)
	image.material = film
	add_child(image)
	update_film()

func _process(delta):
	if not motion_paused:elapsed += delta
	transition_elapsed += delta
	update_film()

func update_film():
	if not film:return
	film.set_shader_parameter("viewport_size",size.max(Vector2.ONE))
	film.set_shader_parameter("image_size",FRAMES[page].get_size())
	film.set_shader_parameter("elapsed",elapsed if review_time<0 else review_time)
	film.set_shader_parameter("transition_elapsed",transition_elapsed if review_time<0 else review_time)
	film.set_shader_parameter("compact",size.x<900)

func freeze_at(seconds: float):
	# Explicit review clock; runtime uses frame delta respecting frame caps.
	review_time = seconds
	elapsed = seconds
	update_film()
