extends FighterState
## Getting hit. Grounded hits slide the fighter back; launched or airborne hits
## tumble until landing (one floor bounce for hard spikes, then knockdown).
## Slamming into a wall at speed is a wall splat: extra damage and hitstun.

const WALL_SPLAT_SPEED := 450.0
const BOUNCE_SPEED := 420.0

var _stun := 0
var _tumbling := false
var _bounced := false
var _splatted := false


func enter(msg: Dictionary) -> void:
	var f := fighter
	f.velocity = msg.get("knockback", Vector2.ZERO)
	_stun = msg.get("frames", 20)
	_tumbling = msg.get("launch", false) or f.velocity.y < -260.0 or not f.is_on_floor()
	_bounced = false
	_splatted = false
	f.rig.trail_joint = &""
	if msg.get("stagger", false):
		f.rig.set_pose(&"parried", 30.0)
	elif _tumbling:
		f.rig.set_pose(&"tumble", 30.0)
	else:
		f.rig.set_pose(&"hurt", 40.0)


func update(delta: float) -> void:
	var f := fighter
	var prev := f.velocity
	if f.is_on_floor() and not _tumbling:
		f.velocity.x = move_toward(f.velocity.x, 0.0, 1500.0 * delta)
	f.apply_gravity(delta, 0.85, false)
	f.move_and_slide()

	if not _splatted and f.is_on_wall() and absf(prev.x) > WALL_SPLAT_SPEED:
		_splatted = true
		f.velocity.x = -prev.x * 0.35
		f.health = maxf(1.0, f.health - 3.0)
		_stun += 8
		CombatBus.fx.emit(&"wall_splat", f.global_position + Vector2(signf(prev.x) * 14.0, -50.0), {})

	if _tumbling and frames > 3 and f.is_on_floor() and prev.y >= 0.0:
		if prev.y > BOUNCE_SPEED and not _bounced:
			_bounced = true
			f.velocity = Vector2(prev.x * 0.6, -prev.y * 0.35)
			CombatBus.fx.emit(&"dust", f.global_position, {"big": true})
		else:
			change(&"knockdown")
			return

	if frames >= _stun:
		if not _tumbling:
			settle()
		elif not f.is_on_floor():
			change(&"air")
