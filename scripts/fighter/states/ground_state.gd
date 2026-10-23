extends FighterState
## Standing and running. The hub every other state returns to.


func enter(_msg: Dictionary) -> void:
	fighter.air_jumps = 1
	fighter.air_dodge_available = true


func update(delta: float) -> void:
	var f := fighter
	var inp := f.input
	if not f.is_on_floor():
		change(&"air")
		return
	if inp.down and inp.peek(&"jump") and f.on_platform():
		inp.consume(&"jump")
		f.drop_through()
		change(&"air")
		return
	if inp.consume(&"jump"):
		f.velocity.y = Fighter.JUMP_VELOCITY
		f.velocity.x = inp.move_x * Fighter.AIR_SPEED * f.mobility()
		Sfx.play(&"jump", 1.0, -8.0)
		CombatBus.fx.emit(&"dust", f.global_position, {})
		change(&"air")
		return
	if inp.consume(&"dodge"):
		change(&"dodge")
		return
	if inp.consume(&"heavy"):
		f.start_attack(f.pick_heavy())
		return
	if inp.consume(&"light"):
		f.start_attack(f.pick_light())
		return
	if inp.block:
		change(&"block")
		return

	if absf(inp.move_x) > 0.2:
		f.facing = 1 if inp.move_x > 0.0 else -1
	else:
		f.face_target()
	f.ground_move(delta)
	f.move_and_slide()
	f.rig.set_pose(&"run" if absf(f.velocity.x) > 40.0 else &"idle", 18.0)
