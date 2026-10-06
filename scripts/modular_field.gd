extends Node2D

const W: int = 1672
const H: int = 941
const NEAR_SPEED: float = 245.0
const FAR_SPEED: float = 110.0

const ROUTES: Array[String] = [
    "module_030.png",
    "module_031.png",
    "module_032.png",
    "module_034.png",
    "module_036.png",
    "module_037.png",
    "module_038.png",
    "module_039.png"
]
const VERTICALS: Array[String] = [
    "module_048.png",
    "module_049.png",
    "module_050.png",
    "module_051.png"
]

var rng := RandomNumberGenerator.new()
var texture_cache: Dictionary = {}
var walkmesh := PackedVector2Array()
var interactions: Array[Dictionary] = []
var player_pos := Vector2(220, 790)
var facing: float = 1.0
var top_y: float = 560.0
var bottom_y: float = 840.0
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
    glow_a.energy = 0.30 + 0.12 * sin(t * 2.0)
    glow_b.energy = 0.30 + 0.14 * sin(t * 1.6 + 1.0)
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
    for y in range(H):
        var v: float = float(y) / float(H - 1)
        var tone: float = lerp(0.86, 0.54, v)
        img.fill_rect(Rect2i(0, y, W, 1), Color(tone, tone, tone, 1.0))
    var x: int = -80
    while x < W + 80:
        var tw: int = rng.randi_range(70, 160)
        var th: int = rng.randi_range(290, 760)
        var top: int = H - th - rng.randi_range(10, 120)
        var shade: float = rng.randf_range(0.42, 0.66)
        img.fill_rect(Rect2i(x, top, tw, th), Color(shade, shade, shade, 0.55))
        var inset: int = rng.randi_range(14, 28)
        img.fill_rect(Rect2i(x + inset, top, 3, th), Color(0.82, 0.82, 0.82, 0.25))
        img.fill_rect(Rect2i(x + tw - inset, top, 2, th), Color(0.22, 0.22, 0.24, 0.22))
        x += tw + rng.randi_range(45, 120)
    for i in range(rng.randi_range(3, 6)):
        var by: int = rng.randi_range(180, 620)
        var bh: int = rng.randi_range(8, 18)
        img.fill_rect(Rect2i(0, by, W, bh), Color(0.36, 0.36, 0.39, 0.34))
        for bx in range(rng.randi_range(0, 140), W, rng.randi_range(170, 260)):
            img.fill_rect(Rect2i(bx, by - 18, 3, 35), Color(0.28, 0.28, 0.30, 0.25))
    for y in range(250, 720):
        var k: float = 1.0 - abs((float(y) - 485.0) / 235.0)
        if k > 0.0:
            var alpha: float = 0.20 * k
            img.fill_rect(Rect2i(0, y, W, 1), Color(0.96, 0.96, 0.96, alpha))
    generated_bg.texture = ImageTexture.create_from_image(img)

func _grammar_abyss_crossing() -> void:
    _add_module(far_modules, _pick(VERTICALS), Vector2(355, 390), 0.72, false, -50, 0.56)
    _add_module(far_modules, _pick(VERTICALS), Vector2(1190, 350), 0.78, rng.randf() > 0.5, -49, 0.58)
    _add_module(mid_modules, _pick(ROUTES), Vector2(880, 420), 0.70, rng.randf() > 0.5, -8, 0.72)
    _add_module(play_modules, "module_030.png", Vector2(450, 675), 0.90, false, 600, 0.95)
    _add_module(play_modules, _pick(["module_031.png", "module_037.png", "module_036.png"]), Vector2(1270, 630), 0.80, true, 610, 0.95)
    _add_module(foreground_modules, "module_048.png", Vector2(50, 590), 1.10, false, 2200, 0.78)
    walkmesh = PackedVector2Array([
        Vector2(90, 795), Vector2(85, 665), Vector2(340, 630), Vector2(690, 646),
        Vector2(1000, 642), Vector2(1370, 604), Vector2(1610, 620), Vector2(1620, 910), Vector2(90, 910)
    ])
    player_pos = Vector2(280, 780)
    top_y = 600.0; bottom_y = 850.0
    interactions = [
        {"pos": Vector2(1380, 620), "radius": 95.0, "prompt": "CROSS", "message": "A generated route continues into the next chunk."},
        {"pos": Vector2(820, 650), "radius": 80.0, "prompt": "LOOK DOWN", "message": "The generated void has no visible floor."}
    ]
    glow_a.position = Vector2(520, 340); glow_b.position = Vector2(1320, 580)

