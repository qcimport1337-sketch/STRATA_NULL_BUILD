extends Control

const INTERNAL_SIZE := Vector2i(640, 360)
const WORLD_SEED := 59017831

var viewport: SubViewport
var world: Node3D
var player: StrataPlayer
var camera_rig: StrataCameraRig
var camera: Camera3D
var enemy: StrataEnemy
var panel: StrataDestructible
var terminal: StrataTerminal
var hud: Label
var prompt: Label
var status: Label
var debug_label: Label
var damage_flash: ColorRect
var debug_visible := true
var status_time := 0.0
var beam_time := 0.0
var beam_mesh: MeshInstance3D
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.seed = WORLD_SEED
    _build_render_pipeline()
    _build_world()
    _build_ui()
    show_status("AWAKEN // STRATA 00", 2.5)

func _build_render_pipeline() -> void:
    viewport = SubViewport.new()
    viewport.name = "LowResWorld"
    viewport.size = INTERNAL_SIZE
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.msaa_3d = Viewport.MSAA_DISABLED
    viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
    viewport.use_occlusion_culling = true
    add_child(viewport)

    world = Node3D.new()
    world.name = "World"
    viewport.add_child(world)

    var display := TextureRect.new()
    display.name = "SpatialMangaDisplay"
    display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    display.texture = viewport.get_texture()
    display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    var shader := load("res://shaders/spatial_manga.gdshader") as Shader
    var mat := ShaderMaterial.new()
    mat.shader = shader
    display.material = mat
    add_child(display)

func _material(color: Color, roughness := 0.92) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    return m

