class_name Fighter
extends CharacterBody2D
## A stickman fighter. Owns physics, health and the combat state machine.
## How it is controlled lives in its FighterInput (player, CPU, network);
## how it looks lives in its StickRig; what its attacks do lives in its
## moveset of AttackData.

enum HitResult { MISS, HIT, BLOCKED, PARRIED }

const RUN_SPEED := 340.0
const AIR_SPEED := 320.0
const GROUND_ACCEL := 2800.0
const GROUND_FRICTION := 2400.0
const AIR_ACCEL := 1600.0
const JUMP_VELOCITY := -680.0
const DOUBLE_JUMP_VELOCITY := -580.0
const GRAVITY := 1750.0
const FAST_FALL_GRAVITY := 3200.0
const MAX_FALL_SPEED := 980.0
const HURTBOX := Rect2(-15, -92, 30, 92)
const PLATFORM_LAYER := 3
const COUNTER_WINDOW := 50
const PUSH_RADIUS := 30.0
static var UNARMED := MoveLibrary.unarmed()

const STATES := {
	&"ground": preload("res://scripts/fighter/states/ground_state.gd"),
	&"air": preload("res://scripts/fighter/states/air_state.gd"),
	&"attack": preload("res://scripts/fighter/states/attack_state.gd"),
	&"block": preload("res://scripts/fighter/states/block_state.gd"),
	&"dodge": preload("res://scripts/fighter/states/dodge_state.gd"),
	&"air_dodge": preload("res://scripts/fighter/states/air_dodge_state.gd"),
	&"hitstun": preload("res://scripts/fighter/states/hitstun_state.gd"),
	&"knockdown": preload("res://scripts/fighter/states/knockdown_state.gd"),
	&"recover": preload("res://scripts/fighter/states/recover_state.gd"),
	&"ko": preload("res://scripts/fighter/states/ko_state.gd"),
}

@export var player_index := 0
@export var display_name := "PLAYER 1"
@export var body_color := Color(0.9, 0.94, 1.0)
@export var aura_color := Color(0.3, 0.6, 1.0, 1.0)
@export var max_health := 100.0
## Fighters on the same team never hit or target each other.
@export var team := 0
@export var eye_color := Color(0.04, 0.04, 0.07)
## Draws a small health bar above the head (survival enemies).
@export var show_overhead_bar := false

var health := 100.0
var facing := 1
var input: FighterInput = FighterInput.new()
var moveset: Dictionary = UNARMED
var weapon: WeaponData
var weapon_uses := 0
var air_jumps := 1
var air_dodge_available := true
var hitstop := 0
## While > 0 the next landed hit is a counter (set by a successful parry).
var counter_frames := 0
## Hits taken in the current combo (resets when the fighter recovers).
var combo_taken := 0
var frame := 0
var last_block_release := -100
var last_roll_end := -100

var rig: StickRig
var states: StateMachine

var _drop_frames := 0


func _ready() -> void:
	add_to_group(&"fighters")
	z_index = 5
	collision_layer = 0
	set_collision_layer_value(2, true)
	collision_mask = 0
	set_collision_mask_value(1, true)
	set_collision_mask_value(PLATFORM_LAYER, true)
	floor_snap_length = 8.0

	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 13.0
	capsule.height = 88.0
	shape.shape = capsule
	shape.position = Vector2(0, -44)
	add_child(shape)

	rig = StickRig.new()
	rig.color = body_color
	rig.aura_color = aura_color
	rig.eye_color = eye_color
	add_child(rig)

	health = max_health
	states = StateMachine.new(self)
	for state_name in STATES:
		states.add(state_name, STATES[state_name].new())
	states.change(&"ground")


func _physics_process(delta: float) -> void:
	frame += 1
	if input.enabled:
		input.poll(self)
	else:
		input.clear()
	if _drop_frames > 0:
		_drop_frames -= 1
		if _drop_frames == 0:
			set_collision_mask_value(PLATFORM_LAYER, true)
	if hitstop > 0:
		hitstop -= 1
		rig.frozen = true
		return
	rig.frozen = false
	if counter_frames > 0:
		counter_frames -= 1
	states.update(delta)
	_separate()
	rig.scale.x = facing
	rig.locomotion_speed = velocity.x
	rig.health_ratio = health / max_health
	input.age()
	queue_redraw()


