extends StaticBody3D
class_name StrataDestructible

var breached := false

func damage(_amount: int = 1) -> void:
    set_breached(true)

func set_breached(value: bool) -> void:
    breached = value
    visible = not breached
    collision_layer = 0 if breached else 1
    collision_mask = 0 if breached else 1
    for c in get_children():
        if c is CollisionShape3D:
            c.disabled = breached
