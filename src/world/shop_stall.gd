class_name ShopStall extends RefCounted

## A counter in each spawn tunnel. The shop UI opens when you stand next to it.


static func build(parent: Node3D, at: Vector3, team: int) -> void:
	var root := Node3D.new()
	root.name = "Shop%s" % ("A" if team == Team.Id.A else "B")
	root.position = at
	parent.add_child(root)
	var cloth := Color(0.25, 0.42, 0.78) if team == Team.Id.A else Color(0.75, 0.28, 0.22)
	_box(root, Vector3(0, 0.55, 0), Vector3(2.4, 1.1, 1.1), Color(0.42, 0.3, 0.16))
	_box(root, Vector3(0, 1.16, 0), Vector3(2.6, 0.12, 1.3), Color(0.55, 0.4, 0.22))
	_box(root, Vector3(0, 2.15, -0.45), Vector3(2.6, 0.08, 1.1), cloth)
	_post(root, Vector3(-1.15, 0, -0.85))
	_post(root, Vector3(1.15, 0, -0.85))
	var sign := Label3D.new()
	sign.text = "SHOP"
	sign.font_size = 96
	sign.pixel_size = 0.01
	sign.position = Vector3(0, 1.7, 0.7)
	sign.modulate = cloth
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	root.add_child(sign)


static func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position = at
	visual.material_override = GreyMaterials.flat_material(color)
	parent.add_child(visual)


static func _post(parent: Node3D, at: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.08
	mesh.bottom_radius = 0.08
	mesh.height = 2.2
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position = at + Vector3(0, 1.1, 0)
	visual.material_override = GreyMaterials.flat_material(Color(0.32, 0.24, 0.14))
	parent.add_child(visual)
