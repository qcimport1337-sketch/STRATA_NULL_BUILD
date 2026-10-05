extends Control

const INTERNAL_SIZE := Vector2i(480, 270)
const WORLD_SEED := 59017831

var viewport: SubViewport
var world: Node3D
var player: StrataPlayer
var camera_rig: StrataCameraRig
var camera: Camera3D
var hud: Label
var status: Label
var debug_label: Label
var debug_visible := false
var status_time := 0.0
var current_segment := 0
var view_quadrant := 0
var rotation_lock := false
var wipe: ColorRect

func _ready() -> void:
    print("STRATA_BOOT_BEGIN")
    _build_render_pipeline()
    _build_world()
    _build_ui()
    Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
    print("STRATA_SMOKE_READY")
    show_status("STRATA // NULL  PLATFORM-3D PROTOTYPE", 2.5)

func _build_render_pipeline() -> void:
    var bg := ColorRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0.94,0.94,0.91,1.0)
    add_child(bg)

    var container := SubViewportContainer.new()
    container.name = "LowResContainer"
    container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    container.stretch = true
    container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(container)

    viewport = SubViewport.new()
    viewport.name = "PixelWorld"
    viewport.size = INTERNAL_SIZE
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.msaa_3d = Viewport.MSAA_DISABLED
    viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
    viewport.transparent_bg = false
    container.add_child(viewport)

    world = Node3D.new()
    world.name = "World"
    viewport.add_child(world)

func _mat(c: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.roughness = 1.0
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return m

func _box(name_: String, pos: Vector3, size: Vector3, color: Color, collision := true, parent: Node = null) -> Node3D:
    var root: Node3D
    if collision:
        root = StaticBody3D.new()
        root.collision_layer = 1
        root.collision_mask = 1
    else:
        root = Node3D.new()
    root.name = name_
    root.position = pos
    (parent if parent != null else world).add_child(root)

    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    mesh.material_override = _mat(color)
    root.add_child(mesh)

    if collision:
        var cs := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        cs.shape = shape
        root.add_child(cs)
    return root

func _build_world() -> void:
    var env_node := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.88,0.88,0.84)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.82,0.82,0.78)
    env.ambient_light_energy = 0.80
    env_node.environment = env
    world.add_child(env_node)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-45,-35,0)
    sun.light_energy = 0.85
    sun.shadow_enabled = false
    world.add_child(sun)

    # SEGMENT A: classic side-view platforming along world X.
    _box("A_Floor", Vector3(0,-0.30,-2.5), Vector3(22,0.6,10.0), Color(0.08,0.08,0.085))
    _box("A_Platform1", Vector3(-4.0,1.3,0), Vector3(3.4,0.35,2.6), Color(0.16,0.16,0.16))
    _box("A_Platform2", Vector3(1.0,2.4,0), Vector3(3.1,0.35,2.6), Color(0.20,0.20,0.19))
    _box("A_Platform3", Vector3(5.4,1.1,0), Vector3(2.8,0.35,2.6), Color(0.13,0.13,0.135))

    # Huge distant masses, physically behind the platform plane.
    _box("A_BackMass1", Vector3(-5,4.5,-12), Vector3(8,10,5), Color(0.20,0.20,0.19), false)
    _box("A_BackMass2", Vector3(5,6.0,-18), Vector3(10,14,6), Color(0.12,0.12,0.12), false)
    for i in range(7):
        _box("A_BackRib%d" % i, Vector3(-8.0 + i*2.8,4.0,-7.0), Vector3(0.18,8.0,0.18), Color(0.015,0.015,0.017), false)

    # Corner landing where the path physically turns 90 degrees in 3D.
    _box("Corner", Vector3(10.5,0.0,-5.0), Vector3(7.0,0.45,11.0), Color(0.10,0.10,0.105))

    # SEGMENT B: same 2D platformer controls, but now the local plane runs along world -Z.
    _box("B_Floor", Vector3(10.5,-0.30,-12.0), Vector3(8.0,0.6,20.0), Color(0.075,0.075,0.08))
    _box("B_Platform1", Vector3(10.5,1.4,-8.0), Vector3(2.7,0.35,3.0), Color(0.18,0.18,0.18))
    _box("B_Platform2", Vector3(10.5,2.6,-13.0), Vector3(2.7,0.35,3.0), Color(0.22,0.22,0.21))
    _box("B_Platform3", Vector3(10.5,1.2,-18.0), Vector3(2.7,0.35,3.0), Color(0.14,0.14,0.145))
    _box("B_RedGate", Vector3(10.5,1.5,-21.0), Vector3(2.2,3.0,0.4), Color(0.88,0.02,0.015))

    # Deep architecture visible only after the camera turns with the traversal plane.
    _box("B_BackMass", Vector3(24.0,6.0,-13.0), Vector3(8,15,14), Color(0.16,0.16,0.15), false)
    for i in range(8):
        _box("B_Rib%d" % i, Vector3(17.0,4.0,-3.0-i*2.6), Vector3(0.2,8.0,0.2), Color(0.02,0.02,0.02), false)

    # Player: graphic silhouette, not capsule presentation.
    player = StrataPlayer.new()
    player.name = "Kael"
    player.position = Vector3(-8.0,0.8,0)
    player.collision_layer = 4
    player.collision_mask = 1
    world.add_child(player)

    var pshape := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.30
    capsule.height = 1.65
    pshape.shape = capsule
    pshape.position.y = 0.82
    player.add_child(pshape)

    var body := MeshInstance3D.new()
    var body_box := BoxMesh.new()
    body_box.size = Vector3(0.62,1.18,0.34)
    body.mesh = body_box
    body.position = Vector3(0,0.78,0)
    body.material_override = _mat(Color(0.01,0.01,0.012))
    player.add_child(body)

    var head := MeshInstance3D.new()
    var head_box := BoxMesh.new()
    head_box.size = Vector3(0.52,0.50,0.38)
    head.mesh = head_box
    head.position = Vector3(0,1.62,0)
    head.material_override = _mat(Color(0.72,0.72,0.68))
    player.add_child(head)

    var arm := MeshInstance3D.new()
    var arm_box := BoxMesh.new()
    arm_box.size = Vector3(0.65,0.18,0.18)
    arm.mesh = arm_box
    arm.position = Vector3(0.43,0.93,0)
    arm.material_override = _mat(Color(0.01,0.01,0.012))
    player.add_child(arm)

    camera_rig = StrataCameraRig.new()
    world.add_child(camera_rig)
    camera = camera_rig.setup(player)
    camera_rig.global_position = Vector3(-8,2.2,9.0)
    player.setup(camera,self)
    camera_rig.set_quadrant(0)

