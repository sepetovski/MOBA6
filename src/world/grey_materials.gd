class_name GreyMaterials extends RefCounted

## Shared gray materials. One grid texture, triplanar in world space, so every surface reads as 1 m squares.

static var _grid: Texture2D
static var _meadow: StandardMaterial3D
static var _by_albedo: Dictionary = {}


static func meadow_material() -> StandardMaterial3D:
	if _meadow != null:
		return _meadow
	_meadow = StandardMaterial3D.new()
	_meadow.albedo_color = Color(0.45, 0.68, 0.32)
	_meadow.roughness = 1.0
	return _meadow

static func get_material(albedo: float) -> StandardMaterial3D:
	var key := snappedf(albedo, 0.001)
	if _by_albedo.has(key):
		return _by_albedo[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(key, key, key)
	material.albedo_texture = grid_texture()
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE
	material.roughness = 1.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_by_albedo[key] = material
	return material

static func grid_texture() -> Texture2D:
	if _grid != null:
		return _grid
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	image.fill(Color(0.72, 0.72, 0.72))
	var line := Color(0.35, 0.35, 0.35)
	for i in 64:
		image.set_pixel(i, 0, line)
		image.set_pixel(i, 1, line)
		image.set_pixel(0, i, line)
		image.set_pixel(1, i, line)
	_grid = ImageTexture.create_from_image(image)
	return _grid
