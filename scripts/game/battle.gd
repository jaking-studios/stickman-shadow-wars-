class_name Battle
extends Node2D
## Shared base for every fight scene (versus, survival, and later story and
## tournament). Builds the arena, camera, HUD, touch controls and pause menu,
## spawns fighters, drops weapon pickups, and turns combat events into juice:
## sparks, sound, shake, slow motion and popups.
##
## Subclasses override _setup() to add fighters and run their own flow.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const WEAPON_INTERVAL := Vector2(9.0, 15.0)
const MAX_PICKUPS := 2

var arena: Arena
var camera: MatchCamera
var hud: Hud
var fx_layer: Node2D
var fighters: Array[Fighter] = []
var best_combo := 0
## Weapons fall from the sky while true.
var weapons_enabled := true

var _slowmo_token := 0
var _pause_layer: CanvasLayer
var _start_held := {}
var _weapon_timer := 0.0


func _ready() -> void:
	Engine.time_scale = 1.0
	# The battle keeps listening for pause while paused; everything it spawns
	# is explicitly pausable.
	process_mode = Node.PROCESS_MODE_ALWAYS
	weapons_enabled = GameState.weapons_enabled
	arena = Arena.new()
	arena.theme_id = GameState.pick_arena()
	add_child(arena)
	fx_layer = Node2D.new()
	fx_layer.z_index = 20
	add_child(fx_layer)
	camera = MatchCamera.new()
	add_child(camera)
	camera.set_bounds(arena.camera_bounds())
	camera.make_current()
	arena.camera = camera
	hud = Hud.new()
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
	_weapon_timer = randf_range(4.0, 7.0)

	CombatBus.hit_resolved.connect(_on_hit)
	CombatBus.fighter_ko.connect(_on_ko)
	CombatBus.fx.connect(_on_fx)
	_setup()
	camera.targets = fighters
	hud.fighters = fighters
	for child in get_children():
		if child.process_mode == Node.PROCESS_MODE_INHERIT:
			child.process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_pause_menu()
	_begin()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false


# --- Hooks for subclasses ------------------------------------------------

## Spawn fighters and configure the HUD.
func _setup() -> void:
	pass


## Called once everything exists: start the first round / wave.
func _begin() -> void:
	pass


## True while fighters are allowed to act (weapons only drop then).
func _is_fighting() -> bool:
	return true


func _on_ko(_fighter: Node, _killer: Node) -> void:
	pass


# --- Helpers -------------------------------------------------------------

func spawn_fighter(display_name: String, input: FighterInput, team: int, body: Color, aura: Color) -> Fighter:
	var f := Fighter.new()
	f.player_index = fighters.size()
	f.display_name = display_name
	f.input = input
	f.team = team
	f.body_color = body
	f.aura_color = aura
	add_child(f)
	f.process_mode = Node.PROCESS_MODE_PAUSABLE
	fighters.append(f)
	return f


func remove_fighter(f: Fighter) -> void:
	fighters.erase(f)
	if is_instance_valid(f):
		f.queue_free()


func clear_pickups() -> void:
	for p in get_tree().get_nodes_in_group(&"pickups"):
		p.queue_free()


func drop_weapon(weapon: WeaponData, pos: Vector2, velocity := Vector2.ZERO) -> void:
	var p := WeaponPickup.new()
	p.weapon = weapon
	p.position = pos
	p.velocity = velocity
	add_child(p)
	p.process_mode = Node.PROCESS_MODE_PAUSABLE


## Real-time delay that is safely dropped if the battle is freed first.
func after(seconds: float, callback: Callable) -> void:
	get_tree().create_timer(seconds, false, false, true).timeout.connect(callback)


func slowmo(scale: float, real_seconds: float) -> void:
	_slowmo_token += 1
	Engine.time_scale = scale
	after(real_seconds, _end_slowmo.bind(_slowmo_token))


func _end_slowmo(token: int) -> void:
	if token == _slowmo_token:
		Engine.time_scale = 1.0


