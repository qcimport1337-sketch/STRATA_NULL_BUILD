extends CharacterBody3D
class_name StrataEnemy

var target: StrataPlayer
var health := 3
var speed := 2.4
var gravity := 18.0
var attack_cooldown := 0.0
var alert := false
var home := Vector3.ZERO

func setup(p_target: StrataPlayer) -> void:
    target = p_target
    home = global_position

func _physics_process(delta: float) -> void:
    if target == null or health <= 0:
        return
    attack_cooldown = maxf(0.0, attack_cooldown - delta)
    if not is_on_floor():
        velocity.y -= gravity * delta
    var delta_pos := target.global_position - global_position
    var flat := Vector3(delta_pos.x, 0, delta_pos.z)
    var d := flat.length()
    if d < 15.0:
        alert = true
    if alert:
        if d > 1.35:
            var dir := flat.normalized()
            velocity.x = move_toward(velocity.x, dir.x * speed, 8.0 * delta)
            velocity.z = move_toward(velocity.z, dir.z * speed, 8.0 * delta)
            if dir.length_squared() > 0.01:
                rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), delta * 7.0)
        else:
            velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
            velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
            if attack_cooldown <= 0.0:
                attack_cooldown = 1.05
                target.take_damage(14)
    move_and_slide()

func damage(amount: int = 1) -> void:
    health -= amount
    alert = true
    if health <= 0:
        set_physics_process(false)
        visible = false
        collision_layer = 0
        collision_mask = 0

func serialize() -> Dictionary:
    return {"health": health, "position": [global_position.x, global_position.y, global_position.z]}

func restore(data: Dictionary) -> void:
    health = int(data.get("health", 3))
    var p = data.get("position", [])
    if p is Array and p.size() == 3:
        global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
    var alive := health > 0
    visible = alive
    collision_layer = 2 if alive else 0
    collision_mask = 1 if alive else 0
    set_physics_process(alive)
