extends Node
## Match settings chosen in the menu, plus the persistent player profile.
## The profile is the seed of the progression system (XP, currency, unlocks).

enum Mode { VS_CPU, VS_LOCAL, CPU_VS_CPU }

const DIFFICULTIES := ["Easy", "Normal", "Hard", "Nightmare"]
const PROFILE_PATH := "user://profile.json"

var mode := Mode.VS_CPU
var difficulty := 1
var rounds_to_win := 2
var debug_hitboxes := false
## `-- --log` prints combat events to stdout (used by the CI smoke test).
var log_events := "--log" in OS.get_cmdline_user_args()
var profile := {"matches": 0, "wins": 0, "xp": 0, "best_combo": 0}


var _shots := {}
var _frame := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_profile()
	# `-- --shot=<frame>:<path.png>` saves screenshots (used for the README).
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			var parts := arg.trim_prefix("--shot=").split(":", true, 1)
			_shots[int(parts[0])] = parts[1]
		elif arg.begins_with("--record="):
			# --record=<first>:<last>:<every>:<dir> saves numbered frames for GIFs.
			var r := arg.trim_prefix("--record=").split(":", true, 3)
			for f in range(int(r[0]), int(r[1]), int(r[2])):
				_shots[f] = "%s/f%05d.png" % [r[3], f]


func _process(_delta: float) -> void:
	if _shots.is_empty():
		return
	_frame += 1
	if _shots.has(_frame):
		get_viewport().get_texture().get_image().save_png(_shots[_frame])
		_shots.erase(_frame)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_hitboxes"):
		debug_hitboxes = not debug_hitboxes


func record_match(player_won: bool, best_combo: int) -> void:
	profile.matches += 1
	if player_won:
		profile.wins += 1
	profile.xp += 100 if player_won else 35
	profile.best_combo = maxi(profile.best_combo, best_combo)
	save_profile()


func save_profile() -> void:
	var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(profile, "\t"))


func load_profile() -> void:
	if not FileAccess.file_exists(PROFILE_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	if data is Dictionary:
		for key in data:
			if profile.has(key):
				profile[key] = int(data[key])
