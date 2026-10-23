class_name AIInput
extends FighterInput
## CPU opponent. It drives the fighter through the same intents a human uses
## (move, hold, press), so it obeys every rule a player does.
##
## It only "sees" the world on think ticks spaced by its reaction time, reads
## incoming attacks (block / parry / roll), punishes whiffs, anti-airs,
## leads moving targets, continues combos on hit, and adapts by counting the
## opponent's habits (jump-ins and heavy attacks).

const PROFILES := [
	{"name": "Easy", "react": 26, "jitter": 10, "aggression": 0.35, "guard": 0.25, "parry": 0.0, "dodge": 0.15, "combo": 0.3, "anti_air": 0.15, "predict": 0.0},
	{"name": "Normal", "react": 16, "jitter": 6, "aggression": 0.55, "guard": 0.5, "parry": 0.12, "dodge": 0.2, "combo": 0.6, "anti_air": 0.35, "predict": 0.1},
	{"name": "Hard", "react": 9, "jitter": 4, "aggression": 0.7, "guard": 0.65, "parry": 0.3, "dodge": 0.25, "combo": 0.85, "anti_air": 0.6, "predict": 0.2},
	{"name": "Nightmare", "react": 4, "jitter": 2, "aggression": 0.85, "guard": 0.8, "parry": 0.6, "dodge": 0.25, "combo": 1.0, "anti_air": 0.85, "predict": 0.28},
]
const CLOSE_RANGE := 80.0

var profile: Dictionary
var _think := 0
var _move := 0.0
var _move_frames := 0
var _block_frames := 0
var _down_frames := 0
var _seen := {"jump_in": 0, "heavy": 0}
var _last_target_state: StringName = &""


func _init(difficulty := 1) -> void:
	profile = PROFILES[clampi(difficulty, 0, PROFILES.size() - 1)]


func poll(f: Fighter) -> void:
	move_x = 0.0
	up = false
	var t := f.target()
	if t == null:
		down = false
		block = false
		return
	_observe(f, t)
	_think -= 1
	if _think <= 0:
		_think = int(profile.react) + randi() % (int(profile.jitter) + 1)
		_decide(f, t)
	_follow_up(f, t)

	if _move_frames > 0:
		_move_frames -= 1
		move_x = _move
	block = _block_frames > 0
	if _block_frames > 0:
		_block_frames -= 1
	down = _down_frames > 0
	if _down_frames > 0:
		_down_frames -= 1


## Count the opponent's habits so the CPU leans into the right answer.
func _observe(f: Fighter, t: Fighter) -> void:
	var s := t.states.current_name
	if s == _last_target_state:
		return
	_last_target_state = s
	if s == &"attack":
		var atk := t.current_attack()
		if atk and atk.heavy_hit:
			_seen.heavy += 1
		if atk and atk.air and t.global_position.y < f.global_position.y - 40.0:
			_seen.jump_in += 1


func _decide(f: Fighter, t: Fighter) -> void:
	var me := f.global_position
	var lead: Vector2 = t.velocity * float(profile.predict)
	var dx := t.global_position.x + lead.x - me.x
	var dist := absf(dx)
	var dir := signf(dx) if dx != 0.0 else float(f.facing)
	var dy := t.global_position.y - me.y

	# 1. Defend against an attack that is coming.
	if t.threatens(f) and randf() < float(profile.guard) + minf(0.2, _seen.heavy * 0.02):
		var r := randf()
		if r < float(profile.parry):
			_block_frames = 10
		elif r < float(profile.parry) + float(profile.dodge):
			press(&"dodge")
			_move = -dir if randf() < 0.6 else dir
			_move_frames = 2
		else:
			_block_frames = 24
		return

	# 2. Punish a whiffed attack.
	if t.attack_phase() == &"recovery" and dist < 120.0 and randf() < float(profile.aggression):
		_move = dir
		_move_frames = 3
		press(&"heavy" if dist > 60.0 else &"light")
		return

	# 3. Anti-air a jump-in.
	var anti_air := float(profile.anti_air) + minf(0.3, _seen.jump_in * 0.04)
	if dy < -70.0 and dist < 110.0 and t.states.current_name in [&"air", &"attack"] and randf() < anti_air:
		_down_frames = 4
		press(&"heavy")
		return

	# 4. Follow a target standing on a platform above.
	if dy < -120.0 and dist < 280.0 and f.is_on_floor():
		press(&"jump")
		_move = dir
		_move_frames = 24
		return

	# 5. Close the distance.
	if dist > CLOSE_RANGE:
		_move = dir
		_move_frames = int(profile.react) + 4
		if dist > 300.0 and randf() < 0.12:
			press(&"jump")
		return

	# 6. In range: attack, guard, or step back to bait.
	if randf() < float(profile.aggression):
		var r := randf()
		if r < 0.6:
			press(&"light")
		elif r < 0.82:
			press(&"heavy")
		else:
			_down_frames = 3
			press(&"heavy")
	elif randf() < 0.5:
		_block_frames = 14
	else:
		_move = -dir
		_move_frames = 8


## Every frame: keep a landed combo going.
func _follow_up(f: Fighter, t: Fighter) -> void:
	var s := f.states.current_name
	var chance := float(profile.combo) * 0.35
	if s == &"attack" and f.states.current.connected:
		if randf() > chance:
			return
		match f.current_attack().id:
			&"light1", &"air_light":
				press(&"light")
			&"light2":
				if randf() < 0.5:
					press(&"light")
				else:
					_down_frames = 3
					press(&"heavy")
			&"launcher":
				press(&"jump")
			&"air_light2":
				press(&"heavy")
	elif s == &"air" and t.states.current_name == &"hitstun" and f.global_position.distance_to(t.global_position) < 90.0:
		if randf() < chance:
			_move = signf(t.global_position.x - f.global_position.x)
			_move_frames = 4
			press(&"light")
	elif s == &"knockdown" and randf() < chance * 0.3:
		press(&"dodge")
