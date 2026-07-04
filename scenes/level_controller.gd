extends Node2D

@export var choosing_phase_scene: PackedScene
@export var building_phase_scene: PackedScene
@export var attacking_phase_scene: PackedScene
@export var win_screen_scene: PackedScene
@export var tutorial_scene: PackedScene
@export var attacker_scene: PackedScene
@export var spawn_offset_range: float = 50.0
## The child the player protects. Spawned once into the persistent Arena.
@export var kid_scene: PackedScene
## Optional floor/walls (StaticBody2D) added to the Arena. Leave empty if not needed yet.
@export var arena_bounds_scene: PackedScene
## The settings overlay opened by the in-game pause button.
@export var settings_scene: PackedScene
## Background track for gameplay; crossfades in (leave empty until you have audio assets).
@export var gameplay_music: AudioStream
## Comic-book splash shown between Build and Attack (optional; graceful fallback if unassigned).
@export var transition_scene: PackedScene
## Heart sprite for the Kid's health display (optional; a drawn placeholder shows if empty).
@export var health_heart_texture: Texture2D
## Pointer hand for the first-run tutorial coach-marks (optional; captions still show if empty).
@export var tutorial_hand_texture: Texture2D

## Bottom-center of the 1920x1080 design space (no camera → world coords == screen coords).
const KID_POSITION: Vector2 = Vector2(960.0, 870.0)
## Local offset of the hearts above the Kid's head.
const HEARTS_OFFSET: Vector2 = Vector2(0.0, -120.0)

@onready var phase_container: Node = $PhaseContainer
@onready var spawn_left: Marker2D = $SpawnPointLeft
@onready var spawn_right: Marker2D = $SpawnPointRight
## Optional in-game pause button (added to the editor HUD; safe if absent).
@onready var _pause_button: TextureButton = get_node_or_null(^"HUD/PauseButton")

var current_phase_node: Node = null
var attacker_instance: Node = null
## Persistent world that survives phase swaps: holds the Kid + all placed furniture.
var arena: Node2D = null
var _settings_open: bool = false

func _ready() -> void:
	GameEvents.try_connect(GameEvents.phase_finished, _on_phase_finished)
	GameEvents.try_connect(GameEvents.game_over, _on_game_over)

	if _pause_button != null:
		_pause_button.pressed.connect(_on_pause_pressed)
		# ALWAYS so the release tween still runs after pressing it pauses the tree.
		_pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
		_setup_pause_juice()

	_show_tutorial_if_needed()

## Press feedback for the pause button (deferred a frame so its size/pivot are valid).
func _setup_pause_juice() -> void:
	await get_tree().process_frame
	UIJuice.center_pivot(_pause_button)
	UIJuice.press_scale(_pause_button)

func _show_tutorial_if_needed() -> void:
	# FTUE is in-game coach-marks (non-blocking): start the session, then guide the first run.
	_begin_session()
	if not SaveManager.is_tutorial_completed():
		var guide: TutorialGuide = TutorialGuide.new()
		guide.hand_texture = tutorial_hand_texture
		add_child(guide)

func _on_tutorial_finished() -> void:
	_begin_session()

func _begin_session() -> void:
	_ensure_arena()
	AudioManager.play_music(gameplay_music)
	GameManager.start_game()
	_load_phase(choosing_phase_scene)

## Create the persistent Arena once per session, as a sibling of PhaseContainer so it is
## never freed by _load_phase. Spawns optional bounds + the Kid into it.
func _ensure_arena() -> void:
	if arena != null and is_instance_valid(arena):
		return
	arena = Node2D.new()
	arena.name = "Arena"
	arena.add_to_group(&"arena")
	add_child(arena)

	if arena_bounds_scene != null:
		arena.add_child(arena_bounds_scene.instantiate())

	if kid_scene != null:
		var kid: Node2D = kid_scene.instantiate()
		arena.add_child(kid)
		kid.global_position = KID_POSITION
		var hearts: HealthDisplay = HealthDisplay.new()
		hearts.heart_texture = health_heart_texture
		hearts.position = HEARTS_OFFSET
		kid.add_child(hearts)

## Accessor for phases that prefer a direct reference over the &"arena" group lookup.
func get_arena() -> Node2D:
	return arena


func _load_phase(scene: PackedScene) -> void:
	if current_phase_node and is_instance_valid(current_phase_node):
		current_phase_node.queue_free()
		await get_tree().process_frame
	current_phase_node = scene.instantiate()
	phase_container.add_child(current_phase_node)

