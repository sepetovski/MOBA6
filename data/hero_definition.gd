class_name HeroDefinition extends Resource

@export var id: StringName
@export var display_name: String
@export var model_scene: PackedScene
@export var stats: UnitStats
@export var movement: MovementProfile
@export var abilities: Array[AbilityDefinition] = []
@export var passive: AbilityDefinition
@export var animation_map: Dictionary = {}
