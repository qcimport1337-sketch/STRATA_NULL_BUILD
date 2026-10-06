extends Node2D

const W: int = 1672
const H: int = 941
const NEAR_SPEED: float = 245.0
const FAR_SPEED: float = 110.0

const ROUTE_LONG: Array[String] = [
    "straight_catwalk.png",
    "split_deck_bridge.png",
    "enclosed_service_bridge.png",
    "maintenance_spine.png",
    "rail_bridge.png",
    "transfer_bridge.png"
]
const ROUTE_NODE: Array[String] = [
    "cantilever_platform.png",
    "balcony_landing.png",
    "ring_landing.png"
]
const ROUTE_SPECIAL: Array[String] = [
    "broken_span.png",
    "suspended_walkway.png",
    "ramp_connector.png",
    "suspended_platform.png"
]
const VERTICALS: Array[String] = [
    "abyss_column.png",
    "elevator_shaft.png",
    "service_riser.png"
]

var rng := RandomNumberGenerator.new()
var texture_cache: Dictionary = {}
var walkmesh := PackedVector2Array()
var interactions: Array[Dictionary] = []
var player_pos := Vector2(250, 790)
var facing: float = 1.0
var top_y: float = 560.0
var bottom_y: float = 850.0
var show_debug: bool = false
var msg_timer: float = 0.0
var seed_value: int = 0
var grammar_name: String = ""

@onready var generated_bg: Sprite2D = $GeneratedBackground
@onready var far_modules: Node2D = $FarModules
@onready var mid_modules: Node2D = $MidModules
@onready var play_modules: Node2D = $PlayModules
@onready var foreground_modules: Node2D = $ForegroundModules
@onready var player: Node2D = $Player
@onready var seed_label: Label = $UI/SeedLabel
@onready var prompt: Label = $UI/Prompt
@onready var message: Label = $UI/Message
@onready var debug_label: Label = $UI/Debug
@onready var glow_a: PointLight2D = $FX/GlowA
@onready var glow_b: PointLight2D = $FX/GlowB

func _ready() -> void:
    _bind(&"move_left", [KEY_A, KEY_LEFT])
    _bind(&"move_right", [KEY_D, KEY_RIGHT])
    _bind(&"move_up", [KEY_W, KEY_UP])
    _bind(&"move_down", [KEY_S, KEY_DOWN])
    _bind(&"interact", [KEY_E, KEY_SPACE])
    _bind(&"regen", [KEY_R])
    _bind(&"debug_mesh", [KEY_F1])
    if "--smoke-test" in OS.get_cmdline_user_args():
        print("STRATA_SMOKE_READY")
        get_tree().quit()
        return
    _generate_scene()

func _bind(action: StringName, keys: Array) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    if InputMap.action_get_events(action).size() > 0:
        return
    for code in keys:
        var ev := InputEventKey.new()
        ev.physical_keycode = code
        InputMap.action_add_event(action, ev)

func _process(delta: float) -> void:
    if Input.is_action_just_pressed("regen"):
        _generate_scene()
        return
    if Input.is_action_just_pressed("debug_mesh"):
        show_debug = not show_debug
        debug_label.visible = show_debug
        queue_redraw()

    _move_player(delta)
    _update_interaction()

    var t: float = float(Time.get_ticks_msec()) / 1000.0
    glow_a.energy = 0.28 + 0.11 * sin(t * 2.1)
    glow_b.energy = 0.30 + 0.12 * sin(t * 1.6 + 1.0)

    if msg_timer > 0.0:
        msg_timer -= delta
        if msg_timer <= 0.0:
            message.text = "R regenerate   WASD move   E interact   F1 walkmesh"

