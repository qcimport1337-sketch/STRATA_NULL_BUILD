extends Control

const INTERNAL_SIZE := Vector2i(640, 360)
const WORLD_SEED := 59017831

var viewport: SubViewport
var world: Node3D
var player: StrataPlayer
var camera_rig: StrataCameraRig
var camera: Camera3D
var hud: Label
var status: Label
var debug_label: Label
var boot_label: Label
var debug_visible := true
var status_time := 0.0

func _ready() -> void:
    print("STRATA_BOOT_BEGIN")
    _build_boot_ui()
    _build_render_pipeline()
    _build_world_safe()
    _build_ui()
    boot_label.visible = false
    print("STRATA_SMOKE_READY")
    show_status("STRATA // NULL  0.2.1 SAFE FOUNDATION", 3.0)

func _build_boot_ui() -> void:
    var bg := ColorRect.new()
    bg.name = "BootBackground"
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0.035, 0.035, 0.04, 1.0)
    add_child(bg)

    boot_label = Label.new()
    boot_label.name = "BootLabel"
    boot_label.set_anchors_preset(Control.PRESET_CENTER)
    boot_label.position = Vector2(-240, -35)
    boot_label.size = Vector2(480, 70)
    boot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    boot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    boot_label.text = "STRATA // NULL\nINITIALIZING SAFE WORLD..."
    boot_label.add_theme_font_size_override("font_size", 22)
    add_child(boot_label)

func _build_render_pipeline() -> void:
    var container := SubViewportContainer.new()
    container.name = "LowResContainer"
    container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    container.stretch = true
    container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(container)
    move_child(container, 1)

    viewport = SubViewport.new()
    viewport.name = "LowResWorld"
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
    return m

func _box(name_: String, pos: Vector3, size: Vector3, color: Color, collision := true) -> Node3D:
    var root: Node3D
    if collision:
        root = StaticBody3D.new()
        root.collision_layer = 1
        root.collision_mask = 1
    else:
        root = Node3D.new()
    root.name = name_
    root.position = pos
    world.add_child(root)

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

func _build_world_safe() -> void:
    var env_node := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.82, 0.82, 0.79)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.72, 0.72, 0.70)
    env.ambient_light_energy = 0.72
    env_node.environment = env
    world.add_child(env_node)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
    sun.light_energy = 1.0
    sun.shadow_enabled = false
    world.add_child(sun)

    _box("Floor", Vector3(0, -0.3, -7), Vector3(12, 0.6, 28), Color(0.09,0.09,0.095))
    _box("LeftWall", Vector3(-6.0, 3.0, -7), Vector3(0.5, 6.6, 28), Color(0.15,0.15,0.155))
    _box("RightWall", Vector3(6.0, 3.0, -7), Vector3(0.5, 6.6, 28), Color(0.15,0.15,0.155))

    for i in range(9):
        var z := 4.0 - float(i) * 3.0
        _box("RibL_%d" % i, Vector3(-5.3, 3.7, z), Vector3(0.22, 7.4, 0.25), Color(0.015,0.015,0.018), false)
        _box("RibR_%d" % i, Vector3(5.3, 3.7, z), Vector3(0.22, 7.4, 0.25), Color(0.015,0.015,0.018), false)
        _box("RibTop_%d" % i, Vector3(0, 7.25, z), Vector3(10.8, 0.18, 0.25), Color(0.015,0.015,0.018), false)

    _box("Bridge", Vector3(0, 0.05, -22.0), Vector3(3.0, 0.35, 8.0), Color(0.11,0.11,0.115))
    _box("FarMass", Vector3(0, 6.0, -33.0), Vector3(18.0, 13.0, 6.0), Color(0.20,0.20,0.195))
    _box("RedMarker", Vector3(3.2, 1.3, -15.5), Vector3(1.4, 2.6, 0.35), Color(0.82,0.025,0.018))

    for i in range(8):
        var x := -4.0 + float(i) * 1.15
        _box("Pipe_%d" % i, Vector3(x, 5.3, -12.0), Vector3(0.13, 0.13, 17.0), Color(0.035,0.035,0.038), false)

    player = StrataPlayer.new()
    player.name = "Kael"
    player.position = Vector3(0, 0.8, 4.5)
    player.collision_layer = 4
    player.collision_mask = 1
    world.add_child(player)

    var pshape := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.34
    capsule.height = 1.65
    pshape.shape = capsule
    pshape.position.y = 0.82
    player.add_child(pshape)

    var visual := MeshInstance3D.new()
    var capmesh := CapsuleMesh.new()
    capmesh.radius = 0.34
    capmesh.height = 1.65
    visual.mesh = capmesh
    visual.position.y = 0.82
    visual.material_override = _mat(Color(0.01,0.01,0.012))
    player.add_child(visual)

    var head := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.24
    sphere.height = 0.48
    head.mesh = sphere
    head.position = Vector3(0,1.75,0)
    head.material_override = _mat(Color(0.73,0.73,0.70))
    player.add_child(head)

    camera_rig = StrataCameraRig.new()
    camera_rig.name = "CameraRig"
    world.add_child(camera_rig)
    camera = camera_rig.setup(player)
    camera_rig.global_position = player.global_position + Vector3(0, 1.4, 0)
    player.setup(camera, self)