func _box(parent: Node, name_: String, pos: Vector3, size: Vector3, color: Color, collision := true) -> Node3D:
    var root: Node3D
    if collision:
        root = StaticBody3D.new()
        root.collision_layer = 1
        root.collision_mask = 1
    else:
        root = Node3D.new()
    root.name = name_
    root.position = pos
    parent.add_child(root)
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    mesh.material_override = _material(color)
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
    env.background_color = Color(0.78, 0.79, 0.78)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.72, 0.74, 0.75)
    env.ambient_light_energy = 0.58
    env.fog_enabled = true
    env.fog_light_color = Color(0.72, 0.74, 0.74)
    env.fog_density = 0.018
    env.fog_height = 2.0
    env.fog_height_density = 0.04
    env_node.environment = env
    world.add_child(env_node)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52, -28, 0)
    sun.light_energy = 1.15
    sun.light_color = Color(0.94, 0.95, 0.96)
    sun.shadow_enabled = true
    world.add_child(sun)

    _box(world, "AlcoveFloor", Vector3(0,-0.25,5.5), Vector3(5.4,0.5,5.0), Color(0.11,0.115,0.12))
    _box(world, "AlcoveLeft", Vector3(-2.7,1.8,5.5), Vector3(0.35,4.1,5.0), Color(0.18,0.19,0.20))
    _box(world, "AlcoveRight", Vector3(2.7,1.8,5.5), Vector3(0.35,4.1,5.0), Color(0.18,0.19,0.20))
    _box(world, "AlcoveRoof", Vector3(0,3.9,5.5), Vector3(5.7,0.35,5.0), Color(0.14,0.145,0.15))
    _box(world, "Vestibule", Vector3(0,-0.25,1.0), Vector3(4.2,0.5,4.0), Color(0.13,0.135,0.14))
    _box(world, "MainPlatform", Vector3(0,-0.30,-9.5), Vector3(12.0,0.6,17.0), Color(0.09,0.095,0.10))
    _box(world, "LeftMass", Vector3(-7.4,4.0,-10), Vector3(3.0,9.0,20.0), Color(0.16,0.17,0.18))
    _box(world, "RightMass", Vector3(7.4,4.0,-10), Vector3(3.0,9.0,20.0), Color(0.16,0.17,0.18))

    for i in range(8):
        var z := -2.0 - float(i) * 3.0
        _box(world, "RibL_%d" % i, Vector3(-5.8,3.6,z), Vector3(0.22,7.2,0.22), Color(0.035,0.038,0.04), false)
        _box(world, "RibR_%d" % i, Vector3(5.8,3.6,z), Vector3(0.22,7.2,0.22), Color(0.035,0.038,0.04), false)
        _box(world, "RibTop_%d" % i, Vector3(0,7.1,z), Vector3(11.8,0.18,0.24), Color(0.035,0.038,0.04), false)

    _box(world, "SideFloor", Vector3(6.0,0.20,-5.5), Vector3(4.0,0.4,5.0), Color(0.18,0.18,0.18))
    terminal = StrataTerminal.new()
    terminal.name = "TraceTerminal"
    terminal.position = Vector3(5.7,0.9,-6.7)
    terminal.collision_layer = 1
    world.add_child(terminal)
    var tm := MeshInstance3D.new()
    var tbox := BoxMesh.new()
    tbox.size = Vector3(0.8,1.5,0.55)
    tm.mesh = tbox
    tm.material_override = _material(Color(0.35,0.36,0.36))
    terminal.add_child(tm)
    var tcs := CollisionShape3D.new()
    var tsh := BoxShape3D.new()
    tsh.size = Vector3(0.8,1.5,0.55)
    tcs.shape = tsh
    terminal.add_child(tcs)

    for i in range(10):
        _box(world, "Step_%02d" % i, Vector3(-4.3,0.15 + i*0.30,-5.0 - i*0.42), Vector3(2.0,0.30,0.65), Color(0.20,0.20,0.20))
    _box(world, "UpperCatwalk", Vector3(-4.3,3.0,-12.0), Vector3(2.2,0.35,8.0), Color(0.16,0.16,0.17))

    var elevator := StrataElevator.new()
    elevator.name = "FreightElevator"
    elevator.position = Vector3(4.4,0.15,-13.0)
    elevator.collision_layer = 1
    world.add_child(elevator)
    var em := MeshInstance3D.new()
    var ebox := BoxMesh.new()
    ebox.size = Vector3(2.8,0.35,2.8)
    em.mesh = ebox
    em.material_override = _material(Color(0.22,0.22,0.23))
    elevator.add_child(em)
    var ecs := CollisionShape3D.new()
    var esh := BoxShape3D.new()
    esh.size = Vector3(2.8,0.35,2.8)
    ecs.shape = esh
    elevator.add_child(ecs)

    panel = StrataDestructible.new()
    panel.name = "GLEPanel"
    panel.position = Vector3(0,1.6,-19.0)
    panel.collision_layer = 1
    world.add_child(panel)
    var pm := MeshInstance3D.new()
    var pbox := BoxMesh.new()
    pbox.size = Vector3(4.0,3.2,0.35)
    pm.mesh = pbox
    pm.material_override = _material(Color(0.52,0.04,0.035))
    panel.add_child(pm)
    var pcs := CollisionShape3D.new()
    var psh := BoxShape3D.new()
    psh.size = Vector3(4.0,3.2,0.35)
    pcs.shape = psh
    panel.add_child(pcs)

    _box(world, "Bridge", Vector3(0,0.0,-23.0), Vector3(3.2,0.35,8.0), Color(0.10,0.105,0.11))
    _build_seeded_connector(Vector3(0,0,-28.0))

    player = StrataPlayer.new()
    player.name = "Kael"
    player.position = Vector3(0,0.8,6.5)
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
    visual.material_override = _material(Color(0.035,0.035,0.04))
    player.add_child(visual)
    var gle := MeshInstance3D.new()
    var gbox := BoxMesh.new()
    gbox.size = Vector3(0.12,0.12,0.65)
    gle.mesh = gbox
    gle.position = Vector3(0.32,1.05,-0.23)
    gle.material_override = _material(Color(0.75,0.03,0.02),0.35)
    player.add_child(gle)

    camera_rig = StrataCameraRig.new()
    camera_rig.name = "CameraRig"
    world.add_child(camera_rig)
    camera = camera_rig.setup(player)
    camera_rig.global_position = player.global_position + Vector3(0,1.5,0)
    player.setup(camera, self)

    enemy = StrataEnemy.new()
    enemy.name = "Safeguard"
    enemy.position = Vector3(2.7,0.7,-13.8)
    enemy.collision_layer = 2
    enemy.collision_mask = 1
    world.add_child(enemy)
    var es := CollisionShape3D.new()
    var ecaps := CapsuleShape3D.new()
    ecaps.radius = 0.42
    ecaps.height = 1.8
    es.shape = ecaps
    es.position.y = 0.9
    enemy.add_child(es)
    var ev := MeshInstance3D.new()
    var ec := CapsuleMesh.new()
    ec.radius = 0.42
    ec.height = 1.8
    ev.mesh = ec
    ev.position.y = 0.9
    ev.material_override = _material(Color(0.08,0.08,0.085))
    enemy.add_child(ev)
    var eye := MeshInstance3D.new()
    var eye_box := BoxMesh.new()
    eye_box.size = Vector3(0.55,0.10,0.12)
    eye.mesh = eye_box
    eye.position = Vector3(0,1.35,-0.38)
    eye.material_override = _material(Color(0.85,0.02,0.01),0.2)
    enemy.add_child(eye)
    enemy.setup(player)

