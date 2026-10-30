class_name GreyMaterials extends RefCounted

## Shared gray materials. One grid texture, triplanar in world space, so every surface reads as 1 m squares.

static var _grid: Texture2D
static var _meadow: StandardMaterial3D
static var _by_albedo: Dictionary = {}
static var _by_color: Dictionary = {}


static func meadow_material() -> StandardMaterial3D:
	if _meadow != null:
		return _meadow
	_meadow = StandardMaterial3D.new()
	# Sunlit grass around the lane. The texture is mottled, so it is not one flat green fill.
	_meadow.albedo_color = Color(0.82, 0.88, 0.7)
	_meadow.albedo_texture = _grass_texture()
	_meadow.roughness = 1.0
	_meadow.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_meadow.cull_mode = BaseMaterial3D.CULL_DISABLED
	_meadow.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_meadow.uv1_triplanar = true
	_meadow.uv1_world_triplanar = true
	_meadow.uv1_scale = Vector3(0.35, 0.35, 0.35)
	return _meadow


static func lane_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	# Sandy dirt, the colour of the reference path. Light enough to read, not a white or brown slab.
	material.albedo_color = Color(0.8, 0.74, 0.58)
	material.albedo_texture = _lane_texture()
	material.roughness = 0.96
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.uv1_scale = Vector3(0.4, 0.4, 0.4)
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	return material


static func flat_material(color: Color) -> StandardMaterial3D:
	var key := "%0.3f,%0.3f,%0.3f" % [color.r, color.g, color.b]
	if _by_color.has(key):
		return _by_color[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_by_color[key] = material
	return material


static func _grass_texture() -> Texture2D:
	# Mottled yellow-green. Hash noise, not waves, so the floor does not turn into stripes.
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	var lush := Color(0.34, 0.55, 0.18)
	var bright := Color(0.55, 0.72, 0.26)
	var yellow := Color(0.68, 0.66, 0.30)
	var soil := Color(0.58, 0.48, 0.26)
	for y in size:
		for x in size:
			var clump := _noise(x >> 3, y >> 3)
			var speckle := _noise(x, y)
			var color := lush.lerp(bright, clump)
			color = color.lerp(yellow, speckle * 0.35)
			if speckle > 0.86:
				color = color.lerp(soil, 0.55)
			elif speckle < 0.08:
				color = color.lerp(Color(0.28, 0.42, 0.14), 0.4)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


static func _lane_texture() -> Texture2D:
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	var sand := Color(0.62, 0.50, 0.30)
	var pale := Color(0.74, 0.62, 0.38)
	var soil := Color(0.50, 0.38, 0.22)
	var stone := Color(0.58, 0.56, 0.50)
	for y in size:
		for x in size:
			var clump := _noise(x >> 2, y >> 2)
			var grit := _noise(x * 3 + 11, y * 5 + 7)
			var color := sand.lerp(pale, clump)
			if grit > 0.9:
				color = stone
			elif grit < 0.1:
				color = color.lerp(soil, 0.5)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


static func _noise(x: int, y: int) -> float:
	var n := x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xffffff) / float(0xffffff)

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
