class_name WeaponData
extends Resource
## A weapon is a look (how the rig draws it) plus a moveset that replaces the
## fighter's fists while it is held. It breaks after `durability` hits.

@export var id: StringName
@export var display_name := ""
## &"blade", &"hammer", &"spear" or &"plasma": picks the rig drawing.
@export var style: StringName = &"blade"
@export var color := Color.WHITE
## Distance from the hand to the tip, in rig pixels.
@export var length := 44.0
@export var durability := 16

var moveset: Dictionary = {}