func _build_ui() -> void:
    var ui := CanvasLayer.new()
    ui.layer = 20
    add_child(ui)

    hud = Label.new()
    hud.position = Vector2(24, 20)
    hud.text = "STRATA // NULL"
    hud.add_theme_font_size_override("font_size", 20)
    ui.add_child(hud)

    status = Label.new()
    status.set_anchors_preset(Control.PRESET_CENTER_TOP)
    status.position = Vector2(-300, 26)
    status.size = Vector2(600, 38)
    status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status.add_theme_font_size_override("font_size", 18)
    ui.add_child(status)

    debug_label = Label.new()
    debug_label.position = Vector2(24, 52)
    debug_label.add_theme_font_size_override("font_size", 14)
    ui.add_child(debug_label)

    var controls := Label.new()
    controls.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    controls.position = Vector2(24,-42)
    controls.text = "WASD MOVE   SHIFT RUN   SPACE JUMP   ESC RELEASE MOUSE"
    controls.add_theme_font_size_override("font_size", 14)
    ui.add_child(controls)

func _process(delta: float) -> void:
    if status_time > 0.0:
        status_time -= delta
        if status_time <= 0.0:
            status.text = ""

    if player != null:
        debug_label.visible = debug_visible
        if debug_visible:
            debug_label.text = "FPS %d\nPOS %.1f  %.1f  %.1f\nHP %d\nSAFE RENDER PATH" % [
                Engine.get_frames_per_second(),
                player.global_position.x,
                player.global_position.y,
                player.global_position.z,
                player.health
            ]
    if Input.is_action_just_pressed("toggle_debug"):
        debug_visible = not debug_visible

func show_status(text_: String, seconds := 1.0) -> void:
    status.text = text_
    status_time = seconds

func fire_gle() -> void:
    show_status("GLE // SAFE TEST", 0.6)

func try_interact() -> void:
    show_status("INTERACTION // SAFE TEST", 0.6)

func flash_damage() -> void:
    pass

func quick_save() -> void:
    var data := {"world_seed": WORLD_SEED, "player": player.serialize()}
    show_status("SAVE // WRITTEN" if SaveService.save_game(data) else "SAVE // FAILED", 1.0)

func quick_load() -> void:
    var data := SaveService.load_game()
    if data.is_empty():
        show_status("LOAD // NO SAVE", 1.0)
        return
    player.restore(data.get("player", {}))
    show_status("LOAD // RESTORED", 1.0)
