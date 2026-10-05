extends Node

const SAVE_DIR := "user://saves"
const SAVE_PATH := SAVE_DIR + "/slot_0.save"
const PREV_PATH := SAVE_DIR + "/slot_0.prev.save"
const TEMP_PATH := SAVE_DIR + "/slot_0.tmp"
const SAVE_FORMAT_VERSION := 1
const GENERATOR_VERSION := 1

func _ready() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))

func save_game(data: Dictionary) -> bool:
    var payload := data.duplicate(true)
    payload["save_format_version"] = SAVE_FORMAT_VERSION
    payload["generator_version"] = GENERATOR_VERSION
    payload["timestamp_unix"] = Time.get_unix_time_from_system()
    var f := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    if f == null:
        push_error("STRATA save: could not open temp file")
        return false
    f.store_string(JSON.stringify(payload))
    f.flush()
    f.close()
    if FileAccess.file_exists(SAVE_PATH):
        if FileAccess.file_exists(PREV_PATH):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(PREV_PATH))
        DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(PREV_PATH))
    var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(SAVE_PATH))
    return err == OK

func load_game() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH):
        return {}
    var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if f == null:
        return {}
    var text := f.get_as_text()
    f.close()
    var parsed = JSON.parse_string(text)
    return parsed if parsed is Dictionary else {}
