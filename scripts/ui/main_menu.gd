extends Control
## Title screen: mode select, difficulty, profile stats, and two stickmen
## sparring in the background using the same StickRig as the game.

const MATCH_SCENE := "res://scenes/match.tscn"
const SPAR_POSES: Array[StringName] = [&"idle", &"jab", &"cross", &"kick", &"block", &"heavy", &"uppercut", &"idle", &"dash", &"victory"]

var _difficulty_button: Button
var _rigs: Array[StickRig] = []
var _time := 0.0
var _step := 0


func _ready() -> void:
	Engine.time_scale = 1.0
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	for i in 2:
		var rig := StickRig.new()
		rig.color = Color(0.88, 0.94, 1.0) if i == 0 else Color(1.0, 0.42, 0.38)
		rig.aura_color = Color(0.25, 0.6, 1.0) if i == 0 else Color(1.0, 0.2, 0.25)
		rig.scale = Vector2(2.4 * (1 if i == 0 else -1), 2.4)
		add_child(rig)
		_rigs.append(rig)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -70
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var title := Label.new()
	title.text = "STICKMAN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.6, 1.0))
	title.add_theme_constant_override("outline_size", 10)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "S H A D O W   W A R S"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 34)
	subtitle.add_theme_color_override("font_color", Color(1.0, 0.35, 0.5))
	box.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	box.add_child(spacer)

	var first := _add(box, "1P  vs  CPU", _start.bind(GameState.Mode.VS_CPU))
	_add(box, "2P  Local Versus", _start.bind(GameState.Mode.VS_LOCAL))
	_add(box, "CPU  vs  CPU", _start.bind(GameState.Mode.CPU_VS_CPU))
	_difficulty_button = _add(box, "", _cycle_difficulty)
	_refresh_difficulty()
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		_add(box, "Quit", get_tree().quit)
	first.grab_focus()
	# `godot -- --autoplay` jumps straight into a CPU vs CPU match (demo / CI smoke test).
	if "--autoplay" in OS.get_cmdline_user_args():
		GameState.difficulty = GameState.DIFFICULTIES.size() - 1
		_start.call_deferred(GameState.Mode.CPU_VS_CPU)

	var footer := Label.new()
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -60
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 16)
	footer.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	var p := GameState.profile
	footer.text = "P1: WASD move · W jump · J light · K heavy · L block · Space dodge      P2: Arrows · Numpad 1/2/3/0      Controllers: X/Y/A/B + RB\n" \
		+ "Wins %d / %d matches · XP %d · Best combo %d" % [p.wins, p.matches, p.xp, p.best_combo]
	add_child(footer)


func _add(box: VBoxContainer, text: String, callback: Callable) -> Button:
	var b := UiStyle.make_button(text)
	b.pressed.connect(callback)
	box.add_child(b)
	return b


func _start(mode: GameState.Mode) -> void:
	GameState.mode = mode
	Sfx.play(&"hit_heavy", 0.8, -4.0)
	get_tree().change_scene_to_file(MATCH_SCENE)


func _cycle_difficulty() -> void:
	GameState.difficulty = (GameState.difficulty + 1) % GameState.DIFFICULTIES.size()
	_refresh_difficulty()


func _refresh_difficulty() -> void:
	_difficulty_button.text = "Difficulty:  %s" % GameState.DIFFICULTIES[GameState.difficulty]


func _process(delta: float) -> void:
	_time += delta
	var w := size.x
	var floor_y := size.y - 74.0
	_rigs[0].position = Vector2(w * 0.5 - 380.0, floor_y)
	_rigs[1].position = Vector2(w * 0.5 + 380.0, floor_y)
	if _time > 0.55:
		_time = 0.0
		_step += 1
		_rigs[0].set_pose(SPAR_POSES[_step % SPAR_POSES.size()], 26.0)
		_rigs[1].set_pose(SPAR_POSES[(_step + 4) % SPAR_POSES.size()], 26.0)
	queue_redraw()


func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.05, 0.03, 0.1))
	for i in 12:
		var k := float(i) / 12.0
		draw_rect(Rect2(0, s.y * k, s.x, s.y / 12.0 + 1.0), Color(0.09, 0.04, 0.2).lerp(Color(0.4, 0.08, 0.26), k))
	var moon := Vector2(s.x * 0.5, s.y * 0.36)
	draw_circle(moon, 300.0, Color(1.0, 0.35, 0.5, 0.06))
	draw_circle(moon, 220.0, Color(1.0, 0.45, 0.55, 0.16))
	draw_rect(Rect2(0, s.y - 74.0, s.x, 74.0), Color(0.04, 0.03, 0.07))
	draw_line(Vector2(0, s.y - 74.0), Vector2(s.x, s.y - 74.0), Color(0.35, 0.8, 1.0, 0.9), 3.0)
