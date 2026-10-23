extends Node2D
## One versus match. Builds the arena, spawns fighters for the chosen mode,
## runs the round flow (intro, fight, KO / time out, match end) and turns
## combat events into juice: sparks, sound, shake, slow motion, popups.

enum Phase { INTRO, FIGHT, ROUND_OVER, MATCH_OVER }

const ROUND_TIME := 99.0
const COLORS := [Color(0.88, 0.94, 1.0), Color(1.0, 0.42, 0.38)]
const AURAS := [Color(0.25, 0.6, 1.0), Color(1.0, 0.2, 0.25)]
const MENU_SCENE := "res://scenes/main_menu.tscn"

var arena: Arena
var camera: MatchCamera
var hud: Hud
var fx_layer: Node2D
var fighters: Array[Fighter] = []
var wins := [0, 0]
var round_number := 1
var time_left := ROUND_TIME
var phase := Phase.INTRO
var best_combo := 0

var _slowmo_token := 0
var _pause_layer: CanvasLayer


func _ready() -> void:
	Engine.time_scale = 1.0
	# The match keeps listening for pause while paused; everything it spawns
	# is explicitly pausable.
	process_mode = Node.PROCESS_MODE_ALWAYS
	arena = Arena.new()
	add_child(arena)
	for i in 2:
		var f := Fighter.new()
		f.player_index = i
		f.body_color = COLORS[i]
		f.aura_color = AURAS[i]
		f.display_name = _name_for(i)
		f.input = _input_for(i)
		add_child(f)
		fighters.append(f)
	fx_layer = Node2D.new()
	fx_layer.z_index = 20
	add_child(fx_layer)

	camera = MatchCamera.new()
	add_child(camera)
	camera.targets = fighters
	camera.set_bounds(arena.camera_bounds())
	camera.make_current()
	arena.camera = camera

	hud = Hud.new()
	hud.fighters = fighters
	hud.wins = wins
	hud.rounds_to_win = GameState.rounds_to_win
	add_child(hud)
	if InputSetup.wants_touch_controls():
		var touch_layer := CanvasLayer.new()
		touch_layer.layer = 6
		add_child(touch_layer)
		var touch := TouchControls.new()
		touch.pause_pressed.connect(_toggle_pause)
		touch_layer.add_child(touch)
	else:
		hud.hint = "Esc: pause    F1: hitboxes"
	for child in get_children():
		if child.process_mode == Node.PROCESS_MODE_INHERIT:
			child.process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_pause_menu()

	CombatBus.hit_resolved.connect(_on_hit)
	CombatBus.fighter_ko.connect(_on_ko)
	CombatBus.fx.connect(_on_fx)
	_start_round()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false


func _name_for(i: int) -> String:
	match GameState.mode:
		GameState.Mode.VS_CPU:
			return "PLAYER" if i == 0 else "CPU · %s" % GameState.DIFFICULTIES[GameState.difficulty].to_upper()
		GameState.Mode.VS_LOCAL:
			return "PLAYER %d" % (i + 1)
		_:
			return "CPU %d" % (i + 1)


func _input_for(i: int) -> FighterInput:
	match GameState.mode:
		GameState.Mode.VS_CPU:
			return PlayerInput.new("p1") if i == 0 else AIInput.new(GameState.difficulty)
		GameState.Mode.VS_LOCAL:
			return PlayerInput.new("p%d" % (i + 1))
		_:
			return AIInput.new(GameState.difficulty)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel") or _start_pressed():
		_toggle_pause()
	if get_tree().paused:
		return
	hud.time_left = time_left
	if phase == Phase.FIGHT:
		time_left = maxf(0.0, time_left - delta)
		if time_left <= 0.0:
			_time_up()
	elif phase == Phase.MATCH_OVER:
		if Input.is_action_just_pressed("p1_light") or Input.is_action_just_pressed("p1_jump") or Input.is_action_just_pressed("ui_accept"):
			get_tree().reload_current_scene()


func _start_pressed() -> bool:
	for pad in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_START):
			if not _start_held.has(pad):
				_start_held[pad] = true
				return true
		else:
			_start_held.erase(pad)
	return false

var _start_held := {}


# --- Round flow ----------------------------------------------------------

func _start_round() -> void:
	phase = Phase.INTRO
	time_left = ROUND_TIME
	for i in fighters.size():
		fighters[i].reset_for_round(arena.spawn_points[i], 1 if i == 0 else -1)
		fighters[i].input.enabled = false
	camera.snap()
	var title := "FINAL ROUND" if wins[0] == GameState.rounds_to_win - 1 and wins[1] == GameState.rounds_to_win - 1 else "ROUND %d" % round_number
	hud.announce(title, arena.display_name, 1.2)
	Sfx.play(&"gong", 1.0, -6.0)
	_after(1.2, _begin_fight)


func _begin_fight() -> void:
	hud.announce("FIGHT!", "", 0.7)
	Sfx.play(&"hit_heavy", 0.7)
	camera.add_trauma(0.3)
	for f in fighters:
		f.input.enabled = true
	phase = Phase.FIGHT


func _on_ko(fighter: Node, killer: Node) -> void:
	if phase != Phase.FIGHT:
		return
	phase = Phase.ROUND_OVER
	for f in fighters:
		f.input.enabled = false
	_slowmo(0.2, 1.2)
	camera.punch_in(fighter)
	camera.add_trauma(0.8)
	Sfx.play(&"ko", 1.0, 2.0)
	var perfect := (killer as Fighter).health >= (killer as Fighter).max_health
	hud.announce("K.O.", "PERFECT!" if perfect else "", 1.8)
	_after(2.4, _finish_round.bind(fighters.find(killer)))