func _generate_scene() -> void:
    rng.randomize()
    seed_value = int(rng.randi())

    _clear_modules(far_modules)
    _clear_modules(mid_modules)
    _clear_modules(play_modules)
    _clear_modules(foreground_modules)
    _make_procedural_background()

    var choice: int = rng.randi_range(0, 2)
    if choice == 0:
        grammar_name = "ABYSS CROSSING"
        _grammar_abyss_crossing()
    elif choice == 1:
        grammar_name = "MAINTENANCE SPINE"
        _grammar_maintenance_spine()
    else:
        grammar_name = "VERTICAL LOOP"
        _grammar_vertical_loop()

    _dress_far_layer()
    _dress_foreground()
    seed_label.text = "Seed %d   %s" % [seed_value, grammar_name]
    prompt.text = ""
    message.text = "R regenerate   WASD move   E interact   F1 walkmesh"
    _update_player_visual()
    queue_redraw()

func _clear_modules(parent: Node2D) -> void:
    for child in parent.get_children():
        child.queue_free()

func _make_procedural_background() -> void:
    var img: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)

    # Pale fog field rather than a flat slab.
    for y in range(H):
        var v: float = float(y) / float(H - 1)
        var tone: float = lerp(0.93, 0.72, v)
        img.fill_rect(Rect2i(0, y, W, 1), Color(tone, tone, tone, 1.0))

    # Distant megastructure columns.
    var x: int = rng.randi_range(-80, 10)
    while x < W:
        var tw: int = rng.randi_range(54, 128)
        var th: int = rng.randi_range(330, 780)
        var top: int = H - th - rng.randi_range(0, 100)
        var shade: float = rng.randf_range(0.45, 0.68)
        img.fill_rect(Rect2i(x, top, tw, th), Color(shade, shade, shade, 0.34))

        # vertical ribs
        var rib_step: int = rng.randi_range(17, 31)
        var rx: int = x + rng.randi_range(6, 14)
        while rx < x + tw:
            img.fill_rect(Rect2i(rx, top, 2, th), Color(0.20, 0.20, 0.22, 0.13))
            rx += rib_step

        # service slots
        var slot_y: int = top + rng.randi_range(30, 70)
        while slot_y < H - 60:
            if rng.randf() < 0.52:
                img.fill_rect(Rect2i(x + 8, slot_y, maxi(6, tw - 16), 3), Color(0.82, 0.82, 0.82, 0.17))
            slot_y += rng.randi_range(55, 115)

        x += tw + rng.randi_range(28, 92)

    # Distant route bands.
    var bridge_count: int = rng.randi_range(4, 7)
    for i in range(bridge_count):
        var by: int = rng.randi_range(160, 650)
        var bh: int = rng.randi_range(5, 13)
        var alpha: float = rng.randf_range(0.16, 0.30)
        img.fill_rect(Rect2i(0, by, W, bh), Color(0.24, 0.24, 0.27, alpha))
        var support_x: int = rng.randi_range(20, 160)
        var support_step: int = rng.randi_range(150, 260)
        while support_x < W:
            img.fill_rect(Rect2i(support_x, by - 28, 2, 48), Color(0.24, 0.24, 0.27, alpha * 0.85))
            support_x += support_step

    # Thin cable arcs.
    for i in range(rng.randi_range(5, 10)):
        var x0: int = rng.randi_range(-100, W - 200)
        var x1: int = x0 + rng.randi_range(220, 520)
        var y0: int = rng.randi_range(80, 430)
        var sag: float = rng.randf_range(18.0, 70.0)
        var prev := Vector2i(x0, y0)
        for step in range(1, 80):
            var t: float = float(step) / 79.0
            var xx: int = int(lerp(float(x0), float(x1), t))
            var yy: int = int(float(y0) + sag * 4.0 * t * (1.0 - t))
            _draw_line_image(img, prev, Vector2i(xx, yy), Color(0.16, 0.16, 0.18, 0.16))
            prev = Vector2i(xx, yy)

    # Fog bands erase detail with depth.
    _fog_band(img, 160, 250, 0.10)
    _fog_band(img, 390, 280, 0.13)

    generated_bg.texture = ImageTexture.create_from_image(img)

