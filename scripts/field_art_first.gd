extends Node2D

const ART_FILENAME := "A2_05_Maintenance_Zone.png"
const WALK_SPEED_NEAR := 245.0
const WALK_SPEED_FAR := 115.0
const TOP_Y := 282.0
const BOTTOM_Y := 786.0

var walkmesh := PackedVector2Array([
    Vector2(118, 282), Vector2(315, 282), Vector2(355, 405), Vector2(424, 552),
    Vector2(505, 594), Vector2(744, 602), Vector2(792, 650), Vector2(742, 704),
    Vector2(535, 704), Vector2(411, 746), Vector2(252, 786), Vector2(116, 760)
])

var player_pos := Vector2(344, 650)
var player_facing := 1.0
var show_walkmesh := false
var message_timer := 0.0

var interactions := [
    {"pos": Vector2(176, 367), "radius": 58.0, "prompt": "ENTER MAINTENANCE CORRIDOR", "message": "The corridor continues into the Megastructure."},
    {"pos": Vector2(682, 645), "radius": 72.0, "prompt": "LOOK INTO THE ABYSS", "message": "No bottom. Only more structure."}
]

@onready var background: Sprite2D = $Background
@onready var player: Node2D = $Player
@onready var prompt_label: Label = $UI/Prompt
@onready var message_label: Label = $UI/Message
@onready var debug_label: Label = $UI/Debug

func _ready() -> void:
    _ensure_input_actions()
    if "--smoke-test" in OS.get_cmdline_user_args():
        print("STRATA_SMOKE_READY")
        get_tree().quit()
        return
    _load_external_art()
    _update_player_visual()
    queue_redraw()

func _load_external_art() -> void:
    var exe_dir: String = OS.get_executable_path().get_base_dir()
    var candidate_paths: Array[String] = [
        exe_dir.path_join(ART_FILENAME),
        exe_dir.path_join("art").path_join(ART_FILENAME),
        ProjectSettings.globalize_path("res://").path_join(ART_FILENAME)
    ]
    for p: String in candidate_paths:
        if FileAccess.file_exists(p):
            var image := Image.new()
            var err := image.load(p)
            if err == OK:
                background.texture = ImageTexture.create_from_image(image)
                return
    message_label.text = "Missing artwork file: " + ART_FILENAME

func _ensure_input_actions() -> void:
    _bind_keys(&"move_left", [KEY_A, KEY_LEFT])
    _bind_keys(&"move_right", [KEY_D, KEY_RIGHT])
    _bind_keys(&"move_up", [KEY_W, KEY_UP])
    _bind_keys(&"move_down", [KEY_S, KEY_DOWN])
    _bind_keys(&"interact", [KEY_E, KEY_SPACE])
    _bind_keys(&"debug_walkmesh", [KEY_F1])

func _bind_keys(action: StringName, keys: Array) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    if InputMap.action_get_events(action).size() > 0:
        return
    for keycode in keys:
        var ev := InputEventKey.new()
        ev.physical_keycode = keycode
        InputMap.action_add_event(action, ev)

func _process(delta: float) -> void:
    if Input.is_action_just_pressed("debug_walkmesh"):
        show_walkmesh = not show_walkmesh
        debug_label.visible = show_walkmesh
        queue_redraw()
    _move_player(delta)
    _update_interaction()
    if message_timer > 0.0:
        message_timer -= delta
        if message_timer <= 0.0:
            message_label.text = ""

func _move_player(delta: float) -> void:
    var input_vec: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if input_vec.length_squared() < 0.001:
        return
    if abs(input_vec.x) > 0.05:
        player_facing = sign(input_vec.x)

    var depth_t: float = clamp((player_pos.y - TOP_Y) / (BOTTOM_Y - TOP_Y), 0.0, 1.0)
    var speed: float = lerp(WALK_SPEED_FAR, WALK_SPEED_NEAR, depth_t)
    var candidate: Vector2 = player_pos + input_vec.normalized() * speed * delta

    if Geometry2D.is_point_in_polygon(candidate, walkmesh):
        player_pos = candidate
    else:
        var x_only: Vector2 = Vector2(candidate.x, player_pos.y)
        var y_only: Vector2 = Vector2(player_pos.x, candidate.y)
        if Geometry2D.is_point_in_polygon(x_only, walkmesh):
            player_pos = x_only
        elif Geometry2D.is_point_in_polygon(y_only, walkmesh):
            player_pos = y_only

    _update_player_visual()

func _update_player_visual() -> void:
    player.position = player_pos
    var depth_t: float = clamp((player_pos.y - TOP_Y) / (BOTTOM_Y - TOP_Y), 0.0, 1.0)
    var s: float = lerp(0.42, 1.08, depth_t)
    player.scale = Vector2(s * player_facing, s)
    player.z_index = int(player_pos.y)

func _update_interaction() -> void:
    var nearest: Dictionary = {}
    var nearest_distance: float = INF
    for item: Dictionary in interactions:
        var d: float = player_pos.distance_to(item.pos)
        if d <= float(item.radius) and d < nearest_distance:
            nearest = item
            nearest_distance = d

    if nearest.is_empty():
        prompt_label.text = ""
        return

    prompt_label.text = "E  " + str(nearest.prompt)
    if Input.is_action_just_pressed("interact"):
        message_label.text = str(nearest.message)
        message_timer = 3.5

func _draw() -> void:
    if not show_walkmesh:
        return
    draw_colored_polygon(walkmesh, Color(1.0, 0.1, 0.1, 0.12))
    var closed := PackedVector2Array(walkmesh)
    closed.append(walkmesh[0])
    draw_polyline(closed, Color(1.0, 0.18, 0.18, 0.92), 3.0, true)
    for item: Dictionary in interactions:
        draw_circle(item.pos, float(item.radius), Color(1.0, 0.1, 0.1, 0.10))
        draw_circle(item.pos, 7.0, Color(1.0, 0.2, 0.2, 0.95))