func _grammar_maintenance_spine() -> void:
    _add_module(far_modules, "module_049.png", Vector2(1100, 320), 0.78, false, -40, 0.54)
    _add_module(far_modules, _pick(["module_048.png", "module_051.png"]), Vector2(470, 350), 0.70, true, -38, 0.52)
    _add_module(mid_modules, "module_039.png", Vector2(1020, 430), 0.66, false, -5, 0.68)
    _add_module(play_modules, "module_038.png", Vector2(560, 680), 0.95, false, 620, 0.98)
    _add_module(play_modules, "module_037.png", Vector2(1330, 590), 0.88, true, 625, 0.98)
    _add_module(foreground_modules, "module_051.png", Vector2(80, 515), 1.25, false, 2200, 0.72)
    walkmesh = PackedVector2Array([
        Vector2(50, 840), Vector2(55, 690), Vector2(350, 632), Vector2(790, 640),
        Vector2(1130, 610), Vector2(1530, 565), Vector2(1620, 605), Vector2(1620, 920), Vector2(50, 920)
    ])
    player_pos = Vector2(330, 790)
    top_y = 555.0; bottom_y = 850.0
    interactions = [
        {"pos": Vector2(1420, 585), "radius": 90.0, "prompt": "SERVICE DOOR", "message": "The maintenance branch is generated from compatible modules."}
    ]
    glow_a.position = Vector2(405, 520); glow_b.position = Vector2(1390, 550)

func _grammar_vertical_loop() -> void:
    _add_module(far_modules, "module_048.png", Vector2(820, 340), 0.96, false, -42, 0.62)
    _add_module(far_modules, "module_049.png", Vector2(1310, 330), 0.72, false, -40, 0.50)
    _add_module(mid_modules, "module_032.png", Vector2(990, 460), 0.64, true, -4, 0.72)
    _add_module(play_modules, "module_036.png", Vector2(560, 690), 0.88, false, 620, 0.98)
    _add_module(play_modules, "module_037.png", Vector2(1260, 620), 0.84, false, 630, 0.98)
    _add_module(foreground_modules, "module_034.png", Vector2(80, 665), 1.18, false, 2200, 0.76)
    walkmesh = PackedVector2Array([
        Vector2(120, 850), Vector2(110, 730), Vector2(390, 688), Vector2(650, 640),
        Vector2(920, 605), Vector2(1160, 610), Vector2(1490, 600), Vector2(1600, 660), Vector2(1600, 920), Vector2(120, 920)
    ])
    player_pos = Vector2(260, 810)
    top_y = 590.0; bottom_y = 860.0
    interactions = [
        {"pos": Vector2(1240, 620), "radius": 100.0, "prompt": "LIFT LANDING", "message": "Vertical sockets would connect the next generated elevation."}
    ]
    glow_a.position = Vector2(830, 330); glow_b.position = Vector2(1260, 600)

func _pick(arr: Array[String]) -> String:
    return arr[rng.randi_range(0, arr.size() - 1)]

func _add_module(parent: Node2D, filename: String, pos: Vector2, scale_value: float, flip_x: bool, z: int, opacity: float) -> void:
    var tex: Texture2D = _load_module_texture(filename)
    var sprite := Sprite2D.new()
    sprite.texture = tex
    sprite.position = pos
    sprite.scale = Vector2((-scale_value if flip_x else scale_value), scale_value)
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
        img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
        img.fill(Color(0.8, 0.1, 0.1, 0.7))
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
        if Geometry2D.is_point_in_polygon(xo, walkmesh): player_pos = xo
        elif Geometry2D.is_point_in_polygon(yo, walkmesh): player_pos = yo
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
    draw_colored_polygon(walkmesh, Color(1, 0.08, 0.08, 0.10))
    var closed := PackedVector2Array(walkmesh)
    closed.append(walkmesh[0])
    draw_polyline(closed, Color(1, 0.2, 0.2, 0.9), 2.5, true)
