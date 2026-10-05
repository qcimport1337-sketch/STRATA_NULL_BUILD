extends StaticBody3D
class_name StrataTerminal

var read := false

func get_prompt() -> String:
    return "F  READ TRACE" if not read else "F  REVIEW TRACE"

func interact(game: Node) -> void:
    read = true
    game.show_status("TRACE // DIRECTIVE FRAGMENT: DESCEND", 3.0)