func _spawn_enemy(name_: String, pos: Vector3) -> void:
    var enemy = StrataEnemy.new()
    enemy.name = name_
    enemy.position = pos
    enemy.collision_layer = 2
    enemy.collision_mask = 1
    world.add_child(enemy)

    var cs = CollisionShape3D.new()
    var capsule = CapsuleShape3D.new()
    capsule.radius = 0.38
    capsule.height = 1.70
    cs.shape = capsule
    cs.position.y = 0.85
    enemy.add_child(cs)

    var body = MeshInstance3D.new()
    var body_quad = QuadMesh.new()
    body_quad.size = Vector2(0.86,1.42)
    body.mesh = body_quad
    body.position = Vector3(0,0.86,0)
    body.material_override = _billboard_material(Color(0.018,0.018,0.020))
    enemy.add_child(body)

    var eye = MeshInstance3D.new()
    var eye_quad = QuadMesh.new()
    eye_quad.size = Vector2(0.48,0.10)
    eye.mesh = eye_quad
    eye.position = Vector3(0,1.23,-0.02)
    eye.material_override = _billboard_material(Color(0.94,0.015,0.010))
    enemy.add_child(eye)

    enemy.setup(player)
    enemies.append(enemy)

func _build_ui() -> void:
    var ui := CanvasLayer.new()
    ui.layer = 20
    add_child(ui)

    hud = Label.new()
    hud.position = Vector2(18,14)
    hud.text = "STRATA // NULL"
    hud.add_theme_font_size_override("font_size", 18)
    ui.add_child(hud)

    status = Label.new()
    status.set_anchors_preset(Control.PRESET_CENTER_TOP)
    status.position = Vector2(-300,20)
    status.size = Vector2(600,34)
    status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status.add_theme_font_size_override("font_size", 17)
    ui.add_child(status)

    debug_label = Label.new()
    debug_label.position = Vector2(18,44)
    debug_label.add_theme_font_size_override("font_size", 13)
    ui.add_child(debug_label)

    var controls := Label.new()
    controls.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    controls.position = Vector2(18,-38)
    controls.text = "WASD MOVE IN 3D    Q / E ROTATE VIEW    SHIFT RUN    SPACE JUMP    F6 DEBUG"
    controls.add_theme_font_size_override("font_size", 14)
    ui.add_child(controls)

    wipe = ColorRect.new()
    wipe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    wipe.color = Color(0.01,0.01,0.012,0.0)
    wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(wipe)

func _process(delta: float) -> void:
    gle_cooldown = maxf(0.0, gle_cooldown - delta)
    _update_crosshair()
    if status_time > 0.0:
        status_time -= delta
        if status_time <= 0.0:
            status.text = ""

    _handle_view_rotation()

    debug_label.visible = debug_visible
    if debug_visible and player != null:
        debug_label.text = "FPS %d\nSEGMENT %d\nWORLD XYZ %.1f %.1f %.1f" % [
            Engine.get_frames_per_second(),
            current_segment + 1,
            player.global_position.x,
            player.global_position.y,
            player.global_position.z
        ]
    if Input.is_action_just_pressed("toggle_debug"):
        debug_visible = not debug_visible

