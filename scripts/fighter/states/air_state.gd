extends FighterState
## Airborne movement: double jump (with a front flip), air dodge, air attacks.

const FLIP_FRAMES := 22

var _flip := -1


func enter(_msg: Dictionary) -> void:
	_flip = -1


func exit() -> void:
	fighter.rig.spin = 0.0


func update(delta: float) -> void:
	var f := fighter
	var inp := f.input
	if f.is_on_floor() and f.velocity.y >= 0.0:
		CombatBus.fx.emit(&"dust", f.global_position, {})
		Sfx.play(&"land", 1.0, -10.0)
		change(&"ground")
		return
	if inp.consume(&"jump") and f.air_jumps > 0:
		f.air_jumps -= 1
		f.velocity.y = Fighter.DOUBLE_JUMP_VELOCITY
		if absf(inp.move_x) > 0.2:
			f.velocity.x = inp.move_x * Fighter.AIR_SPEED * f.mobility()
		_flip = 0
		Sfx.play(&"jump", 1.2, -8.0)
		CombatBus.fx.emit(&"jump", f.global_position, {})
	if inp.consume(&"dodge") and f.air_dodge_available:
		change(&"air_dodge")
		return
	if inp.consume(&"heavy"):
		f.start_attack(&"air_heavy")
		return
	if inp.consume(&"light"):
		f.start_attack(&"air_light")
		return

	if absf(inp.move_x) > 0.2:
		f.facing = 1 if inp.move_x > 0.0 else -1
	f.air_move(delta)
	f.apply_gravity(delta)
	f.move_and_slide()

	f.rig.set_pose(&"jump" if f.velocity.y < 0.0 else &"fall", 10.0)
	if _flip >= 0:
		_flip += 1
		f.rig.spin = TAU * minf(1.0, float(_flip) / FLIP_FRAMES)
		if _flip >= FLIP_FRAMES:
			_flip = -1
			f.rig.spin = 0.0
