class_name Team extends RefCounted

enum Id { A = 0, B = 1 }

static func opposing(team: Id) -> Id:
	return Id.B if team == Id.A else Id.A
