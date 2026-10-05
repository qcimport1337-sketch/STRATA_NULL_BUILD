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
var _fire_cooldown := 0.0

func setup(p_camera: Camera3D, p_game: Node) -> void:
    camera = p_camera
    game = p_game
    spawn_position = global_position

func _physics_process(delta: float) -> void:
    if camera == null:
        return

    _fire_cooldown = maxf(0.0, _fire_cooldown - delta)

    if not is_on_floor():
        velocity.y -= gravity * delta
    elif Input.is_action_just_pressed("jump"):
        velocity.y = jump_velocity

    # Screen-relative 3D movement:
    # A/D = left/right on screen
    # W   = deeper into the world
    # S   = back toward the viewer
    var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

    var cam_right: Vector3 = camera.global_transform.basis.x
    cam_right.y = 0.0
    cam_right = cam_right.normalized()

    var cam_forward: Vector3 = -camera.global_transform.basis.z
    cam_forward.y = 0.0
    cam_forward = cam_forward.normalized()

    var desired_dir: Vector3 = cam_right * input_vec.x + cam_forward * -input_vec.y
    if desired_dir.length_squared() > 1.0:
        desired_dir = desired_dir.normalized()

    var target_speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
    var desired_vel: Vector3 = desired_dir * target_speed
    var accel := acceleration if is_on_floor() else acceleration * air_control_ratio

    velocity.x = move_toward(velocity.x, desired_vel.x, accel * delta)
    velocity.z = move_toward(velocity.z, desired_vel.z, accel * delta)

    if desired_dir.length_squared() > 0.02:
        var target_yaw := atan2(-desired_dir.x, -desired_dir.z)
        rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 12.0, 0.0, 1.0))

    move_and_slide()

    if global_position.y < -18.0:
        reconstruct()

    if Input.is_action_just_pressed("primary_fire") and _fire_cooldown <= 0.0:
        RuntimeLogger.write("LMB_FIRE_ACTION_RECEIVED")
        _fire_cooldown = 0.20
        RuntimeLogger.write("GLE_CALL_BEGIN")
        game.fire_gle()
        RuntimeLogger.write("GLE_CALL_RETURNED")
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
    if game != null:
        game.show_status("RECONSTRUCTED", 1.5)

func serialize() -> Dictionary:
    return {
        "position": [global_position.x, global_position.y, global_position.z],
        "rotation_y": rotation.y,
        "health": health
    }

func restore(data: Dictionary) -> void:
    var p = data.get("position", [])
    if p is Array and p.size() == 3:
        global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
    rotation.y = float(data.get("rotation_y", rotation.y))
    health = int(data.get("health", max_health))
    velocity = Vector3.ZERO
