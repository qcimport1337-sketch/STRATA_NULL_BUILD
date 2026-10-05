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
var combat_ui: CanvasLayer
var crosshair: Control
var beam: Line2D
var enemies: Array = []
var mouse_fire_was_down := false
var gle_cooldown := 0.0
var combat_smoke_mode := false

func _ready() -> void:
    print("STRATA_BOOT_BEGIN")
    _build_render_pipeline()
    _build_world()
    _build_ui()
    _build_combat_test()
    combat_smoke_mode = "--combat-smoke" in OS.get_cmdline_user_args()
    print("STRATA_SMOKE_READY")
    show_status("STRATA // NULL  GLE TESTED BUILD", 2.5)
    if combat_smoke_mode:
        call_deferred("_run_combat_smoke")

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

func _billboard_material(c: Color) -> StandardMaterial3D:
    var m := _mat(c)
    m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    return m

func _spawn_test_enemy(name_: String, pos: Vector3) -> StrataEnemy:
    var enemy := StrataEnemy.new()
    enemy.name = name_
    enemy.position = pos
    enemy.collision_layer = 2
    enemy.collision_mask = 1
    world.add_child(enemy)

    var cs := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.38
    shape.height = 1.7
    cs.shape = shape
    cs.position.y = 0.85
    enemy.add_child(cs)

    var body := MeshInstance3D.new()
    var quad := QuadMesh.new()
    quad.size = Vector2(0.85, 1.5)
    body.mesh = quad
    body.position = Vector3(0, 0.85, 0)
    body.material_override = _billboard_material(Color(0.02,0.02,0.025))
    enemy.add_child(body)

    var eye := MeshInstance3D.new()
    var eye_quad := QuadMesh.new()
    eye_quad.size = Vector2(0.42, 0.09)
    eye.mesh = eye_quad
    eye.position = Vector3(0, 1.15, -0.02)
    eye.material_override = _billboard_material(Color(1.0,0.01,0.005))
    enemy.add_child(eye)

    enemy.setup(player)
    enemies.append(enemy)
    return enemy

func _build_combat_test() -> void:
    combat_ui = CanvasLayer.new()
    combat_ui.layer = 30
    add_child(combat_ui)

    beam = Line2D.new()
    beam.width = 8.0
    beam.default_color = Color(1.0,0.01,0.005,0.0)
    beam.antialiased = false
    combat_ui.add_child(beam)

    crosshair = Control.new()
    crosshair.size = Vector2(28,28)
    crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
    combat_ui.add_child(crosshair)

    for rect_data in [
        [Vector2(12,0),Vector2(4,8)],
        [Vector2(12,20),Vector2(4,8)],
        [Vector2(0,12),Vector2(8,4)],
        [Vector2(20,12),Vector2(8,4)],
        [Vector2(12,12),Vector2(4,4)]
    ]:
        var p := ColorRect.new()
        p.position = rect_data[0]
        p.size = rect_data[1]
        p.color = Color(0.9,0.02,0.015,0.95)
        p.mouse_filter = Control.MOUSE_FILTER_IGNORE
        crosshair.add_child(p)

    _spawn_test_enemy("EnemyNear", Vector3(-1.5,0.8,-2.0))
    _spawn_test_enemy("EnemyDeep", Vector3(4.5,0.8,-6.0))
    Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

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
    controls.text = "WASD MOVE    MOUSE AIM    LMB GLE    Q/E ROTATE VIEW    SPACE JUMP"
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

    var mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
    if mouse_down and not mouse_fire_was_down and gle_cooldown <= 0.0:
        fire_gle()
    mouse_fire_was_down = mouse_down

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

func _viewport_to_internal(p: Vector2) -> Vector2:
    var size := get_viewport_rect().size
    if size.x <= 1.0 or size.y <= 1.0:
        return Vector2(INTERNAL_SIZE) * 0.5
    return Vector2(
        p.x / size.x * float(INTERNAL_SIZE.x),
        p.y / size.y * float(INTERNAL_SIZE.y)
    )

