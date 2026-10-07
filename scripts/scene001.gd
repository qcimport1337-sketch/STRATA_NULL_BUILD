extends Node3D

const W := 1040.0
const H := 580.0
const START_POS := Vector3(-4.65, 0.0, 4.15)
const SENTINEL_POS := Vector3(2.8, 0.0, -2.7)
const MOVE_SPEED := 3.6
const TURN_SPEED := 10.0
const MOUSE_SENS := 0.0020
const YAW_LIMIT := deg_to_rad(13.0)
const PITCH_LIMIT := deg_to_rad(6.0)

var actor: CharacterBody3D
var actor_visual: Node3D
var camera: Camera3D
var bg_rect: TextureRect
var bg_mat: ShaderMaterial
var yaw := 0.0
var pitch := 0.0
var walk_phase := 0.0
var moving := false
var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var coat_left: Node3D
var coat_right: Node3D
var sword: Node3D
var model_root: Node3D
var audit_mode := false
var audit_name := ""
var initialized := false

func _ready() -> void:
    _ensure_inputs()
    for a in OS.get_cmdline_user_args():
        if a == "--smoke-test":
            print("STRATA_SMOKE_READY")
            get_tree().quit()
            return
        if a.begins_with("--audit-shot="):
            audit_mode = true
            audit_name = a.get_slice("=", 1)
    _build_background()
    _build_world()
    initialized = true
    if audit_mode:
        if "forward" in audit_name: actor.position = START_POS + Vector3(1.1,0,-1.8)
        elif "right" in audit_name: actor.position = START_POS + Vector3(2.2,0,-0.7)
        elif "hero" in audit_name: actor.position = START_POS
        _update_camera(true)
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color(0,0,0,1)
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color(0.12,0.12,0.13,1)
    e.ambient_light_energy = 0.25
    env.environment = e
    add_child(env)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    if audit_mode:
        await get_tree().process_frame
        await get_tree().process_frame
        await get_tree().create_timer(0.25).timeout
        var img := get_viewport().get_texture().get_image()
        img.save_png(ProjectSettings.globalize_path("res://" + audit_name + ".png"))
        get_tree().quit()

func _ensure_inputs() -> void:
    _bind(&"move_left", [KEY_A, KEY_LEFT])
    _bind(&"move_right", [KEY_D, KEY_RIGHT])
    _bind(&"move_forward", [KEY_W, KEY_UP])
    _bind(&"move_back", [KEY_S, KEY_DOWN])
    _bind(&"hero_recenter", [KEY_Q])

func _bind(action: StringName, keys: Array) -> void:
    if not InputMap.has_action(action): InputMap.add_action(action)
    if InputMap.action_get_events(action).size() > 0: return
    for code in keys:
        var ev := InputEventKey.new()
        ev.physical_keycode = code
        InputMap.action_add_event(action, ev)

func _asset_texture(filename: String) -> Texture2D:
    var external := OS.get_executable_path().get_base_dir().path_join("assets").path_join(filename)
    if FileAccess.file_exists(external):
        var im := Image.new()
        if im.load(external) == OK:
            return ImageTexture.create_from_image(im)
    return load("res://assets/" + filename)

func _build_background() -> void:
    var sprite := Sprite3D.new()
    sprite.texture = _asset_texture("scene001_bg_patch.png")
    sprite.pixel_size = 0.0520
    sprite.position = Vector3(0.5, 5.0, -18.0)
    sprite.shaded = false
    sprite.double_sided = true
    add_child(sprite)

func _build_world() -> void:
    actor = CharacterBody3D.new()
    actor.name = "Protagonist"
    actor.position = START_POS
    add_child(actor)
    var cs := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.33
    cap.height = 1.72
    cs.shape = cap
    cs.position.y = 0.86
    actor.add_child(cs)
    model_root = Node3D.new()
    model_root.name = "MangaCharacter3D"
    actor.add_child(model_root)
    _build_character_model()
    model_root.scale = Vector3(0.82,0.82,0.82)

    camera = Camera3D.new()
    camera.fov = 48.0
    camera.current = true
    add_child(camera)
    _update_camera(true)

