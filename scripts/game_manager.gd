extends Node

## Autoload: small shared state that survives scene changes between levels
## (current level index, block backpack count). Gameplay entities read/write
## this instead of passing state through scene-instantiation arguments.

signal blocks_changed(count: int)
signal level_index_changed(index: int)

const MAX_BLOCKS := 5

## Bumped by hand on every deploy so the on-screen build tag (see main.gd)
## makes it obvious whether a device is showing a stale cached build.
const BUILD_VERSION := "2026-07-19.8"

const SAVE_PATH := "user://progress.save"

var current_level_index := 0
var block_count := 0
var custom_mission_message := ""

## Highest level index Chip has ever reached (0-based). Level 0 is always
## playable. Persisted across sessions so the title screen's level-select
## can offer replaying any level already unlocked.
var highest_unlocked_level := 0

## Whether the first-time icon-only tutorial (IntroScreen) has already
## been shown. Persisted so it only ever appears once per player, not
## once per session.
var has_seen_intro := false


func _ready() -> void:
	load_progress()


func unlock_level(index: int) -> void:
	if index > highest_unlocked_level:
		highest_unlocked_level = index
		save_progress()


func mark_intro_seen() -> void:
	if not has_seen_intro:
		has_seen_intro = true
		save_progress()


## Wipes saved progress (level unlocks + intro-seen flag) so the title
## screen's level-select and intro tutorial both behave like a first-ever
## play again. Used by the title screen's "reset" button.
func reset_progress() -> void:
	highest_unlocked_level = 0
	has_seen_intro = false
	if FileAccess.file_exists(SAVE_PATH):
		var dir := DirAccess.open("user://")
		if dir:
			dir.remove(SAVE_PATH.trim_prefix("user://"))


func save_progress() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_var({
			"highest_unlocked_level": highest_unlocked_level,
			"has_seen_intro": has_seen_intro,
		})


func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var value = f.get_var()
	if typeof(value) == TYPE_DICTIONARY:
		highest_unlocked_level = value.get("highest_unlocked_level", 0)
		has_seen_intro = value.get("has_seen_intro", false)
	elif typeof(value) == TYPE_INT:
		# Backward-compat with the old bare-int save format.
		highest_unlocked_level = value


func reset_for_level(index: int) -> void:
	current_level_index = index
	block_count = 0
	level_index_changed.emit(current_level_index)
	blocks_changed.emit(block_count)


func add_blocks(amount: int) -> void:
	block_count = clampi(block_count + amount, 0, MAX_BLOCKS)
	blocks_changed.emit(block_count)


func use_block() -> bool:
	if block_count <= 0:
		return false
	block_count -= 1
	blocks_changed.emit(block_count)
	return true


func can_place_block() -> bool:
	return block_count > 0
