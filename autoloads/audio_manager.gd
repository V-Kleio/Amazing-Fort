extends Node

## Global audio: background music (with crossfade) + a pooled SFX API, routed through
## Master → { Music, SFX } buses whose volumes the player controls in Settings.
##
## Music streams are assigned per-scene (editor-assignable @export on main_menu /
## level_controller) and started via play_music(); SFX is API-only: call play_sfx(stream).
## Volumes/mute are persisted through SaveManager. Runs with PROCESS_MODE_ALWAYS so audio
## keeps playing while the game is paused (e.g. the in-game settings overlay).

const BUS_MASTER: String = "Master"
const BUS_MUSIC: String = "Music"
const BUS_SFX: String = "SFX"

const MIN_DB: float = -80.0
const SFX_POOL_SIZE: int = 8

var _music_players: Array[AudioStreamPlayer] = []
var _active_music: int = 0
var _current_music: AudioStream = null

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_create_players()
	_load_settings()

# --- Setup -------------------------------------------------------------------

## Create the Music/SFX buses (routed to Master) if a bus layout hasn't already.
func _ensure_buses() -> void:
	for bus_name in [BUS_MUSIC, BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus()  # appended at the end → index == old bus_count
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, BUS_MASTER)

func _create_players() -> void:
	for i in 2:
		var music: AudioStreamPlayer = AudioStreamPlayer.new()
		music.bus = BUS_MUSIC
		music.process_mode = Node.PROCESS_MODE_ALWAYS
		music.finished.connect(_on_music_finished.bind(music))
		add_child(music)
		_music_players.append(music)

	for i in SFX_POOL_SIZE:
		var sfx: AudioStreamPlayer = AudioStreamPlayer.new()
		sfx.bus = BUS_SFX
		sfx.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(sfx)
		_sfx_players.append(sfx)

func _load_settings() -> void:
	apply_master_volume(SaveManager.get_master_volume())
	apply_music_volume(SaveManager.get_music_volume())
	apply_sfx_volume(SaveManager.get_sfx_volume())
	AudioServer.set_bus_mute(AudioServer.get_bus_index(BUS_MASTER), SaveManager.is_muted())

# --- Volume (0.0..1.0 linear) ------------------------------------------------

func _apply(bus_name: String, value: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value, 0.0001)))

## apply_* set the bus level live without persisting (for slider dragging).
func apply_master_volume(value: float) -> void:
	_apply(BUS_MASTER, value)

func apply_music_volume(value: float) -> void:
	_apply(BUS_MUSIC, value)

func apply_sfx_volume(value: float) -> void:
	_apply(BUS_SFX, value)

## set_* apply AND persist (call on slider release / settings close).
func set_master_volume(value: float) -> void:
	apply_master_volume(value)
	SaveManager.set_master_volume(value)

func set_music_volume(value: float) -> void:
	apply_music_volume(value)
	SaveManager.set_music_volume(value)

func set_sfx_volume(value: float) -> void:
	apply_sfx_volume(value)
	SaveManager.set_sfx_volume(value)

func get_master_volume() -> float:
	return SaveManager.get_master_volume()

func get_music_volume() -> float:
	return SaveManager.get_music_volume()

func get_sfx_volume() -> float:
	return SaveManager.get_sfx_volume()

func set_muted(muted: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(BUS_MASTER), muted)
	SaveManager.set_muted(muted)

func is_muted() -> bool:
	return SaveManager.is_muted()

# --- Music -------------------------------------------------------------------

## Crossfade to `stream`. No-op if null or already the current track.
func play_music(stream: AudioStream, crossfade: float = 1.0) -> void:
	if stream == null or stream == _current_music:
		return
	var new_index: int = 1 - _active_music
	var new_player: AudioStreamPlayer = _music_players[new_index]
	var old_player: AudioStreamPlayer = _music_players[_active_music]

	_active_music = new_index  # swap first so the loop handler targets the right player
	_current_music = stream

	new_player.stream = stream
	new_player.volume_db = MIN_DB
	new_player.play()
	create_tween().tween_property(new_player, "volume_db", 0.0, crossfade)

	if old_player.playing:
		var fade_out: Tween = create_tween()
		fade_out.tween_property(old_player, "volume_db", MIN_DB, crossfade)
		fade_out.tween_callback(old_player.stop)

func stop_music(fade: float = 0.5) -> void:
	_current_music = null
	var player: AudioStreamPlayer = _music_players[_active_music]
	if not player.playing:
		return
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", MIN_DB, fade)
	tween.tween_callback(player.stop)

## Loop the active track (fires for non-looping streams; internally-looping ones never emit).
func _on_music_finished(player: AudioStreamPlayer) -> void:
	if player == _music_players[_active_music] and player.stream != null:
		player.play()

# --- SFX (API-only) ----------------------------------------------------------

## Play a one-shot sound effect on the SFX bus. No-op if null.
func play_sfx(stream: AudioStream, pitch: float = 1.0) -> void:
	if stream == null:
		return
	var player: AudioStreamPlayer = _free_sfx_player()
	player.stream = stream
	player.pitch_scale = pitch
	player.play()

## First idle pool player, else round-robin to recycle the oldest.
func _free_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player
	var chosen: AudioStreamPlayer = _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	return chosen
