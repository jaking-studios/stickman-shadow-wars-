extends Battle
## Arena Survival: endless waves of shadow fighters. Each wave has more,
## tougher and smarter enemies; up to three attack at once and coordinate so
## they don't all crowd in together. The player heals a little between waves.

enum Phase { INTRO, FIGHT, BETWEEN, GAME_OVER }

const MAX_ON_SCREEN := 3
const HEAL_BETWEEN_WAVES := 30.0
const SHADOW_BODY := Color(0.32, 0.24, 0.45)
const SHADOW_AURA := Color(0.55, 0.2, 1.0)
const SHADOW_EYES := Color(1.0, 0.15, 0.25)

var phase := Phase.INTRO
var wave := 0
var kos := 0
var player: Fighter

var _to_spawn := 0
var _spawn_timer := 0.0
var _side := 1


func _setup() -> void:
	var autoplay := "--autoplay" in OS.get_cmdline_user_args()
	var input: FighterInput = AIInput.new(3) if autoplay else PlayerInput.new("p1")
	player = spawn_fighter("PLAYER", input, 0, Color(0.88, 0.94, 1.0), Color(0.25, 0.6, 1.0))
	hud.show_timer = false
	hud.max_bars = 1


func _begin() -> void:
	player.reset_for_round(Vector2(0, 0), 1)
	camera.snap()
	_next_wave()


func _is_fighting() -> bool:
	return phase == Phase.FIGHT or phase == Phase.BETWEEN


func _process(delta: float) -> void:
	super(delta)
	if get_tree().paused:
		return
	hud.side_text = "WAVE %d" % maxi(wave, 1)
	hud.side_sub = "KOs %d   ·   BEST WAVE %d" % [kos, GameState.profile.best_wave]
	if phase == Phase.GAME_OVER:
		if Input.is_action_just_pressed("p1_light") or Input.is_action_just_pressed("p1_jump") or Input.is_action_just_pressed("ui_accept"):
			restart()


func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.GAME_OVER and event is InputEventScreenTouch and event.pressed:
		restart()


func _physics_process(delta: float) -> void:
	super(delta)
	if phase != Phase.FIGHT or get_tree().paused:
		return
	var alive := _enemies_alive()
	if _to_spawn > 0 and alive < MAX_ON_SCREEN:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_enemy()
			_spawn_timer = maxf(0.6, 2.0 - wave * 0.1)
	elif _to_spawn == 0 and alive == 0:
		_wave_cleared()


func _enemies_alive() -> int:
	var n := 0
	for f in fighters:
		if f.team == 1 and f.is_alive():
			n += 1
	return n


func _next_wave() -> void:
	wave += 1
	_to_spawn = wave + 1
	_spawn_timer = 0.8
	phase = Phase.INTRO
	hud.announce("WAVE %d" % wave, "%d shadows incoming" % _to_spawn, 1.4)
	Sfx.play(&"gong", 1.0 + wave * 0.03, -6.0)
	after(1.4, _start_fighting)


func _start_fighting() -> void:
	player.input.enabled = true
	phase = Phase.FIGHT


func _spawn_enemy() -> void:
	_to_spawn -= 1
	_side = -_side
	var level := clampi((wave - 1) / 2, 0, 3)
	var enemy := spawn_fighter("SHADOW", AIInput.new(level), 1, SHADOW_BODY, SHADOW_AURA)
	enemy.eye_color = SHADOW_EYES
	enemy.rig.eye_color = SHADOW_EYES
	enemy.max_health = 40.0 + wave * 8.0
	enemy.show_overhead_bar = true
	enemy.reset_for_round(Vector2(_side * (Arena.HALF_WIDTH - 80.0), -500.0), -_side)
	# Later waves bring armed shadows.
	if weapons_enabled and wave >= 3 and randf() < minf(0.15 * (wave - 2), 0.6):
		enemy.equip(WeaponLibrary.random_weapon())
	Effects.ring(fx_layer, enemy.global_position + Vector2(0, -40), SHADOW_AURA)


func _wave_cleared() -> void:
	phase = Phase.BETWEEN
	player.health = minf(player.max_health, player.health + HEAL_BETWEEN_WAVES)
	hud.announce("WAVE CLEARED", "+%d health" % int(HEAL_BETWEEN_WAVES), 1.6)
	Effects.ring(fx_layer, player.global_position + Vector2(0, -50), Color(0.4, 1.0, 0.6))
	after(2.2, _next_wave)


func _on_ko(fighter: Node, killer: Node) -> void:
	var f := fighter as Fighter
	if f == player:
		_game_over()
		return
	kos += 1
	camera.add_trauma(0.5)
	Sfx.play(&"ko", 1.2, -2.0)
	Effects.popup(fx_layer, f.global_position + Vector2(0, -90), "K.O.", Color(1.0, 0.85, 0.3), 36)
	if _to_spawn == 0 and _enemies_alive() == 0:
		slowmo(0.25, 0.8)
		camera.punch_in(f)
	after(2.5, _fade_out.bind(f))


func _fade_out(f: Fighter) -> void:
	if not is_instance_valid(f):
		return
	var tween := create_tween()
	tween.tween_property(f, "modulate:a", 0.0, 0.6)
	tween.tween_callback(remove_fighter.bind(f))


func _game_over() -> void:
	phase = Phase.GAME_OVER
	for f in fighters:
		f.input.enabled = false
	slowmo(0.2, 1.4)
	camera.punch_in(player)
	camera.add_trauma(0.8)
	Sfx.play(&"ko", 0.8, 2.0)
	var record: bool = wave > GameState.profile.best_wave
	GameState.record_survival(wave, kos)
	if GameState.log_events:
		print("[survival] over, wave=%d kos=%d" % [wave, kos])
	hud.announce("DEFEATED", "Wave %d · %d KOs%s     Light / Jump / tap: retry     Esc: menu" % [wave, kos, "  ·  NEW RECORD!" if record else ""], 1e9)