func _build_seeded_connector(start: Vector3) -> void:
    var z := start.z
    var x := start.x
    for i in range(7):
        x += rng.randf_range(-1.15, 1.15)
        var width := rng.randf_range(2.4, 3.5)
        var length := rng.randf_range(3.0, 4.6)
        _box(world, "Generated_%02d" % i, Vector3(x,0.0,z-length*0.5), Vector3(width,0.35,length), Color(0.12 + i*0.006,0.125 + i*0.006,0.13 + i*0.006))
        z -= length

func _build_ui() -> void:
    var ui := CanvasLayer.new()
    ui.layer = 20
    add_child(ui)
    hud = Label.new()
    hud.position = Vector2(24,22)
    hud.add_theme_font_size_override("font_size", 20)
    hud.text = "STRATA // NULL"
    ui.add_child(hud)
    prompt = Label.new()
    prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    prompt.position = Vector2(-150,-72)
    prompt.size = Vector2(300,32)
    prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    prompt.add_theme_font_size_override("font_size", 18)
    ui.add_child(prompt)
    status = Label.new()
    status.set_anchors_preset(Control.PRESET_CENTER_TOP)
    status.position = Vector2(-300,24)
    status.size = Vector2(600,42)
    status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status.add_theme_font_size_override("font_size", 21)
    ui.add_child(status)
    debug_label = Label.new()
    debug_label.position = Vector2(24,52)
    debug_label.add_theme_font_size_override("font_size", 14)
    ui.add_child(debug_label)
    damage_flash = ColorRect.new()
    damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    damage_flash.color = Color(0.55,0.0,0.0,0.0)
    damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(damage_flash)
    var cross := Label.new()
    cross.set_anchors_preset(Control.PRESET_CENTER)
    cross.position = Vector2(-12,-16)
    cross.text = "+"
    cross.add_theme_font_size_override("font_size", 24)
    ui.add_child(cross)

