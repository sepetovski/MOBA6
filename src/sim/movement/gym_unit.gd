class_name GymUnit extends CharacterBody3D

## TEMP until M4 replaces this with SimUnit. A capsule body, a motor, and the placeholder view.

var motor: MovementMotor
var profile: MovementProfile
var view: PlaceholderUnitView


func setup(movement_profile: MovementProfile, nav_map: RID) -> void:
	profile = movement_profile
	motor = MovementMotor.new(self, profile, nav_map)
	view = PlaceholderUnitView.new()
	view.name = "View"
	add_child(view)
	view.bind(self)
