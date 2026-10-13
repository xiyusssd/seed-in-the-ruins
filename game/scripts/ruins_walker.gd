extends CharacterBody3D
var garden: Node3D
var yaw = -PI / 4
var pitch = -0.08
var stride = 0.0
var last_step = 0.0

func _ready():
	collision_layer = 4
	collision_mask = 1
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.22
	capsule.height = 1.6
	shape.shape = capsule
	shape.position.y = 1.1
	add_child(shape)

func _physics_process(delta):
	if not garden or not garden.first_person: return
	if garden.busy:
		position = garden.avatar.position
		return
	if not garden.playing or not garden.ui or garden.ui.panel_open(): return
	if garden.capture: return
	var axis = Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	move_direction(axis, delta, Input.is_physical_key_pressed(KEY_SHIFT))

func move_direction(axis: Vector2, delta: float, fast = false):
	var speed = 3.6 if fast else 2.4
	var direction = Basis(Vector3.UP, yaw) * Vector3(axis.x, 0, axis.y).normalized()
	var candidate = position + direction * speed * delta
	var before=position
	var ground: float = garden.floor_at(candidate)
	if is_inf(ground):
		# Keep the supported part of diagonal movement when the other axis reaches an edge.
		var axes=[Vector3(direction.x,0,0),Vector3(0,0,direction.z)]
		if absf(direction.z)>absf(direction.x):axes.reverse()
		for axis_direction in axes:
			if axis_direction.length_squared()<.0001:continue
			var supported=garden.floor_at(position+axis_direction*speed*delta)
			if not is_inf(supported):direction=axis_direction;ground=supported;break
		if is_inf(ground):velocity=Vector3.ZERO;return
	position.y = ground + 0.055
	velocity = direction * speed
	move_and_slide()
	# Collision correction must not push the capsule beyond a supported platform.
	if is_inf(garden.floor_at(position)):
		position = before
		velocity = Vector3.ZERO
	garden.avatar.position = position
	if Vector2(position.x-before.x,position.z-before.z).length() > .001:
		stride += delta * (12 if fast else 9)
		last_step += delta
		if last_step > (0.32 if fast else 0.48):
			last_step = 0
			garden.soundscape.footstep(position,fast)
	garden.remember_player_position()

func look(relative: Vector2):
	if garden and garden.tutorial and relative.length()>4 and garden.playing and not garden.ui.panel_open():garden.tutorial.learn("look")
	yaw -= relative.x * 0.0022 * Settings.mouse_sensitivity
	pitch = clampf(pitch - relative.y * 0.0022 * Settings.mouse_sensitivity, -1.4, 1.4)

func eye_position() -> Vector3:
	return global_position + Vector3(0, 1.65 + sin(stride) * 0.012, 0)
