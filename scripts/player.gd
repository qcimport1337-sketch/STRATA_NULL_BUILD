extends CharacterBody3D
class_name StrataPlayer

@export var walk_speed := 3.4
@export var run_speed := 5.6
@export var acceleration := 24.0
@export var air_control_ratio := 0.28
@export var jump_velocity := 5.6
@export var gravity := 18.0
@export var max_health := 100

var health := 100
var game: Node
var camera: Camera3D
var spawn_position := Vector3.ZERO
var plane_tangent := Vector3.RIGHT
var plane_normal := Vector3.BACK
var plane_anchor := Vector3.ZERO
var _fire_cooldown := 0.0

func setup(p_camera: Camera3D, p_game: Node) -> void:
    camera = p_camera
    game = p_game
    spawn_position = global_position
    set_traversal_plane(Vector3.RIGHT, global_position)

func set_traversal_plane(tangent: Vector3, anchor: Vector3) -> void:
    var t := tangent
    t.y = 0.0
    if t.length_squared() < 0.001:
        return
    plane_tangent = t.normalized()
    plane_normal = Vector3(-plane_tangent.z, 0.0, plane_tangent.x).normalized()
    plane_anchor = anchor
    if game != null and game.has_method("on_player_plane_changed"):
        game.on_player_plane_changed(plane_tangent)

func _physics_process(delta: float) -> void:
    _fire_cooldown = maxf(0.0, _fire_cooldown - delta)

    if not is_on_floor():
        velocity.y -= gravity * delta
    elif Input.is_action_just_pressed("jump"):
        velocity.y = jump_velocity

    var axis := Input.get_axis("move_left", "move_right")
    var target_speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
    var desired_speed := axis * target_speed
    var current_speed := velocity.dot(plane_tangent)
    var accel := acceleration if is_on_floor() else acceleration * air_control_ratio
    var new_speed := move_toward(current_speed, desired_speed, accel * delta)
    var vertical := velocity.y
    velocity = plane_tangent * new_speed
    velocity.y = vertical

    if absf(axis) > 0.05:
        var face_dir: Vector3 = plane_tangent * signf(axis)
        rotation.y = lerp_angle(rotation.y, atan2(-face_dir.x, -face_dir.z), clampf(delta * 12.0, 0.0, 1.0))

    move_and_slide()

    # Keep the player physically on the current local 2D traversal plane.
    var offset := global_position - plane_anchor
    var drift := offset.dot(plane_normal)
    global_position -= plane_normal * drift

    if global_position.y < -18.0:
        reconstruct()

    if Input.is_action_just_pressed("primary_fire") and _fire_cooldown <= 0.0:
        _fire_cooldown = 0.20
        game.fire_gle()
    if Input.is_action_just_pressed("interact"):
        game.try_interact()
    if Input.is_action_just_pressed("quick_save"):
        game.quick_save()
    if Input.is_action_just_pressed("quick_load"):
        game.quick_load()

func take_damage(amount: int) -> void:
    health = maxi(0, health - amount)
    if game != null:
        game.flash_damage()
    if health <= 0:
        reconstruct()

func reconstruct() -> void:
    health = max_health
    global_position = spawn_position
    velocity = Vector3.ZERO
    set_traversal_plane(Vector3.RIGHT, spawn_position)
    if game != null:
        game.show_status("RECONSTRUCTED", 1.5)

func serialize() -> Dictionary:
    return {
        "position": [global_position.x, global_position.y, global_position.z],
        "rotation_y": rotation.y,
        "health": health,
        "plane_tangent": [plane_tangent.x, plane_tangent.y, plane_tangent.z],
        "plane_anchor": [plane_anchor.x, plane_anchor.y, plane_anchor.z]
    }

func restore(data: Dictionary) -> void:
    var p = data.get("position", [])
    if p is Array and p.size() == 3:
        global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
    rotation.y = float(data.get("rotation_y", rotation.y))
    health = int(data.get("health", max_health))
    var t = data.get("plane_tangent", [])
    var a = data.get("plane_anchor", [])
    if t is Array and t.size() == 3 and a is Array and a.size() == 3:
        set_traversal_plane(
            Vector3(float(t[0]), float(t[1]), float(t[2])),
            Vector3(float(a[0]), float(a[1]), float(a[2]))
        )
    velocity = Vector3.ZERO
