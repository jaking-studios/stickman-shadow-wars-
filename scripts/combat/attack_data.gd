class_name AttackData
extends Resource
## Frame data for one move. Timings are physics frames (60 per second).
## Hitboxes are authored facing right, relative to the fighter's feet; the
## fighter mirrors them when facing left. Save these as .tres files to give
## each weapon or fighting style its own moveset.

@export var id: StringName

@export_group("Timing")
@export var startup := 5
@export var active := 3
@export var recovery := 10
## Frames after the active window before a buffered chain input fires.
@export var chain_delay := 2
## Lockout after an air attack touches the ground.
@export var landing_lag := 6

@export_group("Hit")
@export var hitbox := Rect2(10, -80, 40, 24)
@export var damage := 5.0
## Damage dealt through a block (never lethal).
@export var chip := 0.0
@export var knockback := Vector2(150, -20)
@export var hitstun := 18
@export var blockstun := 8
@export var hit_stop := 4
@export var shake := 2.0
## Forces the target into an airborne tumble (launchers, spikes).
@export var launcher := false
@export var heavy_hit := false

@export_group("Movement")
@export var air := false
## Forward speed applied on the first active frame.
@export var lunge := 0.0
## Velocity set on the first active frame (x is mirrored by facing). Dive kicks.
@export var dive_velocity := Vector2.ZERO
## Fraction of horizontal momentum kept when the attack starts.
@export var keep_momentum := 0.3
@export var gravity_scale := 1.0

@export_group("Chains")
@export var next_light: StringName
## Heavy can be chained after this move (resolves to launcher if holding down).
@export var chain_heavy := false
## On hit, jump can cancel recovery (launcher -> air combo).
@export var jump_cancel := false

@export_group("Presentation")
@export var pose_windup: StringName = &"idle"
@export var pose_strike: StringName = &"jab"
## Joint that leaves a motion trail while active (hand_f, hand_b, foot_f...).
@export var trail_joint: StringName = &"hand_f"