func _mat(color: Color, unshaded := true) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 0.95
    m.metallic = 0.0
    if unshaded:
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return m

func _outline_mat() -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(0.42,0.43,0.46,1)
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.cull_mode = BaseMaterial3D.CULL_FRONT
    return m

func _mesh_part(parent: Node3D, mesh: Mesh, pos: Vector3, scale_v: Vector3, color: Color, outline := true) -> MeshInstance3D:
    if outline:
        var o := MeshInstance3D.new()
        o.mesh = mesh
        o.position = pos
        o.scale = scale_v * 1.025
        o.material_override = _outline_mat()
        parent.add_child(o)
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.position = pos
    mi.scale = scale_v
    mi.material_override = _mat(color)
    parent.add_child(mi)
    return mi

func _build_character_model() -> void:
    var dark := Color(0.018,0.020,0.024,1)
    var cloth := Color(0.035,0.040,0.047,1)
    var edge := Color(0.11,0.12,0.13,1)

    var hips := Node3D.new(); hips.position.y = 0.92; model_root.add_child(hips)
    var torso_mesh := BoxMesh.new(); torso_mesh.size = Vector3(0.34,0.68,0.22)
    _mesh_part(hips, torso_mesh, Vector3(0,0.42,0), Vector3.ONE, cloth)

    var chest_mesh := BoxMesh.new(); chest_mesh.size = Vector3(0.48,0.40,0.25)
    _mesh_part(hips, chest_mesh, Vector3(0,0.75,-0.01), Vector3.ONE, edge)

    var head_mesh := SphereMesh.new(); head_mesh.radius = 0.145; head_mesh.height = 0.29
    _mesh_part(hips, head_mesh, Vector3(0,1.19,0), Vector3(1.0,0.92,0.96), dark)

    var hood := BoxMesh.new(); hood.size = Vector3(0.54,0.16,0.30)
    _mesh_part(hips, hood, Vector3(0,0.95,0.02), Vector3.ONE, dark)

    var pack := BoxMesh.new(); pack.size = Vector3(0.38,0.50,0.17)
    _mesh_part(hips, pack, Vector3(0,0.58,0.23), Vector3.ONE, Color(0.025,0.028,0.032,1))

    left_leg = Node3D.new(); left_leg.position = Vector3(-0.16,0.91,0); model_root.add_child(left_leg)
    right_leg = Node3D.new(); right_leg.position = Vector3(0.16,0.91,0); model_root.add_child(right_leg)
    var limb := CapsuleMesh.new(); limb.radius = 0.075; limb.height = 0.86
    _mesh_part(left_leg, limb, Vector3(0,-0.38,0), Vector3(0.85,1,0.85), dark)
    _mesh_part(right_leg, limb, Vector3(0,-0.38,0), Vector3(0.85,1,0.85), dark)
    var boot := BoxMesh.new(); boot.size = Vector3(0.20,0.18,0.34)
    _mesh_part(left_leg, boot, Vector3(0,-0.80,-0.07), Vector3.ONE, dark)
    _mesh_part(right_leg, boot, Vector3(0,-0.80,-0.07), Vector3.ONE, dark)

    left_arm = Node3D.new(); left_arm.position = Vector3(-0.34,1.54,0); model_root.add_child(left_arm)
    right_arm = Node3D.new(); right_arm.position = Vector3(0.34,1.54,0); model_root.add_child(right_arm)
    var arm := CapsuleMesh.new(); arm.radius = 0.060; arm.height = 0.68
    _mesh_part(left_arm, arm, Vector3(0,-0.30,0), Vector3(0.86,1,0.86), dark)
    _mesh_part(right_arm, arm, Vector3(0,-0.30,0), Vector3(0.86,1,0.86), dark)

    coat_left = Node3D.new(); coat_left.position = Vector3(-0.16,1.18,0.14); model_root.add_child(coat_left)
    coat_right = Node3D.new(); coat_right.position = Vector3(0.16,1.18,0.14); model_root.add_child(coat_right)
    var coat := PrismMesh.new(); coat.size = Vector3(0.42,1.06,0.10); coat.left_to_right = 0.22
    _mesh_part(coat_left, coat, Vector3(0,-0.60,0), Vector3.ONE, dark)
    _mesh_part(coat_right, coat, Vector3(0,-0.60,0), Vector3(-1,1,1), dark)

    sword = Node3D.new(); sword.position = Vector3(0.30,1.58,0.27); sword.rotation_degrees = Vector3(12,0,-18); model_root.add_child(sword)
    var blade := BoxMesh.new(); blade.size = Vector3(0.055,0.92,0.045)
    _mesh_part(sword, blade, Vector3(0,-0.35,0), Vector3.ONE, Color(0.04,0.045,0.05,1))

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        yaw = clamp(yaw - event.relative.x*MOUSE_SENS, -YAW_LIMIT, YAW_LIMIT)
        pitch = clamp(pitch - event.relative.y*MOUSE_SENS, -PITCH_LIMIT, PITCH_LIMIT)
    elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    elif event is InputEventMouseButton and event.pressed:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
    if not initialized: return
    if Input.is_action_pressed("hero_recenter"):
        yaw = lerp(yaw,0.0,min(1.0,delta*7.0))
        pitch = lerp(pitch,0.0,min(1.0,delta*7.0))
    var iv := Input.get_vector("move_left","move_right","move_forward","move_back")
    var forward := Vector3(0,0,-1).rotated(Vector3.UP,yaw*0.35)
    var right := Vector3(1,0,0).rotated(Vector3.UP,yaw*0.35)
    var dir := right*iv.x + forward*-iv.y
    moving = dir.length_squared() > 0.001
    if moving:
        dir = dir.normalized()
        var candidate := actor.position + dir*MOVE_SPEED*delta
        if _walkable(candidate):
            actor.position = candidate
        var desired_yaw := atan2(dir.x,dir.z) + PI
        model_root.rotation.y = lerp_angle(model_root.rotation.y,desired_yaw,min(1.0,TURN_SPEED*delta))
        walk_phase += delta*8.0
    else:
        walk_phase += delta*2.0
    _animate_character(delta)
    _update_camera(false)

