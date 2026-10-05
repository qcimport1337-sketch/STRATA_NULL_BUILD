extends Node3D
class_name StrataCameraRig

var target: Node3D
var camera: Camera3D
var spring: SpringArm3D
var yaw := 0.0
var pitch := -0.18
var sensitivity := 0.0024
var shoulder_offset := 0.55
var follow_height := 1.45
var profile_distance := 4.4
var pitch_min := deg_to_rad(-42.0)
var pitch_max := deg_to_rad(28.0)

func setup(p_target: Node3D) -> Camera3D:
    target = p_target
    spring = SpringArm3D.new()
    spring.spring_length = profile_distance
    spring.margin = 0.12
    spring.collision_mask = 1
    add_child(spring)
    camera = Camera3D.new()
    camera.fov = 62.0
    camera.near = 0.08
    camera.position.x = shoulder_offset
    spring.add_child(camera)
    camera.current = true
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    return camera

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        yaw -= event.relative.x * sensitivity
        pitch = clampf(pitch - event.relative.y * sensitivity, pitch_min, pitch_max)
    elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
    if target == null:
        return
    var desired_pos := target.global_position + Vector3(0, follow_height, 0)
    global_position = global_position.lerp(desired_pos, 1.0 - exp(-14.0 * delta))
    rotation = Vector3(pitch, yaw, 0.0)
