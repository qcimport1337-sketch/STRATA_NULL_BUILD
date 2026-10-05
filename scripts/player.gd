extends CharacterBody3D
class_name StrataPlayer

@export var walk_speed := 3.2
@export var run_speed := 5.5
@export var acceleration := 22.0
@export var air_control_ratio := 0.22
@export var jump_velocity := 5.2
@export var gravity := 18.0
@export var max_health := 100

var health := 100
var camera: Camera3D
var game: Node
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

    var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var forward := -camera.global_transform.basis.z
    forward.y = 0.0
    forward = forward.normalized()
    var right := camera.global_transform.basis.x
    right.y = 0.0
    right = right.normalized()
    var desired_dir := (right * input_vec.x + forward * -input_vec.y).normalized()
    var target_speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
    var desired := desired_dir * target_speed
    var accel := acceleration if is_on_floor() else acceleration * air_control_ratio
    velocity.x = move_toward(velocity.x, desired.x, accel * delta)
    velocity.z = move_toward(velocity.z, desired.z, accel * delta)

    if desired_dir.length_squared() > 0.02:
        var target_yaw := atan2(-desired_dir.x, -desired_dir.z)
        rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 10.0, 0.0, 1.0))

    move_and_slide()

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
    game.flash_damage()
    if health <= 0:
        reconstruct()

func reconstruct() -> void:
    health = max_health
    global_position = spawn_position
    velocity = Vector3.ZERO
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
