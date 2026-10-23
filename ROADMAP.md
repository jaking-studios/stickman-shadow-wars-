# Roadmap

The full design for Stickman: Shadow Wars is large. Version 0.1 is a playable vertical slice that nails the combat core and lays down the architecture everything else plugs into. This file tracks every part of the design and where it stands.

✅ done in 0.1 · 🟡 partly done / foundation in place · ⬜ planned

## Core combat

| Item | Status | Notes |
| --- | --- | --- |
| Light attack combos | ✅ | Three-hit string with buffered inputs |
| Heavy attacks | ✅ | Chainable from lights |
| Air attacks | ✅ | Two-hit air string + diving slam |
| Dash attacks | ✅ | From a run or out of a dodge roll |
| Launch attacks | ✅ | Down+heavy, jump-cancel into air combos |
| Blocking | ✅ | Chip damage, blockstun, pushback |
| Perfect parry | ✅ | 8-frame window, anti-mash cooldown |
| Counter attacks | ✅ | Post-parry hit deals 1.5× with extra hitstop |
| Dodge roll / air dodge | ✅ | I-frames, tech roll, wavelanding |
| Finisher system | 🟡 | Slow-mo KO punch-in and ragdoll done; bespoke cinematic finisher moves planned |
| Impact VFX / screen shake | ✅ | Sparks, rings, trails, hitstop, trauma shake |

## Physics

| Item | Status | Notes |
| --- | --- | --- |
| Ragdoll | 🟡 | Verlet ragdoll on KO; full active ragdoll during play planned |
| Dynamic limb movement | 🟡 | Procedural pose blending, flinches, run cycle |
| Realistic knockback | ✅ | Scales with damage taken, bounces, knockdowns |
| Wall collisions | ✅ | Wall splats |
| Environmental interactions / hazards | ⬜ | Lava, falling rocks, lasers, spikes, exploding barrels |
| Damage affects movement | ✅ | Slower and slouched at low health |

## Weapons

| Item | Status |
| --- | --- |
| Moveset system that weapons plug into | ✅ (`AttackData` + `MoveLibrary`) |
| Sword, katana, greatsword, spear, axe, hammer, staff | ⬜ |
| Bow, crossbow, throwing knives, grenades (projectile system) | ⬜ |
| Plasma sword, energy hammer, magic staff | ⬜ |

## Abilities

| Item | Status |
| --- | --- |
| Fire: fireballs, flame dash, explosion punch | ⬜ |
| Ice: freeze, ice walls, frost wave | ⬜ |
| Lightning: teleport strike, chain lightning, thunder slam | ⬜ |
| Shadow: clones, shadow dash, invisibility | ⬜ |

Abilities will be new `FighterState`s (cast states) plus a resource/meter system.

## Game modes

| Item | Status |
| --- | --- |
| Versus (1P vs CPU, 2P local, CPU vs CPU) | ✅ |
| Arena / endless survival | ⬜ |
| Tournament bracket | ⬜ |
| Story mode (20+ levels, bosses, rivals, cutscenes, multiple endings) | ⬜ |

## Multiplayer

| Item | Status | Notes |
| --- | --- | --- |
| Local multiplayer | ✅ | Two players on keyboard and/or controllers |
| Online, private lobbies, matchmaking | ⬜ | Input abstraction and frame-based logic are in place for a `NetworkInput` + rollback |

## AI

| Item | Status |
| --- | --- |
| Easy / Normal / Hard / Nightmare | ✅ |
| Dodges and blocks attacks, parries on higher levels | ✅ |
| Predicts player movement | ✅ (velocity lead) |
| Adapts to player strategies | 🟡 (counts jump-ins and heavies; deeper learning planned) |
| Uses abilities intelligently | ⬜ (needs abilities) |
| Teams up in group battles | ⬜ (targeting already supports more than two fighters) |

## Progression and customisation

| Item | Status |
| --- | --- |
| Save/load framework | 🟡 (JSON profile: wins, XP, best combo) |
| XP, skill points, currency, unlocks | ⬜ |
| Character creator (colour, armour, weapons, effects, auras, eyes, victory poses) | 🟡 (rig already supports colour, aura and eye colour) |

## Maps

| Item | Status |
| --- | --- |
| Neon Rooftop | ✅ |
| 14 more arenas (dojo, forest, volcano, castle, cyber city, space station, temple, underwater facility, ancient ruins…) | ⬜ |

## Graphics, audio, platform

| Item | Status |
| --- | --- |
| Smooth procedural animation, trails, particles, weather (rain) | ✅ |
| Dynamic lighting, motion blur | ⬜ |
| Punch / clash / KO sounds | ✅ (synthesised) |
| Music, dynamic combat music, spatial audio | ⬜ |
| Controller support | ✅ |
| Mobile touch controls + Android APK | ✅ |
| Web build | ✅ |
| Ultrawide | ✅ (stretch mode `expand`) |
| Steam achievements, leaderboards, cloud saves | ⬜ (via GodotSteam) |
