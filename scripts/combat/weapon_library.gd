class_name WeaponLibrary
extends RefCounted
## Every weapon in the game. Each moveset is derived from the unarmed one
## (same chains and entry ids) and then reshaped: longer reach, different
## speed, damage and knockback, and slashes instead of kicks.

const IDS: Array[StringName] = [&"katana", &"hammer", &"spear", &"plasma"]

static var _cache := {}


static func get_weapon(id: StringName) -> WeaponData:
	if _cache.is_empty():
		_build()
	return _cache.get(id)


static func random_weapon() -> WeaponData:
	return get_weapon(IDS[randi() % IDS.size()])


static func _build() -> void:
	_cache[&"katana"] = _make(&"katana", "Katana", &"blade", Color(0.92, 0.95, 1.0), 48.0, 18,
		{"reach": 34.0, "damage": 1.25, "speed": 0, "knockback": 1.0})
	_cache[&"hammer"] = _make(&"hammer", "War Hammer", &"hammer", Color(0.75, 0.68, 0.6), 42.0, 12,
		{"reach": 30.0, "damage": 1.6, "speed": 6, "knockback": 1.5, "heavy": true})
	_cache[&"spear"] = _make(&"spear", "Spear", &"spear", Color(0.85, 0.75, 0.5), 66.0, 16,
		{"reach": 58.0, "damage": 1.1, "speed": 2, "knockback": 1.1})
	_cache[&"plasma"] = _make(&"plasma", "Plasma Sword", &"plasma", Color(0.3, 1.0, 0.95), 52.0, 14,
		{"reach": 40.0, "damage": 1.4, "speed": -1, "knockback": 1.2})


static func _make(id: StringName, label: String, style: StringName, color: Color, length: float, durability: int, tune: Dictionary) -> WeaponData:
	var w := WeaponData.new()
	w.id = id
	w.display_name = label
	w.style = style
	w.color = color
	w.length = length
	w.durability = durability
	var moves := MoveLibrary.unarmed()
	var reach: float = tune["reach"]
	var speed: int = tune["speed"]
	for key in moves:
		var a: AttackData = moves[key]
		a.hitbox.size.x += reach
		a.hitbox = a.hitbox.grow_individual(0, 10, 0, 10)
		a.damage *= tune["damage"]
		a.chip = maxf(a.chip, a.damage * 0.12)
		a.knockback *= tune["knockback"]
		a.startup = maxi(2, a.startup + speed)
		a.recovery = maxi(6, a.recovery + speed)
		a.trail_joint = &"blade_tip"
		if tune.get("heavy", false):
			a.heavy_hit = true
			a.shake *= 1.6
			a.hit_stop += 2
	# Weapons slash where fists kick.
	_restyle(moves[&"light3"], &"slash_wind", &"slash", Rect2(0, -110, 56 + reach, 100))
	_restyle(moves[&"air_light"], &"slash_wind", &"slash", Rect2(-6, -112, 58 + reach, 104))
	_restyle(moves[&"air_light2"], &"air_kick_wind", &"jab", Rect2(-4, -96, 60 + reach, 48))
	if style == &"spear":
		# The spear thrusts everything straight ahead.
		for key in [&"light1", &"light2", &"heavy", &"dash_strike"]:
			var a: AttackData = moves[key]
			a.pose_strike = &"jab"
			a.hitbox = Rect2(0, -90, 66 + reach, 26)
	w.moveset = moves
	return w


static func _restyle(a: AttackData, windup: StringName, strike: StringName, box: Rect2) -> void:
	a.pose_windup = windup
	a.pose_strike = strike
	a.hitbox = box