func _draw_line_image(img: Image, a: Vector2i, b: Vector2i, color: Color) -> void:
    var dx: int = abs(b.x - a.x)
    var sx: int = 1 if a.x < b.x else -1
    var dy: int = -abs(b.y - a.y)
    var sy: int = 1 if a.y < b.y else -1
    var err: int = dx + dy
    var x: int = a.x
    var y: int = a.y
    while true:
        if x >= 0 and x < W and y >= 0 and y < H:
            img.set_pixel(x, y, img.get_pixel(x, y).blend(color))
        if x == b.x and y == b.y:
            break
        var e2: int = 2 * err
        if e2 >= dy:
            err += dy
            x += sx
        if e2 <= dx:
            err += dx
            y += sy

func _fog_band(img: Image, center_y: int, radius: int, strength: float) -> void:
    var y0: int = maxi(0, center_y - radius)
    var y1: int = mini(H - 1, center_y + radius)
    for y in range(y0, y1 + 1):
        var dist: float = abs(float(y - center_y)) / float(radius)
        var a: float = strength * (1.0 - clamp(dist, 0.0, 1.0))
        if a <= 0.0:
            continue
        for x in range(W):
            img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color(0.97, 0.97, 0.97, 1.0), a))

func _grammar_abyss_crossing() -> void:
    # Primary route is built from two separately extracted modules, never a full scene crop.
    _add_module(play_modules, _pick(ROUTE_NODE), Vector2(285, 650), rng.randf_range(0.72, 0.86), false, 620, 1.0, 0.0)
    _add_module(play_modules, _pick(["straight_catwalk.png", "maintenance_spine.png", "split_deck_bridge.png"]), Vector2(690, 630), rng.randf_range(0.74, 0.90), false, 625, 1.0, rng.randf_range(-0.035, 0.035))
    _add_module(play_modules, _pick(ROUTE_NODE), Vector2(1325, 605), rng.randf_range(0.66, 0.82), true, 630, 1.0, 0.0)

    _add_module(mid_modules, _pick(VERTICALS), Vector2(560, 360), rng.randf_range(0.72, 0.92), false, -6, 0.76, 0.0)
    _add_module(mid_modules, _pick(VERTICALS), Vector2(1240, 330), rng.randf_range(0.66, 0.86), true, -5, 0.70, 0.0)
    _add_module(mid_modules, _pick(ROUTE_LONG), Vector2(990, 420), rng.randf_range(0.47, 0.62), rng.randf() > 0.5, -4, 0.48, rng.randf_range(-0.04, 0.04))

    walkmesh = PackedVector2Array([
        Vector2(100, 830), Vector2(105, 692), Vector2(310, 650), Vector2(640, 638),
        Vector2(960, 632), Vector2(1280, 610), Vector2(1570, 630), Vector2(1600, 910), Vector2(100, 910)
    ])
    player_pos = Vector2(240, 795)
    top_y = 605.0
    bottom_y = 855.0
    interactions = [
        {"pos": Vector2(1390, 620), "radius": 90.0, "prompt": "CONTINUE", "message": "The next generated structure lies beyond the landing."},
        {"pos": Vector2(820, 650), "radius": 90.0, "prompt": "LOOK DOWN", "message": "Fog hides the lower levels."}
    ]
    glow_a.position = Vector2(560, 345)
    glow_b.position = Vector2(1360, 590)