func _process(delta: float) -> void:
    if status_time > 0.0:
        status_time -= delta
        if status_time <= 0.0:
            status.text = ""
    if beam_time > 0.0:
        beam_time -= delta
        if beam_time <= 0.0 and is_instance_valid(beam_mesh):
            beam_mesh.queue_free()
            beam_mesh = null
    if damage_flash.color.a > 0.0:
        damage_flash.color.a = move_toward(damage_flash.color.a, 0.0, delta * 2.6)
    _update_prompt()
    if debug_visible and player != null:
        debug_label.visible = true
        debug_label.text = "FPS %d\nSEED %d\nPOS %.1f  %.1f  %.1f\nHP %d\nENEMY %s\nF5 SAVE   F9 LOAD   F6 DEBUG" % [Engine.get_frames_per_second(), WORLD_SEED, player.global_position.x, player.global_position.y, player.global_position.z, player.health, ("ALIVE" if enemy != null and enemy.health > 0 else "DOWN")]
    else:
        debug_label.visible = false
    if Input.is_action_just_pressed("toggle_debug"):
        debug_visible = not debug_visible
    if Input.is_action_just_pressed("pause") and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _update_prompt() -> void:
    prompt.text = ""
    var hit := _center_ray(2.6)
    if hit.is_empty():
        return
    var collider = hit.get("collider")
    if collider is StrataTerminal:
        prompt.text = collider.get_prompt()

func _center_ray(length: float = 60.0) -> Dictionary:
    if camera == null:
        return {}
    var from := camera.global_position
    var to := from + -camera.global_transform.basis.z * length
    var q := PhysicsRayQueryParameters3D.create(from, to)
    q.collision_mask = 1 | 2
    q.exclude = [player.get_rid()]
    return viewport.world_3d.direct_space_state.intersect_ray(q)

func fire_gle() -> void:
    var from := camera.global_position + -camera.global_transform.basis.z * 0.35
    var end := from + -camera.global_transform.basis.z * 60.0
    var hit := _center_ray(60.0)
    if not hit.is_empty():
        end = hit.position
        var collider = hit.collider
        if collider is StrataEnemy:
            collider.damage(1)
            show_status("GLE // IMPACT", 0.55)
        elif collider is StrataDestructible:
            collider.damage(1)
            show_status("STRUCTURAL STATE // BREACHED", 1.5)
    _spawn_beam(from, end)

func _spawn_beam(from: Vector3, to: Vector3) -> void:
    if is_instance_valid(beam_mesh):
        beam_mesh.queue_free()
    beam_mesh = MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.035
    cylinder.bottom_radius = 0.035
    cylinder.height = from.distance_to(to)
    beam_mesh.mesh = cylinder
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(1.0,0.015,0.005)
    mat.emission_enabled = true
    mat.emission = Color(1.0,0.0,0.0)
    mat.emission_energy_multiplier = 4.0
    beam_mesh.material_override = mat
    world.add_child(beam_mesh)
    beam_mesh.global_position = (from + to) * 0.5
    beam_mesh.look_at(to, Vector3.UP)
    beam_mesh.rotate_object_local(Vector3.RIGHT, PI * 0.5)
    beam_time = 0.085

func try_interact() -> void:
    var hit := _center_ray(2.6)
    if hit.is_empty():
        return
    var collider = hit.collider
    if collider is StrataTerminal:
        collider.interact(self)

func show_status(text_: String, seconds := 1.0) -> void:
    status.text = text_
    status_time = seconds

func flash_damage() -> void:
    damage_flash.color.a = 0.22

func quick_save() -> void:
    var data := {
        "world_seed": WORLD_SEED,
        "player": player.serialize(),
        "panel_breached": panel.breached,
        "terminal_read": terminal.read,
        "enemy": enemy.serialize()
    }
    show_status("SAVE // WRITTEN" if SaveService.save_game(data) else "SAVE // FAILED", 1.2)

func quick_load() -> void:
    var data := SaveService.load_game()
    if data.is_empty():
        show_status("LOAD // NO SAVE", 1.2)
        return
    player.restore(data.get("player", {}))
    panel.set_breached(bool(data.get("panel_breached", false)))
    terminal.read = bool(data.get("terminal_read", false))
    enemy.restore(data.get("enemy", {}))
    show_status("LOAD // RESTORED", 1.2)