func _draw() -> void:
	if is_on_floor() and not rig.ragdoll_active:
		draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.25))
		draw_circle(Vector2.ZERO, 28.0, Color(0, 0, 0, 0.4))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if show_overhead_bar and is_alive():
		var w := 46.0
		draw_rect(Rect2(-w * 0.5 - 1, -122, w + 2, 7), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-w * 0.5, -121, w * health / max_health, 5), aura_color.lightened(0.2))
	if GameState.debug_hitboxes:
		draw_rect(HURTBOX, Color(0.2, 1.0, 0.3, 0.25))
		var atk := current_attack()
		if atk and attack_phase() == &"active":
			var box := attack_rect(atk)
			box.position -= global_position
			draw_rect(box, Color(1.0, 0.2, 0.2, 0.45))


# --- Movement helpers used by states -------------------------------------

func apply_gravity(delta: float, gravity_scale := 1.0, allow_fast_fall := true) -> void:
	var g := FAST_FALL_GRAVITY if allow_fast_fall and input.down and velocity.y > 0.0 else GRAVITY
	velocity.y = minf(velocity.y + g * gravity_scale * delta, MAX_FALL_SPEED)


func ground_move(delta: float) -> void:
	var target_speed := input.move_x * RUN_SPEED * mobility()
	var rate := GROUND_ACCEL if absf(input.move_x) > 0.1 else GROUND_FRICTION
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)


func air_move(delta: float) -> void:
	if absf(input.move_x) > 0.1:
		velocity.x = move_toward(velocity.x, input.move_x * AIR_SPEED * mobility(), AIR_ACCEL * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, AIR_ACCEL * 0.25 * delta)


## Damage visibly slows you down: up to 20% slower at low health.
func mobility() -> float:
	return lerpf(0.8, 1.0, health / max_health)


func on_platform() -> bool:
	for i in get_slide_collision_count():
		var body := get_slide_collision(i).get_collider() as CollisionObject2D
		if body and body.get_collision_layer_value(PLATFORM_LAYER):
			return true
	return false


func drop_through() -> void:
	set_collision_mask_value(PLATFORM_LAYER, false)
	_drop_frames = 14
	position.y += 2.0


# --- Targeting -----------------------------------------------------------

func target() -> Fighter:
	var best: Fighter = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group(&"fighters"):
		var other := node as Fighter
		if other == self or other.team == team or not other.is_alive():
			continue
		var d := global_position.distance_squared_to(other.global_position)
		if d < best_dist:
			best_dist = d
			best = other
	return best


func face_target() -> void:
	var t := target()
	if t:
		var dx := t.global_position.x - global_position.x
		if absf(dx) > 4.0:
			facing = 1 if dx > 0.0 else -1


func focus_point() -> Vector2:
	if rig.ragdoll_active:
		return rig.ragdoll_center()
	return global_position + Vector2(0, -50)


func is_alive() -> bool:
	return health > 0.0


# --- Attacks -------------------------------------------------------------

func pick_light() -> StringName:
	if not is_on_floor():
		return &"air_light"
	if frame - last_roll_end <= 10:
		return &"dash_strike"
	return &"light1"


func pick_heavy() -> StringName:
	if not is_on_floor():
		return &"air_heavy"
	if input.down:
		return &"launcher"
	if absf(velocity.x) > RUN_SPEED * 0.85 and signf(velocity.x) == float(facing):
		return &"dash_strike"
	return &"heavy"


# --- Weapons -------------------------------------------------------------

func equip(new_weapon: WeaponData) -> void:
	weapon = new_weapon
	weapon_uses = new_weapon.durability
	moveset = new_weapon.moveset
	rig.weapon = new_weapon


func unequip() -> void:
	weapon = null
	moveset = UNARMED
	rig.weapon = null


## Called by the attack state whenever a weapon swing connects.
func wear_weapon() -> void:
	if weapon == null:
		return
	weapon_uses -= 1
	if weapon_uses <= 0:
		CombatBus.fx.emit(&"weapon_break", rig.to_global(rig.joints.get(&"blade_tip", Vector2.ZERO)), {"color": weapon.color})
		unequip()


func start_attack(id: StringName) -> void:
	if moveset.has(id):
		states.change(&"attack", {"id": id})


func current_attack() -> AttackData:
	if states.current_name == &"attack":
		return states.current.atk
	return null


func attack_phase() -> StringName:
	if states.current_name == &"attack":
		return states.current.phase()
	return &""


