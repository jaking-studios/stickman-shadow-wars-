extends FighterState
## Plays one AttackData: startup -> active (hit checks) -> recovery, with
## combo chaining, jump-cancels on hit and landing lag for air attacks.

var atk: AttackData
var connected := false
var _hit: Array[Fighter] = []
var _chain: StringName = &""


func enter(msg: Dictionary) -> void:
	var f := fighter
	atk = f.moveset[msg["id"]]
	connected = false
	_hit.clear()
	_chain = &""
	f.rig.set_pose(atk.pose_windup, 26.0)
	f.velocity.x *= atk.keep_momentum
	if atk.air and f.velocity.y > 0.0:
		f.velocity.y *= 0.4


func exit() -> void:
	fighter.rig.trail_joint = &""


func phase() -> StringName:
	if frames <= atk.startup:
		return &"startup"
	if frames <= atk.startup + atk.active:
		return &"active"
	return &"recovery"


func update(delta: float) -> void:
	var f := fighter
	var active_start := atk.startup + 1
	var active_end := atk.startup + atk.active

	if frames == active_start:
		f.rig.set_pose(atk.pose_strike, 48.0)
		f.rig.trail_joint = atk.trail_joint
		Sfx.play(&"whoosh", 1.15 if not atk.heavy_hit else 0.8, -6.0)
		if atk.lunge != 0.0:
			f.velocity.x = atk.lunge * f.facing
		if atk.dive_velocity != Vector2.ZERO:
			f.velocity = Vector2(atk.dive_velocity.x * f.facing, atk.dive_velocity.y)
	if frames >= active_start and frames <= active_end:
		_check_hits()
		if f.states.current != self:
			return
	if frames == active_end + 1:
		f.rig.trail_joint = &""

	_buffer_chain()
	if _chain != &"" and frames >= active_end + atk.chain_delay:
		f.start_attack(_chain)
		return
	if connected and atk.jump_cancel and frames > active_end and f.input.consume(&"jump"):
		f.velocity = Vector2(f.input.move_x * Fighter.AIR_SPEED, Fighter.JUMP_VELOCITY * 1.2)
		Sfx.play(&"jump", 1.3, -6.0)
		change(&"air")
		return

	if f.is_on_floor() and not atk.air:
		f.velocity.x = move_toward(f.velocity.x, 0.0, Fighter.GROUND_FRICTION * 0.5 * delta)
	f.apply_gravity(delta, atk.gravity_scale, false)
	f.move_and_slide()

	if atk.air and frames > 2 and f.is_on_floor():
		if atk.dive_velocity != Vector2.ZERO:
			CombatBus.fx.emit(&"slam", f.global_position, {})
		change(&"recover", {"frames": atk.landing_lag, "pose": &"land"})
		return
	if frames >= active_end + atk.recovery:
		settle()


func _buffer_chain() -> void:
	if _chain != &"" or frames <= atk.startup:
		return
	var inp := fighter.input
	if atk.next_light != &"" and inp.consume(&"light"):
		_chain = atk.next_light
	elif atk.chain_heavy and inp.consume(&"heavy"):
		_chain = fighter.pick_heavy()


func _check_hits() -> void:
	var f := fighter
	var box := f.attack_rect(atk)
	for node in f.get_tree().get_nodes_in_group(&"fighters"):
		var other := node as Fighter
		if other == f or other in _hit or not other.is_alive():
			continue
		var hurt := other.hurtbox_rect()
		if not box.intersects(hurt):
			continue
		var result := other.receive_hit(f, atk, box.intersection(hurt).get_center())
		if result == Fighter.HitResult.MISS:
			continue
		_hit.append(other)
		if result == Fighter.HitResult.HIT:
			connected = true
		if f.states.current != self:
			return
