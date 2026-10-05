extends Node3D
class_name StrataCameraRig

var target: Node3D
var camera: Camera3D
var plane_tangent := Vector3.RIGHT
var plane_normal := Vector3.BACK
var desired_normal := Vector3.BACK
var follow_height := 1.25
var camera_distance := 9.0
var camera_size := 8.5
var look_ahead := 1.2
var smooth_speed := 7.5

func setup(p_target: Node3D) -> Camera3D:
    target = p_target
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = camera_size
    camera.near = 0.05
    camera.far = 250.0
    add_child(camera)
    camera.current = true
    return camera

func set_traversal_plane(tangent: Vector3) -> void:
    var t := tangent
    t.y = 0.0
    if t.length_squared() < 0.001:
        return
    t = t.normalized()
    plane_tangent = t
    desired_normal = Vector3(-t.z, 0.0, t.x).normalized()

func _process(delta: float) -> void:
    if target == null or camera == null:
        return

    plane_normal = plane_normal.slerp(desired_normal, clampf(delta * 5.0, 0.0, 1.0)).normalized()
    var ahead := plane_tangent * look_ahead * sign(target.velocity.dot(plane_tangent))
    var focus := target.global_position + Vector3(0, follow_height, 0) + ahead
    var desired_pos := focus + plane_normal * camera_distance + Vector3(0, 1.1, 0)
    global_position = global_position.lerp(desired_pos, 1.0 - exp(-smooth_speed * delta))
    look_at(focus, Vector3.UP)
