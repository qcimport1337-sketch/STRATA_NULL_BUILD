extends Node2D

func _ready() -> void:
    queue_redraw()

func _draw() -> void:
    var cloak := PackedVector2Array([
        Vector2(-10, -24), Vector2(-5, -36), Vector2(5, -36), Vector2(10, -24),
        Vector2(16, -4), Vector2(12, 22), Vector2(22, 42), Vector2(8, 39),
        Vector2(2, 52), Vector2(-5, 52), Vector2(-9, 39), Vector2(-22, 44),
        Vector2(-14, 19), Vector2(-16, -4)
    ])
    draw_colored_polygon(cloak, Color(0.025, 0.025, 0.028, 1.0))
    var outline := PackedVector2Array(cloak)
    outline.append(cloak[0])
    draw_polyline(outline, Color(0.76, 0.76, 0.76, 0.82), 1.3, true)
    draw_circle(Vector2(0, -47), 9.0, Color(0.025, 0.025, 0.028, 1.0))
    draw_arc(Vector2(0, -47), 9.5, 0.0, TAU, 24, Color(0.76, 0.76, 0.76, 0.82), 1.3, true)
    draw_line(Vector2(8, -29), Vector2(20, -70), Color(0.03, 0.03, 0.03, 1.0), 3.0, true)
