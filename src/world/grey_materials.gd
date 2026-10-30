class_name GreyMaterials extends RefCounted

## Shared gray materials. One grid texture, triplanar in world space, so every surface reads as 1 m squares.

static var _grid: Texture2D
static var _meadow: StandardMaterial3D
static var _by_albedo: Dictionary = {}


static func meadow_material() -> StandardMaterial3D:
	if _meadow != null:
		return _meadow
	_meadow = StandardMaterial3D.new()
	_meadow.albedo_color = Color(0.78, 0.9, 0.55)
	_meadow.albedo_texture = _grass_texture()
	_meadow.roughness = 1.0
	_meadow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_meadow.cull_mode = BaseMaterial3D.CULL_DISABLED
	_meadow.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_meadow.uv1_triplanar = true
	_meadow.uv1_world_triplanar = true
	_meadow.uv1_scale = Vector3(0.22, 0.22, 0.22)
	return _meadow


static func _grass_texture() -> Texture2D:
	# Colors taken from the kit grass atlas so the floor matches the plants.
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	var lush := Color(0.36, 0.62, 0.16)
	var bright := Color(0.62, 0.78, 0.22)
	var yellow := Color(0.71, 0.68, 0.18)
	var soil := Color(0.45, 0.32, 0.14)
	for y in size:
		for x in size:
			var u := float(x) / float(size)
			var v := float(y) / float(size)
			var wave := 0.5 + 0.5 * sin((u * 4.0 + v * 3.0) * TAU)
			var speckle := 0.5 + 0.5 * sin((u * 13.0 - v * 11.0) * TAU)
			var color := lush.lerp(bright, 0.35 + wave * 0.2)
			if speckle > 0.86:
				color = color.lerp(yellow, 0.35)
			elif speckle < 0.06:
				color = color.lerp(soil, 0.28)
			image.set_pixel(x, y, color)
	var texture := ImageTexture.create_from_image(image)
	return texture

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
