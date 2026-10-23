class_name MoveLibrary
extends RefCounted
## Movesets are Dictionaries of AttackData keyed by id. The fighter only knows
## the entry ids (light1, heavy, launcher, dash_strike, air_light, air_heavy);
## everything after an entry is reached through each move's chain fields.
## A weapon or style swaps the whole dictionary, so a katana moveset is a new
## function here (or a folder of .tres files), not new fighter code.


static func unarmed() -> Dictionary:
	var m := {}
	# Ground string: jab -> cross -> roundhouse kick. Heavy can cut in after 1 or 2.
	_add(m, &"light1", {
		"startup": 4, "active": 3, "recovery": 10, "damage": 4.0,
		"hitbox": Rect2(6, -80, 42, 22), "knockback": Vector2(140, -20), "hitstun": 18,
		"lunge": 120.0, "next_light": &"light2", "chain_heavy": true,
		"pose_windup": &"jab_wind", "pose_strike": &"jab", "trail_joint": &"hand_f",
	})
	_add(m, &"light2", {
		"startup": 5, "active": 3, "recovery": 11, "damage": 5.0,
		"hitbox": Rect2(6, -82, 46, 22), "knockback": Vector2(170, -20), "hitstun": 19,
		"lunge": 140.0, "next_light": &"light3", "chain_heavy": true,
		"pose_windup": &"cross_wind", "pose_strike": &"cross", "trail_joint": &"hand_b",
	})
	_add(m, &"light3", {
		"startup": 7, "active": 4, "recovery": 16, "damage": 8.0,
		"hitbox": Rect2(4, -64, 56, 28), "knockback": Vector2(430, -190), "hitstun": 28,
		"hit_stop": 7, "shake": 4.0, "heavy_hit": true, "lunge": 180.0,
		"pose_windup": &"kick_wind", "pose_strike": &"kick", "trail_joint": &"foot_f",
	})
	_add(m, &"heavy", {
		"startup": 13, "active": 4, "recovery": 20, "damage": 13.0, "chip": 2.0,
		"hitbox": Rect2(4, -86, 60, 32), "knockback": Vector2(580, -250), "hitstun": 32,
		"blockstun": 14, "hit_stop": 9, "shake": 7.0, "heavy_hit": true, "lunge": 260.0,
		"pose_windup": &"heavy_wind", "pose_strike": &"heavy", "trail_joint": &"hand_f",
	})
	_add(m, &"launcher", {
		"startup": 9, "active": 5, "recovery": 18, "damage": 9.0,
		"hitbox": Rect2(-4, -124, 50, 74), "knockback": Vector2(60, -880), "hitstun": 42,
		"hit_stop": 7, "shake": 5.0, "launcher": true, "heavy_hit": true, "jump_cancel": true,
		"lunge": 90.0, "pose_windup": &"uppercut_wind", "pose_strike": &"uppercut", "trail_joint": &"hand_f",
	})
	_add(m, &"dash_strike", {
		"startup": 6, "active": 7, "recovery": 16, "damage": 10.0, "chip": 1.0,
		"hitbox": Rect2(-2, -82, 52, 46), "knockback": Vector2(500, -320), "hitstun": 30,
		"hit_stop": 7, "shake": 5.0, "heavy_hit": true, "lunge": 640.0, "keep_momentum": 0.0,
		"pose_windup": &"dash_wind", "pose_strike": &"dash", "trail_joint": &"foot_f",
	})
	# Air: flying kick -> spinning kick, plus a diving slam that spikes downward.
	_add(m, &"air_light", {
		"startup": 4, "active": 5, "recovery": 10, "damage": 6.0, "air": true, "landing_lag": 4,
		"hitbox": Rect2(2, -76, 54, 36), "knockback": Vector2(230, -230), "hitstun": 24,
		"keep_momentum": 0.85, "gravity_scale": 0.55, "next_light": &"air_light2",
		"pose_windup": &"air_kick_wind", "pose_strike": &"air_kick", "trail_joint": &"foot_f",
	})
	_add(m, &"air_light2", {
		"startup": 6, "active": 5, "recovery": 14, "damage": 7.0, "air": true, "landing_lag": 6,
		"hitbox": Rect2(-6, -96, 60, 48), "knockback": Vector2(330, -300), "hitstun": 26,
		"hit_stop": 6, "shake": 3.0, "keep_momentum": 0.85, "gravity_scale": 0.6,
		"chain_heavy": true,
		"pose_windup": &"air_kick_wind", "pose_strike": &"air_spin", "trail_joint": &"foot_f",
	})
	_add(m, &"air_heavy", {
		"startup": 10, "active": 14, "recovery": 12, "damage": 11.0, "air": true, "landing_lag": 14,
		"hitbox": Rect2(-22, -44, 64, 54), "knockback": Vector2(120, 720), "hitstun": 30,
		"hit_stop": 8, "shake": 8.0, "launcher": true, "heavy_hit": true,
		"dive_velocity": Vector2(140, 1050), "keep_momentum": 0.4, "gravity_scale": 0.3,
		"pose_windup": &"slam_wind", "pose_strike": &"slam", "trail_joint": &"hand_f",
	})
	return m


static func _add(moves: Dictionary, id: StringName, props: Dictionary) -> void:
	var attack := AttackData.new()
	attack.id = id
	for key in props:
		attack.set(key, props[key])
	moves[id] = attack
