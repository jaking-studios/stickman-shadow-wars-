extends Battle
## Versus match: two fighters, best of three rounds, 99-second timer.

enum Phase { INTRO, FIGHT, ROUND_OVER, MATCH_OVER }

const ROUND_TIME := 99.0
const COLORS := [Color(0.88, 0.94, 1.0), Color(1.0, 0.42, 0.38)]
const AURAS := [Color(0.25, 0.6, 1.0), Color(1.0, 0.2, 0.25)]

var wins := [0, 0]
var round_number := 1
var time_left := ROUND_TIME
var phase := Phase.INTRO


func _setup() -> void:
	for i in 2:
		spawn_fighter(_name_for(i), _input_for(i), i, COLORS[i], AURAS[i])
	hud.wins = wins
	hud.rounds_to_win = GameState.rounds_to_win


func _begin() -> void:
	_start_round()


func _is_fighting() -> bool:
	return phase == Phase.FIGHT


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
	super(delta)
	if get_tree().paused:
		return
	hud.time_left = time_left
	if phase == Phase.FIGHT:
		time_left = maxf(0.0, time_left - delta)
		if time_left <= 0.0:
			_time_up()
	elif phase == Phase.MATCH_OVER:
		if Input.is_action_just_pressed("p1_light") or Input.is_action_just_pressed("p1_jump") or Input.is_action_just_pressed("ui_accept"):
			restart()


func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.MATCH_OVER and event is InputEventScreenTouch and event.pressed:
		restart()


func _start_round() -> void:
	phase = Phase.INTRO
	time_left = ROUND_TIME
	clear_pickups()
	for i in fighters.size():
		fighters[i].reset_for_round(arena.spawn_points[i], 1 if i == 0 else -1)
		fighters[i].input.enabled = false
	camera.snap()
	var final: bool = wins[0] == GameState.rounds_to_win - 1 and wins[1] == GameState.rounds_to_win - 1
	hud.announce("FINAL ROUND" if final else "ROUND %d" % round_number, arena.display_name, 1.2)
	Sfx.play(&"gong", 1.0, -6.0)
	after(1.2, _begin_fight)


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
	slowmo(0.2, 1.2)
	camera.punch_in(fighter)
	camera.add_trauma(0.8)
	Sfx.play(&"ko", 1.0, 2.0)
	var perfect := (killer as Fighter).health >= (killer as Fighter).max_health
	hud.announce("K.O.", "PERFECT!" if perfect else "", 1.8)
	after(2.4, _finish_round.bind(fighters.find(killer)))


func _time_up() -> void:
	phase = Phase.ROUND_OVER
	for f in fighters:
		f.input.enabled = false
	var r0 := fighters[0].health / fighters[0].max_health
	var r1 := fighters[1].health / fighters[1].max_health
	var winner := -1 if is_equal_approx(r0, r1) else (0 if r0 > r1 else 1)
	hud.announce("TIME", "DRAW" if winner == -1 else "", 1.6)
	after(1.8, _finish_round.bind(winner))


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
	after(1.3, _next_round)


func _next_round() -> void:
	round_number += 1
	_start_round()
