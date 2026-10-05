extends AnimatableBody3D
class_name StrataElevator

@export var low_y := 0.1
@export var high_y := 5.1
@export var travel_seconds := 5.0
var phase := 0.0
var base_xz := Vector2.ZERO

func _ready() -> void:
    base_xz = Vector2(global_position.x, global_position.z)

func _physics_process(delta: float) -> void:
    phase += delta / travel_seconds
    var t := (sin(phase * PI) + 1.0) * 0.5
    global_position = Vector3(base_xz.x, lerpf(low_y, high_y, t), base_xz.y)
