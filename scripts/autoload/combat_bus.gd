extends Node
## Global combat event bus. Fighters announce what happened; presentation
## (sparks, sound, camera, HUD) and later systems (achievements, stats,
## netcode replication) listen without the fighters knowing about them.

## info keys: attacker, target, attack (AttackData), result (Fighter.HitResult),
## point (Vector2), counter (bool), damage (float)
signal hit_resolved(info: Dictionary)
signal fighter_ko(fighter: Node, killer: Node)
## Cosmetic requests: &"dust", &"slam", &"wall_splat", &"jump".
signal fx(kind: StringName, position: Vector2, data: Dictionary)