# --- Loop ----------------------------------------------------------------

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel") or _start_pressed():
		_toggle_pause()


func _physics_process(delta: float) -> void:
	if get_tree().paused or not _is_fighting():
		return
	if weapons_enabled:
		_weapon_timer -= delta
		if _weapon_timer <= 0.0:
			_weapon_timer = randf_range(WEAPON_INTERVAL.x, WEAPON_INTERVAL.y)
			if get_tree().get_nodes_in_group(&"pickups").size() < MAX_PICKUPS:
				var x := randf_range(-Arena.HALF_WIDTH + 120.0, Arena.HALF_WIDTH - 120.0)
				drop_weapon(WeaponLibrary.random_weapon(), Vector2(x, -900.0))
	_collect_pickups()


func _collect_pickups() -> void:
	for node in get_tree().get_nodes_in_group(&"pickups"):
		var p := node as WeaponPickup
		if p.is_queued_for_deletion() or not p.grounded:
			continue
		for f in fighters:
			if not f.is_alive() or f.weapon != null or f.states.current_name in [&"hitstun", &"knockdown", &"ko"]:
				continue
			if p.grab_rect().intersects(f.hurtbox_rect()):
				f.equip(p.weapon)
				Effects.ring(fx_layer, p.global_position + Vector2(0, -34), p.weapon.color)
				Effects.popup(fx_layer, f.global_position + Vector2(0, -130), p.weapon.display_name.to_upper(), p.weapon.color, 26)
				Sfx.play(&"parry", 1.6, -10.0)
				p.remove_from_group(&"pickups")
				p.queue_free()
				break


func _start_pressed() -> bool:
	for pad in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_START):
			if not _start_held.has(pad):
				_start_held[pad] = true
				return true
		else:
			_start_held.erase(pad)
	return false


# --- Juice ---------------------------------------------------------------

func _on_hit(info: Dictionary) -> void:
	var atk: AttackData = info["attack"]
	var point: Vector2 = info["point"]
	var attacker: Fighter = info["attacker"]
	var target: Fighter = info["target"]
	if GameState.log_events:
		print("[hit] %s -> %s  %s  result=%d  hp=%.0f  combo=%d  weapon=%s" % [attacker.display_name, target.display_name, atk.id, info["result"], target.health, target.combo_taken, attacker.weapon.id if attacker.weapon else &"none"])
	match info["result"]:
		Fighter.HitResult.HIT:
			var counter: bool = info["counter"]
			var tint := attacker.weapon.color if attacker.weapon else (Color(1.0, 0.75, 0.3) if atk.heavy_hit else Color.WHITE)
			Effects.spark(fx_layer, point, tint, 1.4 if atk.heavy_hit or counter else 0.9)
			Sfx.play(&"hit_heavy" if atk.heavy_hit else &"hit_light")
			if attacker.weapon:
				Sfx.play(&"block", 1.4, -8.0)
			camera.add_trauma(atk.shake * 0.06 + (0.3 if counter else 0.0))
			if counter:
				Effects.popup(fx_layer, point + Vector2(0, -50), "COUNTER!", Color(1.0, 0.35, 0.3), 38)
				Effects.ring(fx_layer, point, Color(1.0, 0.35, 0.3))
				slowmo(0.35, 0.18)
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
			slowmo(0.3, 0.25)


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
		&"weapon_break":
			var col: Color = data.get("color", Color.WHITE)
			Effects.spark(fx_layer, pos, col, 1.5)
			Effects.popup(fx_layer, pos + Vector2(0, -30), "BROKEN!", col, 28)
			Sfx.play(&"block", 0.6, 0.0)
			camera.add_trauma(0.25)
		&"weapon_drop":
			if weapons_enabled:
				drop_weapon.call_deferred(data["weapon"], pos, Vector2(randf_range(-150.0, 150.0), -420.0))


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
	for entry in [["Resume", _toggle_pause], ["Restart", restart], ["Main Menu", to_menu]]:
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


func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
