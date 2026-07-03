extends Node

## Handles persistent save data for the roguelite project.

const SAVE_FILE_PATH: String = "user://save_data.json"

var settings: Dictionary = {}

func _ready() -> void:
	load_data()

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		_init_defaults()
		save_data()
		return
	var file: FileAccess = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file:
		var json_string: String = file.get_as_text()
		file.close()
		var json: JSON = JSON.new()
		if json.parse(json_string) == OK:
			var data = json.get_data()
			if data is Dictionary:
				settings = data.get("settings", {})
			else:
				_init_defaults()
		else:
			_init_defaults()
	else:
		_init_defaults()

func save_data() -> void:
	var file: FileAccess = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"settings": settings}, "\t"))
		file.close()
	else:
		push_error("Failed to save data")

func _init_defaults() -> void:
	settings = {
		"tutorial_completed": false,
		"master_volume": 1.0,
		"music_volume": 1.0,
		"sfx_volume": 1.0,
		"muted": false,
	}

func is_tutorial_completed() -> bool:
	return settings.get("tutorial_completed", false)

func complete_tutorial() -> void:
	settings["tutorial_completed"] = true
	save_data()

func reset_tutorial() -> void:
	settings["tutorial_completed"] = false
	save_data()

# --- Audio settings (0.0..1.0 linear volumes; missing keys fall back to defaults) ---

func get_master_volume() -> float:
	return settings.get("master_volume", 1.0)

func set_master_volume(value: float) -> void:
	settings["master_volume"] = value
	save_data()

func get_music_volume() -> float:
	return settings.get("music_volume", 1.0)

func set_music_volume(value: float) -> void:
	settings["music_volume"] = value
	save_data()

func get_sfx_volume() -> float:
	return settings.get("sfx_volume", 1.0)

func set_sfx_volume(value: float) -> void:
	settings["sfx_volume"] = value
	save_data()

func is_muted() -> bool:
	return settings.get("muted", false)

func set_muted(value: bool) -> void:
	settings["muted"] = value
	save_data()