func _animate_character(delta: float) -> void:
    var amp := 0.58 if moving else 0.035
    var swing := sin(walk_phase)*amp
    left_leg.rotation.x = swing
    right_leg.rotation.x = -swing
    left_arm.rotation.x = -swing*0.65
    right_arm.rotation.x = swing*0.65
    var coat_sway := sin(walk_phase+0.9)*(0.10 if moving else 0.025)
    coat_left.rotation.x = -0.10 + coat_sway
    coat_right.rotation.x = -0.12 - coat_sway*0.8
    coat_left.rotation.z = -0.06 + sin(walk_phase*0.53)*0.025
    coat_right.rotation.z = 0.06 - sin(walk_phase*0.47)*0.025
    model_root.position.y = abs(sin(walk_phase))*0.035 if moving else sin(walk_phase)*0.006

func _walkable(p: Vector3) -> bool:
    if p.x < -7.1 or p.x > 7.0 or p.z < -6.7 or p.z > 6.0: return false
    if p.x > -0.65 and p.x < 4.70 and p.z > 1.00 and p.z < 5.75: return false
    for c in [Vector2(-4.5,-1.2),Vector2(-0.3,-1.55),Vector2(4.85,-1.25)]:
        if Vector2(p.x,p.z).distance_to(c) < 0.86: return false
    if Vector2(p.x,p.z).distance_to(Vector2(SENTINEL_POS.x,SENTINEL_POS.z)) < 1.10: return false
    return true

func _update_camera(force_now: bool) -> void:
    var orbit := Vector3(2.55,2.72,6.65).rotated(Vector3.UP,yaw)
    orbit.y += pitch*2.5
    var desired := actor.position + orbit
    var look_player := actor.position + Vector3(0,1.15,0)
    var look_sentinel := SENTINEL_POS + Vector3(0,2.3,0)
    var target := look_player.lerp(look_sentinel,0.34)
    if force_now: camera.position = desired
    else: camera.position = camera.position.lerp(desired,0.13)
    camera.look_at(target,Vector3.UP)