func _grammar_maintenance_spine() -> void:
    _add_module(play_modules, "maintenance_spine.png", Vector2(385, 665), rng.randf_range(0.78, 0.94), false, 620, 1.0, rng.randf_range(-0.02, 0.02))
    _add_module(play_modules, _pick(["straight_catwalk.png", "enclosed_service_bridge.png", "transfer_bridge.png"]), Vector2(880, 625), rng.randf_range(0.70, 0.86), false, 625, 1.0, rng.randf_range(-0.025, 0.025))
    _add_module(play_modules, "balcony_landing.png", Vector2(1380, 595), rng.randf_range(0.72, 0.84), true, 630, 1.0, 0.0)

    _add_module(mid_modules, "elevator_shaft.png", Vector2(1140, 330), rng.randf_range(0.72, 0.90), false, -8, 0.70, 0.0)
    _add_module(mid_modules, _pick(["service_riser.png", "abyss_column.png"]), Vector2(560, 350), rng.randf_range(0.62, 0.80), true, -7, 0.62, 0.0)
    _add_module(mid_modules, _pick(ROUTE_LONG), Vector2(1250, 420), rng.randf_range(0.42, 0.58), true, -5, 0.46, 0.0)

    walkmesh = PackedVector2Array([
        Vector2(70, 850), Vector2(75, 700), Vector2(300, 665), Vector2(600, 650),
        Vector2(900, 630), Vector2(1210, 610), Vector2(1540, 600), Vector2(1610, 660), Vector2(1610, 920), Vector2(70, 920)
    ])
    player_pos = Vector2(250, 805)
    top_y = 590.0
    bottom_y = 860.0
    interactions = [
        {"pos": Vector2(1420, 605), "radius": 90.0, "prompt": "SERVICE ACCESS", "message": "A compatible route socket continues deeper into maintenance."}
    ]
    glow_a.position = Vector2(410, 610)
    glow_b.position = Vector2(1400, 570)

func _grammar_vertical_loop() -> void:
    _add_module(play_modules, "ramp_connector.png", Vector2(365, 685), rng.randf_range(0.78, 0.92), false, 620, 1.0, 0.0)
    _add_module(play_modules, _pick(["ring_landing.png", "cantilever_platform.png"]), Vector2(880, 610), rng.randf_range(0.72, 0.86), false, 625, 1.0, 0.0)
    _add_module(play_modules, _pick(["suspended_walkway.png", "straight_catwalk.png"]), Vector2(1330, 565), rng.randf_range(0.66, 0.78), true, 630, 1.0, rng.randf_range(-0.03, 0.03))

    _add_module(mid_modules, "abyss_column.png", Vector2(780, 325), rng.randf_range(0.86, 1.02), false, -8, 0.76, 0.0)
    _add_module(mid_modules, "elevator_shaft.png", Vector2(1310, 300), rng.randf_range(0.60, 0.78), false, -7, 0.60, 0.0)
    _add_module(mid_modules, _pick(ROUTE_LONG), Vector2(1050, 400), rng.randf_range(0.42, 0.55), true, -5, 0.46, 0.0)

    walkmesh = PackedVector2Array([
        Vector2(90, 860), Vector2(100, 735), Vector2(350, 685), Vector2(610, 645),
        Vector2(880, 615), Vector2(1140, 590), Vector2(1470, 565), Vector2(1590, 630), Vector2(1590, 920), Vector2(90, 920)
    ])
    player_pos = Vector2(250, 815)
    top_y = 550.0
    bottom_y = 870.0
    interactions = [
        {"pos": Vector2(880, 620), "radius": 95.0, "prompt": "LIFT NODE", "message": "This landing can connect to another generated elevation."}
    ]
    glow_a.position = Vector2(790, 330)
    glow_b.position = Vector2(1340, 550)

func _dress_far_layer() -> void:
    var count: int = rng.randi_range(3, 6)
    for i in range(count):
        var fname: String = _pick(VERTICALS if rng.randf() < 0.58 else ROUTE_LONG)
        var pos := Vector2(rng.randi_range(120, W - 120), rng.randi_range(210, 520))
        var scale_value: float = rng.randf_range(0.28, 0.48)
        _add_module(far_modules, fname, pos, scale_value, rng.randf() > 0.5, -45 + i, rng.randf_range(0.20, 0.34), rng.randf_range(-0.025, 0.025))