## Build → Attack handoff: play the transition curtain, swap phases behind it, activate
## furniture physics on reveal, then start the attacker. Falls back cleanly with no curtain.
func _run_build_to_attack() -> void:
	var curtain: DefendTransition = null
	if transition_scene != null:
		curtain = transition_scene.instantiate() as DefendTransition
	if curtain != null:
		add_child(curtain)
		await curtain.covered
	await _load_phase(attacking_phase_scene)
	if curtain != null:
		await curtain.finished
	_activate_furniture_physics()
	if attacker_instance and is_instance_valid(attacker_instance):
		var phase := current_phase_node as AttackingPhase
		attacker_instance.start_attack_phase(phase.round_duration if phase != null else 15.0)

## Unfreeze every placed piece so it obeys gravity/collisions in combat (per EntityData).
func _activate_furniture_physics() -> void:
	for piece in get_tree().get_nodes_in_group(&"placeable"):
		if piece.has_method("activate_physics"):
			piece.activate_physics()

func _on_phase_finished(phase_name: String) -> void:
	match phase_name:
		"choosing":
			GameManager.current_phase = GameManager.Phase.BUILDING
			_load_phase(building_phase_scene)
			_spawn_attacker()
		"building":
			GameManager.current_phase = GameManager.Phase.ATTACKING
			await _run_build_to_attack()
		"attacking_win":
			_cleanup_attacker()
			_load_result_screen(true) # <-- Panggil result screen dengan status MENANG (true)
		"attacking_lose":
			_cleanup_attacker()
			_load_result_screen(false)

func _load_result_screen(is_win: bool) -> void:
	if current_phase_node and is_instance_valid(current_phase_node):
		current_phase_node.queue_free()
		await get_tree().process_frame
		
	var result_screen: Node = win_screen_scene.instantiate()
	
	# Kita panggil fungsi setup() yang udah kita buat di skrip WinScreen sebelumnya
	if result_screen.has_method("setup"):
		result_screen.setup(is_win)
		
	# Add to the HUD CanvasLayer (layer 50) so it sits above the room background for INPUT,
	# not just drawing — a plain Control under PhaseContainer (layer 0) gets its clicks eaten.
	var host: Node = get_node_or_null(^"HUD")
	if host == null:
		host = phase_container
	host.add_child(result_screen)

	# Kalau mau game over beneran pas kalah, kamu bisa atur di WinScreen.gd pas tombol diklik
	GameEvents.try_connect(GameEvents.round_started, _on_round_continued)

func _on_round_continued(_round_number: int) -> void:
	GameEvents.try_disconnect(GameEvents.round_started, _on_round_continued)
	_cleanup_attacker()
	_load_phase(choosing_phase_scene)

func _on_game_over() -> void:
	# During combat, let the Kid's death resolve via the Defeated result screen
	# ("attacking_lose" → _load_result_screen(false)) instead of racing to the menu.
	if GameManager.current_phase == GameManager.Phase.ATTACKING:
		return
	SceneManager.load_main_menu()

## Pause the game and open the settings overlay (unpauses on close).
func _on_pause_pressed() -> void:
	if _settings_open or settings_scene == null:
		return
	var settings: Settings = settings_scene.instantiate() as Settings
	if settings == null:
		push_error("LevelController: settings_scene root is not a Settings node.")
		return
	_settings_open = true
	SceneManager.pause_game()
	get_tree().root.add_child(settings)
	settings.on_close.connect(_on_settings_closed)

func _on_settings_closed() -> void:
	_settings_open = false
	SceneManager.unpause_game()
	
func _spawn_attacker() -> void:
	if attacker_instance and is_instance_valid(attacker_instance):
		return

	attacker_instance = attacker_scene.instantiate()
	add_child(attacker_instance)

	var spawn_on_right: bool = randf() < 0.5
	var base_point: Vector2 = spawn_right.global_position if spawn_on_right else spawn_left.global_position
	var offset := Vector2(
		randf_range(-spawn_offset_range, spawn_offset_range),
		randf_range(-spawn_offset_range, spawn_offset_range)
	)
	attacker_instance.global_position = base_point + offset

	attacker_instance.setup(spawn_on_right)

func _cleanup_attacker() -> void:
	if attacker_instance and is_instance_valid(attacker_instance):
		attacker_instance.cleanup()
		attacker_instance.queue_free()
		attacker_instance = null
	# Clear any live balls from the barrage so they don't linger into the next phase.
	for ball in get_tree().get_nodes_in_group(&"enemy_projectile"):
		ball.queue_free()
