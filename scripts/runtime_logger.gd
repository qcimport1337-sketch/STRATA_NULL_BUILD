extends Node

const LOG_DIR := "user://logs"
const LOG_PATH := LOG_DIR + "/strata_runtime.log"

func _ready() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LOG_DIR))
    write("LOGGER_READY")
    write("OS=" + OS.get_name())
    write("ENGINE=" + Engine.get_version_info().get("string","unknown"))

func write(message: String) -> void:
    var stamp := Time.get_datetime_string_from_system(true, true)
    var line := "[%s] %s\n" % [stamp, message]
    var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
    if f == null:
        f = FileAccess.open(LOG_PATH, FileAccess.WRITE)
    if f == null:
        return
    f.seek_end()
    f.store_string(line)
    f.flush()
    f.close()

func clear() -> void:
    var f := FileAccess.open(LOG_PATH, FileAccess.WRITE)
    if f != null:
        f.store_string("")
        f.flush()
        f.close()
