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
	settings = {"tutorial_completed": false}

func is_tutorial_completed() -> bool:
	return settings.get("tutorial_completed", false)

func complete_tutorial() -> void:
	settings["tutorial_completed"] = true
	save_data()
