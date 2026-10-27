class_name ArenaMath extends RefCounted

## Octagon helpers. Vertices sit at 22.5° + k·45° so the flats face the cardinal axes.
## Vector2.x is world X and Vector2.y is world Z.

const SECTOR := PI / 8.0

static func circumradius(apothem: float) -> float:
	return apothem / cos(SECTOR)

static func vertices(apothem: float) -> PackedVector2Array:
	var radius := circumradius(apothem)
	var verts := PackedVector2Array()
	for k in 8:
		var angle := SECTOR + float(k) * (PI / 4.0)
		verts.append(Vector2(cos(angle), sin(angle)) * radius)
	return verts

static func contains(point: Vector2, apothem: float) -> bool:
	var verts := vertices(apothem)
	var inside := false
	var count := verts.size()
	var j := count - 1
	for i in count:
		var pi := verts[i]
		var pj := verts[j]
		var crosses := (pi.y > point.y) != (pj.y > point.y)
		if crosses:
			var x_at_y := (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x
			if point.x < x_at_y:
				inside = not inside
		j = i
	return inside

static func yaw_to_basis(yaw_deg: float) -> Basis:
	return Basis.from_euler(Vector3(0.0, deg_to_rad(yaw_deg), 0.0))

static func rotate_xz(offset: Vector3, yaw_deg: float) -> Vector3:
	var basis := yaw_to_basis(yaw_deg)
	return basis * offset

static func mirror_yaw_x(yaw_deg: float) -> float:
	return -yaw_deg

static func mirror_yaw_z(yaw_deg: float) -> float:
	return 180.0 - yaw_deg

static func mirror_yaw_both(yaw_deg: float) -> float:
	return yaw_deg + 180.0

static func wrap_yaw(yaw_deg: float) -> float:
	var wrapped := fmod(yaw_deg, 360.0)
	if wrapped > 180.0:
		wrapped -= 360.0
	elif wrapped <= -180.0:
		wrapped += 360.0
	return wrapped

static func yaw_delta(a: float, b: float) -> float:
	return absf(wrap_yaw(a - b))
