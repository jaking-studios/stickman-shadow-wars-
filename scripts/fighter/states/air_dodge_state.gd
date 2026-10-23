extends FighterState
## Directional air dodge (once per airtime). Touching the ground during it
## slides into a landing, so it doubles as a movement tool.

const DURATION := 18
const SPEED := 560.0

var _spin_dir := 1.0


func enter(_msg: Dictionary) -> void:
	var f := fighter
	f.air_dodge_available = false
	var dir := Vector2(f.input.move_x, (1.0 if f.input.down else 0.0) - (1.0 if f.input.up else 0.0))
	f.velocity = dir.normalized() * SPEED if dir.length() > 0.2 else Vector2.ZERO
	_spin_dir = 1.0 if f.velocity.x * f.facing >= 0.0 else -1.0
	f.rig.set_pose(&"roll", 30.0)
	Sfx.play(&"whoosh", 0.75, -8.0)


func exit() -> void:
	fighter.rig.spin = 0.0


func is_invulnerable() -> bool:
	return frames >= 2 and frames <= 13


func solid() -> bool:
	return false


func update(delta: float) -> void:
	var f := fighter
	if frames < 12:
		f.velocity *= 0.92
	else:
		f.apply_gravity(delta)
	f.rig.spin = TAU * float(frames) / DURATION * _spin_dir
	f.move_and_slide()
	if f.is_on_floor() and frames > 1:
		change(&"ground")
	elif frames >= DURATION:
		change(&"air")
