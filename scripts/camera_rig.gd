extends Node3D
class_name StrataCameraRig

var target: Node3D
var camera: Camera3D
var backdrop_root: Node3D
var plane_tangent := Vector3.RIGHT
var plane_normal := Vector3.BACK
var follow_height := 1.30
var camera_distance := 10.0
var camera_size := 8.2
var look_ahead := 0.9
var current_quadrant := 0

func setup(p_target: Node3D) -> Camera3D:
    target = p_target
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = camera_size
    camera.near = 0.05
    camera.far = 300.0
    add_child(camera)
    camera.current = true
    _build_flat_backdrop()
    return camera

func _flat_material(c: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    return m

func _quad(parent: Node3D, pos: Vector3, size: Vector2, c: Color) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var q := QuadMesh.new()
    q.size = size
    mi.mesh = q
    mi.position = pos
    mi.material_override = _flat_material(c)
    parent.add_child(mi)
    return mi

func _build_flat_backdrop() -> void:
    backdrop_root = Node3D.new()
    backdrop_root.name = "MangaBackdrop"
    camera.add_child(backdrop_root)

    # Everything here lives in camera-local space, so it always remains a literal flat composition.
    _quad(backdrop_root, Vector3(0,0,-120), Vector2(42,24), Color(0.91,0.91,0.87))
    _quad(backdrop_root, Vector3(-12,2,-118), Vector2(8,25), Color(0.07,0.07,0.075))
    _quad(backdrop_root, Vector3(12,1,-118), Vector2(7,24), Color(0.10,0.10,0.105))
    _quad(backdrop_root, Vector3(-4,7,-117), Vector2(5,10), Color(0.18,0.18,0.18))
    _quad(backdrop_root, Vector3(4,6,-117), Vector2(6,12), Color(0.15,0.15,0.15))

    for i in range(12):
        var x := -10.5 + float(i) * 1.9
        _quad(backdrop_root, Vector3(x,3.0,-116), Vector2(0.16,16.0), Color(0.015,0.015,0.018))
    for j in range(6):
        var y := -4.0 + float(j) * 2.4
        _quad(backdrop_root, Vector3(0,y,-115.5), Vector2(24.0,0.10), Color(0.20,0.20,0.19))

func set_quadrant(index: int) -> void:
    current_quadrant = posmod(index, 4)
    match current_quadrant:
        0:
            plane_tangent = Vector3.RIGHT
        1:
            plane_tangent = Vector3(0,0,-1)
        2:
            plane_tangent = Vector3.LEFT
        3:
            plane_tangent = Vector3(0,0,1)
    plane_normal = Vector3(-plane_tangent.z, 0.0, plane_tangent.x).normalized()
    _snap_to_target()

func set_traversal_plane(tangent: Vector3) -> void:
    var t := tangent
    t.y = 0.0
    if t.length_squared() < 0.001:
        return
    t = t.normalized()
    plane_tangent = t
    plane_normal = Vector3(-t.z, 0.0, t.x).normalized()
    if absf(t.x) > 0.5:
        current_quadrant = 0 if t.x > 0 else 2
    else:
        current_quadrant = 3 if t.z > 0 else 1
    _snap_to_target()

func _snap_to_target() -> void:
    if target == null:
        return
    var focus := target.global_position + Vector3(0, follow_height, 0)
    global_position = focus + plane_normal * camera_distance + Vector3(0,0.8,0)
    look_at(focus, Vector3.UP)

func _process(_delta: float) -> void:
    if target == null:
        return
    var travel_sign := signf(target.velocity.dot(plane_tangent))
    var ahead: Vector3 = plane_tangent * look_ahead * travel_sign
    var focus: Vector3 = target.global_position + Vector3(0, follow_height, 0) + ahead
    global_position = focus + plane_normal * camera_distance + Vector3(0,0.8,0)
    look_at(focus, Vector3.UP)