func _time_up() -> void:
	phase = Phase.ROUND_OVER
	for f in fighters:
		f.input.enabled = false
	var r0 := fighters[0].health / fighters[0].max_health
	var r1 := fighters[1].health / fighters[1].max_health
	var winner := -1 if is_equal_approx(r0, r1) else (0 if r0 > r1 else 1)
	hud.announce("TIME", "DRAW" if winner == -1 else "", 1.6)
	_after(1.8, _finish_round.bind(winner))


func _finish_round(winner: int) -> void:
	if GameState.log_events:
		print("[round] %d winner=%d" % [round_number, winner])
	if winner >= 0:
		wins[winner] += 1
		fighters[winner].celebrate()
		if wins[winner] >= GameState.rounds_to_win:
			phase = Phase.MATCH_OVER
			if GameState.log_events:
				print("[match] over, winner=%d wins=%s" % [winner, wins])
			hud.announce("%s WINS" % fighters[winner].display_name, "Light / Jump / tap: rematch     Esc: menu", 1e9)
			if GameState.mode == GameState.Mode.VS_CPU:
				GameState.record_match(winner == 0, best_combo)
			return
	_after(1.3, _next_round)


func _next_round() -> void:
	round_number += 1
	_start_round()


func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.MATCH_OVER and event is InputEventScreenTouch and event.pressed:
		get_tree().reload_current_scene()


# --- Juice ---------------------------------------------------------------

func _on_hit(info: Dictionary) -> void:
	var atk: AttackData = info["attack"]
	var point: Vector2 = info["point"]
	var attacker: Fighter = info["attacker"]
	var target: Fighter = info["target"]
	if GameState.log_events:
		print("[hit] %s -> %s  %s  result=%d  hp=%.0f  combo=%d" % [attacker.display_name, target.display_name, atk.id, info["result"], target.health, target.combo_taken])
	match info["result"]:
		Fighter.HitResult.HIT:
			var counter: bool = info["counter"]
			Effects.spark(fx_layer, point, Color(1.0, 0.75, 0.3) if atk.heavy_hit else Color(1, 1, 1), 1.4 if atk.heavy_hit or counter else 0.9)
			Sfx.play(&"hit_heavy" if atk.heavy_hit else &"hit_light")
			camera.add_trauma(atk.shake * 0.06 + (0.3 if counter else 0.0))
			if counter:
				Effects.popup(fx_layer, point + Vector2(0, -50), "COUNTER!", Color(1.0, 0.35, 0.3), 38)
				Effects.ring(fx_layer, point, Color(1.0, 0.35, 0.3))
				_slowmo(0.35, 0.18)
			if target.combo_taken >= 2:
				hud.show_combo(attacker.player_index, target.combo_taken)
				if attacker.player_index == 0:
					best_combo = maxi(best_combo, target.combo_taken)
		Fighter.HitResult.BLOCKED:
			Effects.spark(fx_layer, point, Color(0.45, 0.75, 1.0), 0.7)
			Sfx.play(&"block", 1.0, -3.0)
			camera.add_trauma(0.08)
		Fighter.HitResult.PARRIED:
			Effects.spark(fx_layer, point, Color(1.0, 0.85, 0.3), 1.8)
			Effects.ring(fx_layer, point, Color(1.0, 0.85, 0.3))
			Effects.popup(fx_layer, point + Vector2(0, -60), "PARRY!", Color(1.0, 0.85, 0.3), 40)
			Sfx.play(&"parry", 1.0, -2.0)
			camera.add_trauma(0.35)
			_slowmo(0.3, 0.25)


func _on_fx(kind: StringName, pos: Vector2, data: Dictionary) -> void:
	match kind:
		&"dust":
			Effects.dust(fx_layer, pos, data.get("big", false))
		&"jump":
			Effects.ring(fx_layer, pos, Color(1, 1, 1, 0.5))
		&"slam":
			Effects.dust(fx_layer, pos, true)
			Effects.ring(fx_layer, pos, Color(0.6, 0.8, 1.0))
			camera.add_trauma(0.4)
			Sfx.play(&"hit_heavy", 0.6, -4.0)
		&"wall_splat":
			Effects.spark(fx_layer, pos, Color(1.0, 0.5, 0.3), 1.6)
			Effects.popup(fx_layer, pos + Vector2(0, -50), "WALL SPLAT!", Color(1.0, 0.6, 0.3), 32)
			camera.add_trauma(0.5)
			Sfx.play(&"hit_heavy", 0.8)


func _slowmo(scale: float, real_seconds: float) -> void:
	_slowmo_token += 1
	Engine.time_scale = scale
	_after(real_seconds, _end_slowmo.bind(_slowmo_token))


func _end_slowmo(token: int) -> void:
	if token == _slowmo_token:
		Engine.time_scale = 1.0


## Real-time delay that is safely dropped if the match is freed first.
func _after(seconds: float, callback: Callable) -> void:
	get_tree().create_timer(seconds, false, false, true).timeout.connect(callback)


# --- Pause ---------------------------------------------------------------

func _build_pause_menu() -> void:
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 20
	_pause_layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_pause_layer.visible = false
	add_child(_pause_layer)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	box.add_child(title)
	for entry in [["Resume", _toggle_pause], ["Restart Match", _restart], ["Main Menu", _to_menu]]:
		var b := UiStyle.make_button(entry[0])
		b.pressed.connect(entry[1])
		box.add_child(b)


func _toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	_pause_layer.visible = paused
	if paused:
		var first := _pause_layer.get_child(1).get_child(0).get_child(1) as Button
		first.grab_focus()


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