func _handle_view_rotation() -> void:
    if rotation_lock:
        return
    if Input.is_action_just_pressed("rotate_left"):
        _request_rotation(-1)
    elif Input.is_action_just_pressed("rotate_right"):
        _request_rotation(1)

func _request_rotation(direction: int) -> void:
    rotation_lock = true
    view_quadrant = posmod(view_quadrant + direction, 4)
    wipe.color.a = 1.0
    camera_rig.set_quadrant(view_quadrant)
    var tangent := camera_rig.plane_tangent
    show_status("VIEW %s  //  Q/E ROTATE" % _view_name(), 0.9)
    var tween := create_tween()
    tween.tween_property(wipe, "color:a", 0.0, 0.16)
    tween.finished.connect(func(): rotation_lock = false)

func _view_name() -> String:
    match view_quadrant:
        0: return "EAST"
        1: return "NORTH"
        2: return "WEST"
        _: return "SOUTH"

func on_player_plane_changed(_tangent: Vector3) -> void:
    pass

func show_status(text_: String, seconds := 1.0) -> void:
    status.text = text_
    status_time = seconds

func fire_gle() -> void:
    show_status("GLE // LATER PLATFORM PASS", 0.6)

func try_interact() -> void:
    show_status("INTERACTION // LATER PLATFORM PASS", 0.6)

func flash_damage() -> void:
    pass

func quick_save() -> void:
    var data := {
        "world_seed": WORLD_SEED,
        "segment": current_segment,
        "view_quadrant": view_quadrant,
        "player": player.serialize()
    }
    show_status("SAVE // WRITTEN" if SaveService.save_game(data) else "SAVE // FAILED",1.0)

func quick_load() -> void:
    var data := SaveService.load_game()
    if data.is_empty():
        show_status("LOAD // NO SAVE",1.0)
        return
    current_segment = int(data.get("segment",0))
    view_quadrant = int(data.get("view_quadrant",0))
    player.restore(data.get("player",{}))
    camera_rig.set_quadrant(view_quadrant)
    show_status("LOAD // RESTORED",1.0)func _add_crosshair_piece(pos: Vector2, size_: Vector2) -> void:
    var piece = ColorRect.new()
    piece.position = pos
    piece.size = size_
    piece.color = Color(0.90,0.02,0.015,0.95)
    piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
    crosshair.add_child(piece)
    crosshair_parts.append(piece)

func _update_crosshair() -> void:
    if crosshair == null:
        return
    var screen_size = get_viewport_rect().size
    var p = get_viewport().get_mouse_position()
    p.x = clampf(p.x, 14.0, screen_size.x - 14.0)
    p.y = clampf(p.y, 14.0, screen_size.y - 14.0)
    crosshair.position = p - crosshair.size * 0.5
    var locked = _enemy_under_crosshair() != null
    var col = Color(1.0,0.02,0.01,1.0) if locked else Color(0.90,0.02,0.015,0.95)
    for piece in crosshair_parts:
        piece.color = col

func _crosshair_internal_position() -> Vector2:
    var screen_size = get_viewport_rect().size
    if screen_size.x <= 0.0 or screen_size.y <= 0.0:
        return Vector2(240,135)
    var p = get_viewport().get_mouse_position()
    return Vector2(p.x / screen_size.x * 480.0, p.y / screen_size.y * 270.0)

func _enemy_under_crosshair():
    if camera == null or player == null:
        return null
    var cursor = _crosshair_internal_position()
    var best = null
    var best_dist = 99999.0
    for enemy in enemies:
        if not is_instance_valid(enemy) or enemy.health <= 0 or not enemy.visible:
            continue
        var target_pos = enemy.global_position + Vector3(0,0.95,0)
        var screen_pos = camera.unproject_position(target_pos)
        var dist = screen_pos.distance_to(cursor)
        if dist > 18.0 or dist >= best_dist:
            continue
        var query = PhysicsRayQueryParameters3D.create(player.global_position + Vector3(0,1.0,0), target_pos)
        query.collision_mask = 3
        query.exclude = [player.get_rid()]
        var hit = viewport.world_3d.direct_space_state.intersect_ray(query)
        if not hit.is_empty() and hit.get("collider") == enemy:
            best = enemy
            best_dist = dist
    return best

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        fire_gle()
        return
    if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
        if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        else:
            Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
        return
    if rotation_locked:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.physical_keycode == KEY_Q:
            _rotate_view(-1)
        elif event.physical_keycode == KEY_E:
            _rotate_view(1)


