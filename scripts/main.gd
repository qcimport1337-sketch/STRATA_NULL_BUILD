extends Node3D

var player: CharacterBody3D
var follow_pivot: Node3D
var cam: Camera3D
var projector_cam: Camera3D
var info_label: Label
var hero_yaw := -0.12
var hero_pitch := -0.05
var move_speed := 6.0
var mouse_captured := false
var gravity := 18.0
var project_material: ShaderMaterial
var projection_targets: Array[GeometryInstance3D] = []

func _ready() -> void:
	if "--smoke-test" in OS.get_cmdline_user_args():
		print("STRATA_SMOKE_READY")
		get_tree().quit()
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true
	_setup_world()
	_setup_ui()
	_update_projector_uniforms()

func _setup_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02,0.02,0.03)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1,1,1)
	e.ambient_light_energy = 0.85
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)

	var dir := DirectionalLight3D.new()
	dir.light_energy = 1.3
	dir.rotation_degrees = Vector3(-48, 25, 0)
	add_child(dir)

	projector_cam = Camera3D.new()
	projector_cam.name = "ProjectorCamera"
	projector_cam.fov = 52.0
	projector_cam.current = false
	projector_cam.position = Vector3(-0.2, 4.9, 20.5)
	add_child(projector_cam)
	projector_cam.look_at(Vector3(0.4, 2.4, -9.0), Vector3.UP)

	project_material = _make_projected_material()
	_build_environment()
	_build_player()

func _make_projected_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D project_tex : source_color;
uniform mat4 projector_matrix;
uniform vec3 fallback_color = vec3(0.06, 0.06, 0.07);
varying vec4 proj_pos;
void vertex() {
	proj_pos = projector_matrix * MODEL_MATRIX * vec4(VERTEX, 1.0);
}
void fragment() {
	vec3 color = fallback_color;
	if (proj_pos.w > 0.0) {
		vec3 ndc = proj_pos.xyz / proj_pos.w;
		vec2 uv = ndc.xy * 0.5 + vec2(0.5);
		bool inside = uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0 && ndc.z >= -1.0 && ndc.z <= 1.0;
		if (inside) color = texture(project_tex, vec2(uv.x, 1.0 - uv.y)).rgb;
	}
	ALBEDO = color;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var b64 := ""
	for i in range(6):
		var path := "res://assets/scene001_b64_%02d.txt" % i
		var file := FileAccess.open(path, FileAccess.READ)
		if file: b64 += file.get_as_text()
	var bytes := Marshalls.base64_to_raw(b64)
	var img := Image.new()
	var err := img.load_jpg_from_buffer(bytes)
	if err != OK:
		img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.15,0.15,0.15,1))
	mat.set_shader_parameter("project_tex", ImageTexture.create_from_image(img))
	return mat

func _register_projected(mi: MeshInstance3D) -> void:
	mi.material_override = project_material
	projection_targets.append(mi)