func _dress_foreground() -> void:
    # Only a couple of close masks, kept outside the main path.
    if rng.randf() < 0.65:
        _add_module(foreground_modules, _pick(["service_riser.png", "abyss_column.png"]), Vector2(-25, 575), rng.randf_range(1.0, 1.28), false, 2200, 0.82, 0.0)
    if rng.randf() < 0.45:
        _add_module(foreground_modules, _pick(["service_riser.png", "elevator_shaft.png"]), Vector2(W + 15, 565), rng.randf_range(1.0, 1.24), true, 2200, 0.78, 0.0)

func _pick(arr: Array[String]) -> String:
    return arr[rng.randi_range(0, arr.size() - 1)]

func _add_module(parent: Node2D, filename: String, pos: Vector2, scale_value: float, flip_x: bool, z: int, opacity: float, rotation_value: float) -> void:
    var tex: Texture2D = _load_module_texture(filename)
    var sprite := Sprite2D.new()
    sprite.texture = tex
    sprite.position = pos
    sprite.scale = Vector2((-scale_value if flip_x else scale_value), scale_value)
    sprite.rotation = rotation_value
    sprite.modulate = Color(1.0, 1.0, 1.0, opacity)
    sprite.z_index = z
    parent.add_child(sprite)

func _load_module_texture(filename: String) -> Texture2D:
    if texture_cache.has(filename):
        return texture_cache[filename]

    var path: String = OS.get_executable_path().get_base_dir().path_join("modules").path_join(filename)
    var img := Image.new()
    var err: int = img.load(path)

    if err != OK:
        img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
        img.fill(Color(0.9, 0.05, 0.05, 0.8))

    var tex := ImageTexture.create_from_image(img)
    texture_cache[filename] = tex
    return tex

func _move_player(delta: float) -> void:
    var input_vec: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if input_vec.length_squared() < 0.001:
        return

    if abs(input_vec.x) > 0.05:
        facing = sign(input_vec.x)

    var d: float = clamp((player_pos.y - top_y) / (bottom_y - top_y), 0.0, 1.0)
    var speed: float = lerp(FAR_SPEED, NEAR_SPEED, d)
    var candidate: Vector2 = player_pos + input_vec.normalized() * speed * delta

    if Geometry2D.is_point_in_polygon(candidate, walkmesh):
        player_pos = candidate
    else:
        var xo := Vector2(candidate.x, player_pos.y)
        var yo := Vector2(player_pos.x, candidate.y)
        if Geometry2D.is_point_in_polygon(xo, walkmesh):
            player_pos = xo
        elif Geometry2D.is_point_in_polygon(yo, walkmesh):
            player_pos = yo

    _update_player_visual()

func _update_player_visual() -> void:
    player.position = player_pos
    var d: float = clamp((player_pos.y - top_y) / (bottom_y - top_y), 0.0, 1.0)
    var s: float = lerp(0.38, 1.02, d)
    player.scale = Vector2(s * facing, s)
    player.z_index = int(player_pos.y)

func _update_interaction() -> void:
    var nearest: Dictionary = {}
    var best: float = INF

    for item: Dictionary in interactions:
        var dist: float = player_pos.distance_to(item.pos)
        if dist <= float(item.radius) and dist < best:
            nearest = item
            best = dist

    if nearest.is_empty():
        prompt.text = ""
        return

    prompt.text = "E  " + str(nearest.prompt)
    if Input.is_action_just_pressed("interact"):
        message.text = str(nearest.message)
        msg_timer = 3.0

func _draw() -> void:
    if not show_debug:
        return
    draw_colored_polygon(walkmesh, Color(1.0, 0.08, 0.08, 0.10))
    var closed := PackedVector2Array(walkmesh)
    closed.append(walkmesh[0])
    draw_polyline(closed, Color(1.0, 0.2, 0.2, 0.9), 2.5, true)
