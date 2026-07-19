extends Node
class_name Main

## Root of the game: title screen -> Level 1 -> Level 2 -> Level 3 ->
## Mission File. Owns the persistent TouchControls and UIManager layers
## (they survive across level loads) and swaps World instances between
## levels.

const WORLD_SCENE := preload("res://scenes/world.tscn")
const TOUCH_CONTROLS_SCENE := preload("res://scenes/touch_controls.tscn")
const UI_SCENE := preload("res://scenes/ui.tscn")
const MISSION_FILE_SCENE := preload("res://scenes/mission_file.tscn")
const INTRO_SCENE_SCRIPT := preload("res://scripts/intro_screen.gd")

const LEVEL_CLEAR_DURATION := 2.0
const TITLE_MIN_DURATION := 3.0

@onready var title_screen: CanvasLayer = $TitleScreen
@onready var title_label: Label = $TitleScreen/TitleLabel
@onready var level_clear_overlay: CanvasLayer = $LevelClearOverlay
@onready var world_container: Node2D = $WorldContainer
@onready var version_label: Label = $VersionTag/VersionLabel
@onready var level_buttons: Array[Button] = [
	$TitleScreen/LevelButtons/Level1Button,
	$TitleScreen/LevelButtons/Level2Button,
	$TitleScreen/LevelButtons/Level3Button,
]
@onready var reset_button: Button = $TitleScreen/ResetButton

var touch_controls: TouchControls
var ui_manager: UIManager
var current_world: WorldGenerator
var _audio_unlocked := false
var _title_touch_ready := false
var _reset_armed := false


func _ready() -> void:
	_ensure_generated_assets()

	version_label.text = "v" + GameManager.BUILD_VERSION

	touch_controls = TOUCH_CONTROLS_SCENE.instantiate()
	add_child(touch_controls)

	ui_manager = UI_SCENE.instantiate()
	add_child(ui_manager)

	level_clear_overlay.visible = false
	title_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.10))
	title_label.text = "CHIP'S DIG & BUILD"

	for i in range(level_buttons.size()):
		level_buttons[i].pressed.connect(_on_level_button_pressed.bind(i))

	reset_button.pressed.connect(_on_reset_button_pressed)

	_show_title_screen()


func _show_title_screen() -> void:
	_refresh_level_buttons()
	title_screen.visible = true
	_title_touch_ready = false
	await get_tree().create_timer(TITLE_MIN_DURATION).timeout
	_title_touch_ready = true


func _refresh_level_buttons() -> void:
	for i in range(level_buttons.size()):
		var unlocked: bool = i <= GameManager.highest_unlocked_level
		level_buttons[i].disabled = not unlocked
		level_buttons[i].modulate.a = 1.0 if unlocked else 0.35


## Tap-twice-to-confirm: the first tap just arms it and relabels the
## button, so a curious kid mashing buttons on the title screen can't
## wipe progress with one accidental tap. A second tap within ~2.5s
## actually resets; anything else (waiting it out, tapping elsewhere)
## just quietly re-arms back to normal.
func _on_reset_button_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		reset_button.text = "TAP AGAIN?"
		get_tree().create_timer(2.5).timeout.connect(func():
			if _reset_armed:
				_reset_armed = false
				reset_button.text = "NEW GAME"
		)
		return

	_reset_armed = false
	reset_button.text = "NEW GAME"
	GameManager.reset_progress()
	_refresh_level_buttons()


func _ensure_generated_assets() -> void:
	var probe_path := "res://generated_assets/chip_idle.png"
	if not FileAccess.file_exists(probe_path):
		# Editor-convenience fallback only: an exported HTML5 build ships
		# with generated_assets/ already baked in by build.sh, since
		# preload() calls elsewhere need the files to exist at export time.
		ProceduralArt.run_all()


func _unhandled_input(event: InputEvent) -> void:
	# Fires only for taps the level-select Buttons didn't already consume,
	# so tapping empty title-screen space starts/continues from wherever
	# Chip left off, without double-triggering when a button is tapped.
	if not title_screen.visible:
		return
	if not _title_touch_ready:
		return
	var touched: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if touched:
		_start_game(GameManager.highest_unlocked_level)


func _on_level_button_pressed(index: int) -> void:
	if not _title_touch_ready:
		return
	if index > GameManager.highest_unlocked_level:
		return
	_start_game(index)


func _start_game(level_index: int) -> void:
	if not _audio_unlocked:
		_audio_unlocked = true
		ProceduralAudio.unlock_audio()
	title_screen.visible = false

	if not GameManager.has_seen_intro:
		GameManager.mark_intro_seen()
		var intro: IntroScreen = INTRO_SCENE_SCRIPT.new()
		add_child(intro)
		intro.intro_complete.connect(func():
			intro.queue_free()
			_load_level(level_index)
		, CONNECT_ONE_SHOT)
		intro.play()
	else:
		_load_level(level_index)


func _load_level(index: int) -> void:
	GameManager.reset_for_level(index)
	current_world = WORLD_SCENE.instantiate()
	world_container.add_child(current_world)
	current_world.build_level(index)
	ui_manager.bind_world(current_world)
	current_world.level_complete.connect(_on_level_complete.bind(index), CONNECT_ONE_SHOT)


func _on_level_complete(index: int) -> void:
	GameManager.unlock_level(index + 1)

	_show_level_clear()
	await get_tree().create_timer(LEVEL_CLEAR_DURATION).timeout
	_hide_level_clear()

	if current_world:
		current_world.queue_free()
		current_world = null

	if index + 1 < LevelData.get_level_count():
		_load_level(index + 1)
	else:
		_show_mission_file()


func _show_level_clear() -> void:
	level_clear_overlay.visible = true
	var label: Label = level_clear_overlay.get_node("LevelClearLabel")
	label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.3)


func _hide_level_clear() -> void:
	level_clear_overlay.visible = false


func _show_mission_file() -> void:
	var mission := MISSION_FILE_SCENE.instantiate()
	if GameManager.custom_mission_message != "":
		mission.custom_message = GameManager.custom_mission_message
	add_child(mission)
	mission.mission_complete.connect(func():
		mission.queue_free()
		_show_title_screen()
	)
	mission.play()