func _internal_to_viewport(p: Vector2) -> Vector2:
    var size := get_viewport_rect().size
    return Vector2(
        p.x / float(INTERNAL_SIZE.x) * size.x,
        p.y / float(INTERNAL_SIZE.y) * size.y
    )

func _update_crosshair() -> void:
    if crosshair == null:
        return
    var size := get_viewport_rect().size
    var p := get_viewport().get_mouse_position()
    p.x = clampf(p.x, 14.0, maxf(14.0,size.x-14.0))
    p.y = clampf(p.y, 14.0, maxf(14.0,size.y-14.0))
    crosshair.position = p - Vector2(14,14)

func _enemy_at_crosshair():
    if camera == null:
        return null
    var cursor := _viewport_to_internal(get_viewport().get_mouse_position())
    var best = null
    var best_dist := 24.0
    for enemy in enemies:
        if not is_instance_valid(enemy):
            continue
        if enemy.health <= 0 or not enemy.visible:
            continue
        var target := enemy.global_position + Vector3(0,0.95,0)
        var screen := camera.unproject_position(target)
        var d := screen.distance_to(cursor)
        if d < best_dist:
            best = enemy
            best_dist = d
    return best

func _draw_gle(from_screen: Vector2, to_screen: Vector2) -> void:
    if beam == null:
        return
    beam.points = PackedVector2Array([from_screen,to_screen])
    beam.default_color = Color(1.0,0.01,0.005,1.0)
    var tween := create_tween()
    tween.tween_property(beam,"default_color:a",0.0,0.16)

func fire_gle(forced_enemy = null) -> void:
    gle_cooldown = 0.22
    var player_internal := camera.unproject_position(player.global_position + Vector3(0,1.0,0))
    var from_screen := _internal_to_viewport(player_internal)
    var target_enemy = forced_enemy if forced_enemy != null else _enemy_at_crosshair()

    if target_enemy != null:
        var hp_before: int = target_enemy.health
        target_enemy.damage(3)
        var enemy_internal := camera.unproject_position(target_enemy.global_position + Vector3(0,0.95,0))
        _draw_gle(from_screen,_internal_to_viewport(enemy_internal))
        print("GLE_HIT hp_before=%d hp_after=%d" % [hp_before,target_enemy.health])
        show_status("GLE // DIRECT HIT",0.4)
        return

    var cursor := get_viewport().get_mouse_position()
    var delta := cursor - from_screen
    if delta.length() < 4.0:
        delta = Vector2.RIGHT
    var angle := atan2(delta.y,delta.x)
    var snapped := round(angle/(PI/4.0))*(PI/4.0)
    var dir := Vector2(cos(snapped),sin(snapped))
    _draw_gle(from_screen,from_screen + dir * 900.0)
    print("GLE_DIRECTIONAL")
    show_status("GLE // DIRECTIONAL",0.3)

func _run_combat_smoke() -> void:
    await get_tree().process_frame
    if enemies.is_empty():
        push_error("COMBAT_SMOKE_FAIL no_enemy")
        get_tree().quit(20)
        return
    var enemy = enemies[0]
    var hp_before: int = enemy.health
    fire_gle(enemy)
    await get_tree().process_frame
    var hp_after: int = enemy.health
    var beam_created := beam != null and beam.points.size() == 2
    if hp_after >= hp_before:
        push_error("COMBAT_SMOKE_FAIL damage hp_before=%d hp_after=%d" % [hp_before,hp_after])
        get_tree().quit(21)
        return
    if not beam_created:
        push_error("COMBAT_SMOKE_FAIL beam_not_created")
        get_tree().quit(22)
        return
    print("COMBAT_SMOKE_PASS hp_before=%d hp_after=%d beam_points=%d" % [hp_before,hp_after,beam.points.size()])
    get_tree().quit(0)

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
    show_status("LOAD // RESTORED",1.0)