func _add_box(size: Vector3, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.position = pos
	mi.rotation_degrees = rot_deg
	_register_projected(mi)
	add_child(mi)
	return mi

func _add_cylinder(radius: float, height: float, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, radial_segments:=16) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = radial_segments
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.position = pos
	mi.rotation_degrees = rot_deg
	_register_projected(mi)
	add_child(mi)
	return mi

func _build_environment() -> void:
	_add_box(Vector3(36, 0.4, 18), Vector3(0, -0.2, -3))
	_add_box(Vector3(12, 3.0, 8), Vector3(8.5, -1.6, -5.0))
	_add_box(Vector3(5, 0.45, 5), Vector3(-12, -0.2, -2.5), Vector3(0, 0, -18))
	_add_box(Vector3(8, 0.45, 4.2), Vector3(-6.5, -0.1, -0.2), Vector3(0, 0, -10))
	_add_box(Vector3(7.5, 0.45, 4.5), Vector3(5.7, -0.1, 0.1), Vector3(0, 0, 9))
	_add_box(Vector3(1.5, 10, 24), Vector3(-17.5, 4.5, -5))
	_add_box(Vector3(1.5, 10, 24), Vector3(17.5, 4.5, -5))
	_add_box(Vector3(36, 11, 1.5), Vector3(0, 4.8, -17.5))
	for p in [Vector3(-12.8, 4.0, -4.5), Vector3(-4.3, 4.2, -5.8), Vector3(4.8, 4.3, -5.4), Vector3(13.0, 4.1, -4.3), Vector3(-14.5, 4.0, -13.0), Vector3(14.2, 4.0, -13.5), Vector3(0,4.1,-13.2)]:
		_add_box(Vector3(2.4, 8.5, 2.4), p)
	_add_box(Vector3(12, 0.35, 1.8), Vector3(0.0, 5.9, -8.8), Vector3(0, 10, 0))
	_add_box(Vector3(10, 0.35, 1.8), Vector3(-8.0, 6.4, -10.8), Vector3(0, 28, 0))
	_add_box(Vector3(8, 0.35, 1.8), Vector3(8.7, 6.0, -11.8), Vector3(0, -28, 0))
	_add_box(Vector3(8.5, 0.35, 1.8), Vector3(-11.5, 6.2, -4.5), Vector3(0, 40, 0))
	_add_box(Vector3(8.5, 0.35, 1.8), Vector3(11.4, 6.2, -4.7), Vector3(0, -40, 0))
	for pipe in [
		[Vector3(-8.5, 8.8, 1.0), Vector3(0,0,90), 25.0, 0.55],
		[Vector3(2.5, 8.5, 0.0), Vector3(0,0,90), 28.0, 0.65],
		[Vector3(10.5, 8.2, -1.2), Vector3(0,0,90), 24.0, 0.5],
		[Vector3(-13.5, 7.3, -7.0), Vector3(90,0,0), 16.0, 0.28],
		[Vector3(13.7, 7.3, -7.0), Vector3(90,0,0), 16.0, 0.28]
	]: _add_cylinder(pipe[3], pipe[2], pipe[0], pipe[1])
	for spec in [
		[Vector3(1.1,2.4,0.9), Vector3(-1.7,1.0,-3.2), Vector3(16,8,18)],
		[Vector3(0.8,1.8,0.8), Vector3(-0.7,0.8,-3.1), Vector3(-10,15,8)],
		[Vector3(1.4,2.0,0.9), Vector3(-2.6,0.9,-2.2), Vector3(4,-24,-4)],
		[Vector3(0.8,1.5,0.8), Vector3(-3.5,0.7,-2.8), Vector3(0,12,11)]
	]: _add_box(spec[0], spec[1], spec[2])
	_add_cylinder(0.55, 3.6, Vector3(8.5, 3.5, -5.1), Vector3.ZERO, 10)
	_add_cylinder(0.35, 1.2, Vector3(8.5, 5.7, -5.0), Vector3.ZERO, 10)
	for leg in [Vector3(-0.45,-1.9,0.25), Vector3(0.45,-1.9,0.25), Vector3(-0.65,-1.8,-0.25), Vector3(0.65,-1.8,-0.25)]:
		_add_cylinder(0.07, 4.9, Vector3(8.5+leg.x, 3.5+leg.y/2.0, -5.1+leg.z), Vector3(leg.x*38.0, 0, leg.x*20.0), 6)
	for arm in [Vector3(-0.8,0.7,0.0), Vector3(0.8,0.6,0.0)]:
		_add_cylinder(0.06, 3.6, Vector3(8.5+arm.x, 3.9+arm.y, -5.0), Vector3(0,0, (-28 if arm.x > 0 else 28)), 6)
	var eye := OmniLight3D.new()
	eye.light_color = Color(1,0.1,0.1)
	eye.light_energy = 2.5
	eye.omni_range = 6
	eye.position = Vector3(8.5,5.9,-4.5)
	add_child(eye)
	var eye_ball := MeshInstance3D.new()
	eye_ball.mesh = SphereMesh.new()
	eye_ball.scale = Vector3(0.18,0.18,0.18)
	eye_ball.position = Vector3(8.5,5.9,-4.5)
	var em := StandardMaterial3D.new()
	em.albedo_color = Color(0.8,0.05,0.05)
	em.emission_enabled = true
	em.emission = Color(1,0.1,0.1)
	em.emission_energy_multiplier = 5.0
	eye_ball.material_override = em
	add_child(eye_ball)
	for cable in [
		[Vector3(4.3,7.8,-2.5), Vector3(0,0,-10), 5.8],
		[Vector3(6.8,7.6,-3.6), Vector3(0,0,12), 5.1],
		[Vector3(10.0,7.2,-4.2), Vector3(0,0,18), 4.8]
	]: _add_cylinder(0.03, cable[2], cable[0], cable[1], 6)
	var floor := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(36, 0.5, 18)
	floor.add_child(floor_shape)
	floor.position = Vector3(0,-0.2,-3)
	add_child(floor)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.position = Vector3(-9.8, 0.8, 0.8)
	add_child(player)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.2
	cs.shape = cap
	player.add_child(cs)
	var actor := Node3D.new()
	player.add_child(actor)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.04,0.04,0.05)
	black.roughness = 1.0
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7,1.0,0.28)
	body.mesh = bm
	body.position = Vector3(0,0.95,0)
	body.material_override = black
	actor.add_child(body)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	head.mesh = sm
	head.position = Vector3(0,1.58,0.02)
	head.material_override = black
	actor.add_child(head)
	follow_pivot = Node3D.new()
	player.add_child(follow_pivot)
	follow_pivot.position = Vector3(0,1.4,0)
	cam = Camera3D.new()
	cam.current = true
	cam.position = Vector3(0.0, 2.2, 12.5)
	follow_pivot.add_child(cam)

func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	info_label = Label.new()
	info_label.text = "WASD move  |  Mouse look  |  Click capture mouse  |  ESC release"
	info_label.position = Vector2(20, 680)
	canvas.add_child(info_label)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_captured:
		hero_yaw -= event.relative.x * 0.0035
		hero_pitch = clamp(hero_pitch - event.relative.y * 0.0025, -0.4, 0.25)
	if event is InputEventMouseButton and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		mouse_captured = true
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		mouse_captured = false

func _physics_process(delta: float) -> void:
	var move := Input.get_vector("move_left","move_right","move_forward","move_back")
	var basis := Basis(Vector3.UP, hero_yaw)
	var dir := basis * Vector3(move.x, 0, move.y)
	player.velocity.x = dir.x * move_speed
	player.velocity.z = dir.z * move_speed
	if not player.is_on_floor(): player.velocity.y -= gravity * delta
	else: player.velocity.y = 0.0
	player.move_and_slide()
	if dir.length() > 0.1: player.rotation.y = lerp_angle(player.rotation.y, atan2(dir.x, dir.z), delta * 8.0)
	follow_pivot.rotation = Vector3(hero_pitch, hero_yaw, 0)
	cam.position = Vector3(0.0, 2.2, 12.5)
	cam.look_at(player.global_transform.origin + Vector3(0,1.6,-6.5), Vector3.UP)

func _process(_delta: float) -> void:
	_update_projector_uniforms()

func _update_projector_uniforms() -> void:
	var proj: Projection = projector_cam.get_camera_projection()
	var view: Transform3D = projector_cam.global_transform.affine_inverse()
	project_material.set_shader_parameter("projector_matrix", proj * Projection(view))
