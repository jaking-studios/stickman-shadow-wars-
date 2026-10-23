extends FighterState
## Ground dodge roll with invincibility frames. Rolls toward the held
## direction (backwards if neutral). Attacking at the end becomes a dash strike.

const DURATION := 22
const IFRAME_START := 2
const IFRAME_END := 15
const SPEED := 540.0

var _dir := 1


func enter(_msg: Dictionary) -> void:
	var f := fighter
	_dir = (1 if f.input.move_x > 0.0 else -1) if absf(f.input.move_x) > 0.2 else -f.facing
	f.velocity.x = _dir * SPEED
	f.rig.set_pose(&"roll", 30.0)
	f.rig.trail_joint = &""
	Sfx.play(&"whoosh", 0.7, -8.0)
	CombatBus.fx.emit(&"dust", f.global_position, {})


func exit() -> void:
	fighter.rig.spin = 0.0


func is_invulnerable() -> bool:
	return frames >= IFRAME_START and frames <= IFRAME_END


func solid() -> bool:
	return false


func update(delta: float) -> void:
	var f := fighter
	f.rig.spin = TAU * float(frames) / DURATION * _dir * f.facing
	if frames > 14:
		f.velocity.x = move_toward(f.velocity.x, 0.0, 2600.0 * delta)
	f.apply_gravity(delta, 1.0, false)
	f.move_and_slide()
	if frames > DURATION - 8 and (f.input.consume(&"light") or f.input.consume(&"heavy")):
		f.facing = _dir
		f.start_attack(&"dash_strike")
		return
	if frames >= DURATION:
		f.last_roll_end = f.frame
		settle()
