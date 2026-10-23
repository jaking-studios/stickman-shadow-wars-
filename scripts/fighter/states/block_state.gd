extends FighterState
## Guarding. The first PARRY_WINDOW frames of a fresh block are a perfect
## parry: the attacker is staggered and the defender's next hit is a counter.
## Re-blocking too quickly gives no parry window, so mashing doesn't work.

const PARRY_WINDOW := 8
const PARRY_COOLDOWN := 16

var _parry_left := 0
var _stun := 0


func enter(_msg: Dictionary) -> void:
	var f := fighter
	f.face_target()
	_parry_left = PARRY_WINDOW if f.frame - f.last_block_release > PARRY_COOLDOWN else 0
	_stun = 0
	f.rig.set_pose(&"block", 30.0)


func exit() -> void:
	fighter.last_block_release = fighter.frame


func in_parry_window() -> bool:
	return _parry_left > 0


func apply_blockstun(frames_of_stun: int) -> void:
	_stun = frames_of_stun


func update(delta: float) -> void:
	var f := fighter
	if _parry_left > 0:
		_parry_left -= 1
	f.velocity.x = move_toward(f.velocity.x, 0.0, Fighter.GROUND_FRICTION * 0.6 * delta)
	f.apply_gravity(delta, 1.0, false)
	f.move_and_slide()
	if _stun > 0:
		_stun -= 1
		return
	if not f.is_on_floor():
		change(&"air")
	elif f.input.consume(&"dodge"):
		change(&"dodge")
	elif not f.input.block:
		change(&"ground")
	else:
		f.face_target()
