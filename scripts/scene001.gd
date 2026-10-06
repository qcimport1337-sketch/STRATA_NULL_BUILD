extends Node3D

const START_POS := Vector3(-4.85, 0.0, 4.35)
const SENTINEL_POS := Vector3(2.85, 1.75, -2.65)
const YAW_LIMIT := deg_to_rad(12.0)
const PITCH_LIMIT := deg_to_rad(6.0)
const MOVE_SPEED := 3.6
const MOUSE_SENS := 0.0022

var player: CharacterBody3D
var camera: Camera3D
var bg_rect: TextureRect
var bg_mat: ShaderMaterial
var player_visual: TextureRect
var cover_fog: TextureRect
var aim_rect: ColorRect
var yaw := 0.0
var pitch := 0.0

func _ready() -> void:
    _ensure_inputs()
    if "--smoke-test" in OS.get_cmdline_user_args():
        print("STRATA_SMOKE_READY")
        get_tree().quit()
        return
    _build_world()
    _build_background()
    _build_player_visual()
    _build_reticle()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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

func _external_texture(filename: String) -> Texture2D:
    var path: String = OS.get_executable_path().get_base_dir().path_join("assets").path_join(filename)
    var img := Image.new()
    var err: int = img.load(path)
    if err != OK:
        img = Image.create(8,8,false,Image.FORMAT_RGBA8)
        img.fill(Color(0.2,0.2,0.2,1.0))
    return ImageTexture.create_from_image(img)

func _build_world() -> void:
    player = CharacterBody3D.new()
    player.position = START_POS
    add_child(player)
    var shape := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.32
    capsule.height = 1.65
    shape.shape = capsule
    shape.position.y = 0.83
    player.add_child(shape)
    camera = Camera3D.new()
    camera.fov = 54.0
    add_child(camera)
    _update_camera(true)

func _build_background() -> void:
    var layer := CanvasLayer.new()
    layer.layer = -20
    add_child(layer)
    bg_rect = TextureRect.new()
    bg_rect.position = Vector2.ZERO
    bg_rect.size = Vector2(1040,580)
    bg_rect.texture = _external_texture("scene001_source.png")
    bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    layer.add_child(bg_rect)
    var shader := Shader.new()
    shader.code = """shader_type canvas_item;
uniform sampler2D depth_tex : filter_linear;
uniform vec2 view_shift = vec2(0.0);
void fragment(){
    float d = texture(depth_tex, UV).r;
    vec2 centered = UV - vec2(0.5);
    vec2 par = view_shift * mix(0.12, 1.0, d);
    float zscale = 1.0 + view_shift.y * (d - 0.35) * 0.55;
    vec2 suv = centered / zscale + vec2(0.5) + par;
    suv = clamp(suv, vec2(0.002), vec2(0.998));
    COLOR = texture(TEXTURE, suv);
}"""
    bg_mat = ShaderMaterial.new()
    bg_mat.shader = shader
    bg_mat.set_shader_parameter("depth_tex", _external_texture("scene001_depth.png"))
    bg_rect.material = bg_mat
    var fog_layer := CanvasLayer.new()
    fog_layer.layer = -5
    add_child(fog_layer)
    cover_fog = TextureRect.new()
    cover_fog.texture = _external_texture("player_cover_steam.png")
    cover_fog.position = Vector2(170,260)
    cover_fog.size = Vector2(190,235)
    cover_fog.modulate = Color(1,1,1,0.92)
    fog_layer.add_child(cover_fog)

func _build_player_visual() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 10
    add_child(layer)
    player_visual = TextureRect.new()
    player_visual.texture = _external_texture("scene001_player.png")
    player_visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    player_visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    layer.add_child(player_visual)
    _update_player_visual()

func _build_reticle() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 20
    add_child(layer)
    aim_rect = ColorRect.new()
    aim_rect.size = Vector2(6,6)
    aim_rect.position = Vector2(517,287)
    aim_rect.color = Color(1,1,1,0)
    layer.add_child(aim_rect)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        yaw = clamp(yaw - event.relative.x * MOUSE_SENS, -YAW_LIMIT, YAW_LIMIT)
        pitch = clamp(pitch - event.relative.y * MOUSE_SENS, -PITCH_LIMIT, PITCH_LIMIT)
    elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
    if camera == null or player == null: return
    if Input.is_action_pressed("hero_recenter"):
        yaw = lerp(yaw, 0.0, min(1.0, delta*7.0))
        pitch = lerp(pitch, 0.0, min(1.0, delta*7.0))
    var iv := Input.get_vector("move_left","move_right","move_forward","move_back")
    var f := -camera.global_transform.basis.z
    f.y = 0
    f = f.normalized()
    var r := camera.global_transform.basis.x
    r.y = 0
    r = r.normalized()
    var dir := (r*iv.x + f*-iv.y)
    if dir.length_squared() > 0.001:
        dir = dir.normalized()
        var candidate := player.position + dir*MOVE_SPEED*delta
        if _walkable(candidate): player.position = candidate
    _update_camera(false)
    var travel: Vector3 = player.position - START_POS
    bg_mat.set_shader_parameter("view_shift", Vector2(clamp(-travel.x*0.0018+yaw*0.055,-0.019,0.019),clamp(travel.z*0.00085-pitch*0.030,-0.010,0.010)))
    _update_player_visual()
    _update_aim()

func _walkable(p: Vector3) -> bool:
    if p.x < -7.2 or p.x > 7.0 or p.z < -6.8 or p.z > 6.2: return false
    if p.x > -0.55 and p.x < 4.65 and p.z > 1.15 and p.z < 5.9: return false
    for b in [Vector2(-4.5,-1.3),Vector2(-0.35,-1.55),Vector2(4.95,-1.2)]:
        if Vector2(p.x,p.z).distance_to(b) < 0.9: return false
    if Vector2(p.x,p.z).distance_to(Vector2(SENTINEL_POS.x,SENTINEL_POS.z)) < 1.0: return false
    return true

func _update_camera(force_now: bool) -> void:
    var orbit := Vector3(2.05,3.0+pitch*3.2,6.25).rotated(Vector3.UP,yaw)
    var desired := player.position + orbit
    var target := player.position + Vector3(2.8,1.15,-4.4).rotated(Vector3.UP,yaw*0.55)
    if force_now: camera.position = desired
    else: camera.position = camera.position.lerp(desired,0.12)
    camera.look_at(target,Vector3.UP)

func _update_player_visual() -> void:
    if not camera or not player_visual: return
    var screen := camera.unproject_position(player.global_position + Vector3(0,1.15,0))
    var dist: float = camera.global_position.distance_to(player.global_position)
    var sc: float = clamp(7.0/dist,0.70,1.18)
    var size := Vector2(118,205)*sc
    player_visual.size = size
    player_visual.position = screen - Vector2(size.x*0.5,size.y*0.72) + Vector2(-102,-6)

func _update_aim() -> void:
    if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        aim_rect.color = Color(1,1,1,0)
        return
    var dir := -camera.global_transform.basis.z
    var to_target := SENTINEL_POS - camera.global_position
    var angle: float = rad_to_deg(acos(clamp(dir.normalized().dot(to_target.normalized()),-1.0,1.0)))
    aim_rect.color = Color(1,0.05,0.05,0.95) if angle < 4.0 else Color(0.92,0.92,0.92,0.72)