## True while this fighter's attack is about to (or does) overlap `other`.
## The CPU uses this as its "I see it coming" signal.
func threatens(other: Fighter) -> bool:
	var atk := current_attack()
	if atk == null or attack_phase() == &"recovery":
		return false
	return attack_rect(atk).grow(30.0).intersects(other.hurtbox_rect())


func hurtbox_rect() -> Rect2:
	return Rect2(global_position + HURTBOX.position, HURTBOX.size)


func attack_rect(atk: AttackData) -> Rect2:
	var box := atk.hitbox
	if facing < 0:
		box.position.x = -box.position.x - box.size.x
	return Rect2(global_position + box.position, box.size)


## Resolves an incoming attack: dodge, parry, block or clean hit.
func receive_hit(attacker: Fighter, atk: AttackData, point: Vector2) -> HitResult:
	if not is_alive() or states.current.is_invulnerable():
		return HitResult.MISS
	var info := {"attacker": attacker, "target": self, "attack": atk, "point": point, "counter": false, "damage": 0.0}
	var dx := attacker.global_position.x - global_position.x
	var from_front := absf(dx) < 6.0 or signf(dx) == float(facing)

	if states.current_name == &"block" and from_front:
		var guard = states.current
		if guard.in_parry_window():
			hitstop = 12
			attacker.hitstop = 12
			counter_frames = COUNTER_WINDOW
			attacker.states.change(&"hitstun", {"knockback": Vector2(-attacker.facing * 140.0, 0.0), "frames": 38, "stagger": true})
			states.change(&"ground")
			info["result"] = HitResult.PARRIED
			CombatBus.hit_resolved.emit(info)
			return HitResult.PARRIED
		health = maxf(minf(health, 1.0), health - atk.chip)
		guard.apply_blockstun(atk.blockstun)
		velocity.x = signf(-dx) * maxf(140.0, absf(atk.knockback.x) * 0.45)
		hitstop = atk.hit_stop / 2
		attacker.hitstop = hitstop
		info["result"] = HitResult.BLOCKED
		CombatBus.hit_resolved.emit(info)
		return HitResult.BLOCKED

	var damage := atk.damage
	if attacker.counter_frames > 0:
		damage *= 1.5
		attacker.counter_frames = 0
		info["counter"] = true
	if states.current_name != &"hitstun":
		combo_taken = 0
	combo_taken += 1
	health = maxf(0.0, health - damage)
	info["damage"] = damage

	# Knockback grows as health drops; hitstun decays through long combos.
	var kb_scale := 1.0 + (1.0 - health / max_health) * 0.6
	var kb := Vector2(atk.knockback.x * attacker.facing, atk.knockback.y) * kb_scale
	var stun := maxi(10, atk.hitstun - combo_taken * 2)
	hitstop = atk.hit_stop + (5 if info["counter"] else 0)
	attacker.hitstop = hitstop
	facing = -attacker.facing
	rig.hit_flash()
	info["result"] = HitResult.HIT

	if health <= 0.0:
		hitstop = 0
		states.change(&"ko", {"knockback": kb * 1.3 + Vector2(0, -200)})
		CombatBus.hit_resolved.emit(info)
		CombatBus.fighter_ko.emit(self, attacker)
	else:
		states.change(&"hitstun", {"knockback": kb, "frames": stun, "launch": atk.launcher})
		CombatBus.hit_resolved.emit(info)
	return HitResult.HIT


# --- Round flow ----------------------------------------------------------

func reset_for_round(spawn: Vector2, face: int) -> void:
	global_position = spawn
	velocity = Vector2.ZERO
	health = max_health
	facing = face
	hitstop = 0
	counter_frames = 0
	combo_taken = 0
	rig.stop_ragdoll()
	unequip()
	rig.spin = 0.0
	rig.scale.x = facing
	states.change(&"ground")


func celebrate() -> void:
	if is_alive():
		states.change(&"recover", {"frames": 1000000, "pose": &"victory"})


## Fighters can overlap mid-roll, but otherwise gently push each other apart.
func _separate() -> void:
	if not states.current.solid():
		return
	for node in get_tree().get_nodes_in_group(&"fighters"):
		var other := node as Fighter
		if other == self or not other.states.current.solid():
			continue
		var d := global_position - other.global_position
		if absf(d.x) < PUSH_RADIUS and absf(d.y) < 70.0:
			var dir := signf(d.x) if d.x != 0.0 else float(-facing)
			move_and_collide(Vector2((PUSH_RADIUS - absf(d.x)) * 0.5 * dir, 0.0))
