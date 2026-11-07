class_name BalanceAdmin extends CanvasLayer

## Balance. F10, or the Balance button in settings. Saved on this machine only.

var _root: Control
var _page := "match"
var _match_fields: Dictionary = {}
var _hero_fields: Dictionary = {}
var _item_list: ItemList
var _selected_item := ""
var _selected_hero := "gladiator"
var _hero_name: LineEdit
var _hero_draft: Dictionary = {}
var _item_fields: Dictionary = {}
var _mod_fields: Array[Dictionary] = []
var _body: VBoxContainer


func _ready() -> void:
	layer = 40
	add_to_group(&"balance_admin")
	BalanceStore.boot()
	_root = Control.new()
	_root.visible = false
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 36.0
	panel.offset_top = 36.0
	panel.offset_right = -36.0
	panel.offset_bottom = -36.0
	panel.add_theme_stylebox_override("panel", _panel_style())
	_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Balance"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86))
	box.add_child(title)
	var tabs := HBoxContainer.new()
	for page in ["match", "heroes", "items"]:
		var button := Button.new()
		button.text = page.capitalize()
		button.pressed.connect(_show_page.bind(page))
		tabs.add_child(button)
	box.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 6)
	scroll.add_child(_body)
	var row := HBoxContainer.new()
	var save := Button.new()
	save.text = "Save"
	save.pressed.connect(_save)
	var reset := Button.new()
	reset.text = "Reset shipped numbers"
	reset.pressed.connect(_reset)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void: _root.visible = false)
	row.add_child(save)
	row.add_child(reset)
	row.add_child(close)
	box.add_child(row)
	_show_page("match")


func is_open() -> bool:
	return _root != null and _root.visible


func toggle() -> void:
	_root.visible = not _root.visible
	if _root.visible:
		_show_page(_page)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.physical_keycode != KEY_F10:
		return
	toggle()
	get_viewport().set_input_as_handled()


func _panel_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.08, 0.07, 0.96)
	box.border_color = Color(0.86, 0.74, 0.32)
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box


func _show_page(page: String) -> void:
	_page = page
	for child in _body.get_children():
		child.queue_free()
	if page == "heroes":
		_build_heroes()
	elif page == "items":
		_build_items()
	else:
		_build_match()


func _build_match() -> void:
	_match_fields.clear()
	var rules := BalanceStore.rules()
	for key in ["match_seconds", "gold_per_second", "kill_gold", "kill_streak_gold", "kill_streak_cap", "assist_gold", "assist_seconds", "start_gold", "inventory_slots", "active_slots"]:
		_match_fields[key] = _number_row(_body, key.replace("_", " "), str(rules[key]))
	_note("Match length and gold apply on the next tick. Champion sheets apply to the next unit that spawns.")


func _build_heroes() -> void:
	_hero_fields.clear()
	if _hero_draft.is_empty():
		_load_hero_draft()
	if not _hero_draft.has(_selected_hero):
		_selected_hero = "gladiator"
	var split := _split()
	var left: VBoxContainer = split[0]
	var right: VBoxContainer = split[1]
	var heading := Label.new()
	heading.text = "Selected hero"
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	left.add_child(heading)
	_hero_name = _number_row(left, "name", str(_hero_draft[_selected_hero].get("display_name", _selected_hero)))
	var fields := {}
	for key in BalanceStore.HERO_FIELDS:
		fields[key] = _number_row(left, key.replace("_", " "), str(_hero_draft[_selected_hero][key]))
	_hero_fields[_selected_hero] = fields
	_fill_hero_list(right)


func _load_hero_draft() -> void:
	for id in HeroCatalog.all_ids():
		var hero := HeroCatalog.by_id(StringName(id))
		if hero == null:
			continue
		var sheet := BalanceStore.sheet(hero)
		var overlay := BalanceStore.hero_overlay(id)
		sheet["display_name"] = hero.display_name
		sheet["attack"] = "ranged" if hero.stats.attack == UnitStats.Attack.RANGED else "melee"
		sheet["template"] = str(overlay.get("template", id))
		_hero_draft[id] = sheet


func _build_items() -> void:
	_item_fields.clear()
	_mod_fields.clear()
	if _selected_item.is_empty() and not BalanceStore.items().is_empty():
		_selected_item = BalanceStore.items()[0].id
	var split := _split()
	var left: VBoxContainer = split[0]
	var right: VBoxContainer = split[1]
	_item_fields["id"] = _number_row(left, "id", "")
	_item_fields["name"] = _number_row(left, "name", "")
	_item_fields["price"] = _number_row(left, "price", "400")
	_item_fields["category"] = _number_row(left, "category", "damage")
	_item_fields["active"] = _number_row(left, "active none blink leap stun", "none")
	_item_fields["cooldown"] = _number_row(left, "cooldown", "8")
	_item_fields["range"] = _number_row(left, "range", "8")
	_item_fields["duration"] = _number_row(left, "duration", "0.6")
	for _slot in 3:
		var stat := _number_row(left, "stat", "")
		var mode := _number_row(left, "mode flat or percent", "flat")
		var amount := _number_row(left, "amount", "0")
		_mod_fields.append({"stat": stat, "mode": mode, "amount": amount})
	var remove := Button.new()
	remove.text = "Delete selected"
	remove.pressed.connect(_delete_item)
	left.add_child(remove)
	_note("Stats: health, attack_damage, attack_interval, magazine, reload, run_speed, dash_charges, dash_recharge, damage_taken. Percent on attack_interval, reload, and dash_recharge makes them shorter.")
	_fill_item_list(right)
	_fill_item_id(_selected_item)


func _fill_item_id(item_id: String) -> void:
	var item := BalanceStore.item(item_id)
	if item == null:
		return
	_selected_item = item.id
	(_item_fields["id"] as LineEdit).text = item.id
	(_item_fields["name"] as LineEdit).text = item.display_name
	(_item_fields["price"] as LineEdit).text = str(item.price)
	(_item_fields["category"] as LineEdit).text = item.category
	(_item_fields["active"] as LineEdit).text = item.active
	(_item_fields["cooldown"] as LineEdit).text = str(item.cooldown)
	(_item_fields["range"] as LineEdit).text = str(item.reach)
	(_item_fields["duration"] as LineEdit).text = str(item.duration)
	for slot in _mod_fields.size():
		var stat := _mod_fields[slot]["stat"] as LineEdit
		var mode := _mod_fields[slot]["mode"] as LineEdit
		var amount := _mod_fields[slot]["amount"] as LineEdit
		if slot < item.mods.size():
			stat.text = str(item.mods[slot].get("stat", ""))
			mode.text = str(item.mods[slot].get("mode", "flat"))
			amount.text = str(item.mods[slot].get("amount", 0))
		else:
			stat.text = ""
			mode.text = "flat"
			amount.text = "0"


func _save() -> void:
	if _page == "items":
		_write_selected_item()
	var rules := {}
	if _page == "match":
		for key in _match_fields:
			rules[key] = float((_match_fields[key] as LineEdit).text)
	else:
		rules = BalanceStore.rules()
	var heroes := {}
	if _page == "heroes":
		_stash_hero_form()
		heroes = _hero_draft.duplicate(true)
	else:
		heroes = _current_heroes()
	var items: Array[ItemDefinition] = []
	if _page == "items":
		items = _items_from_form_and_list()
	else:
		for item in BalanceStore.items():
			items.append(item)
	BalanceStore.save(rules, heroes, items)


func _items_from_form_and_list() -> Array[ItemDefinition]:
	var items: Array[ItemDefinition] = []
	for item in BalanceStore.items():
		items.append(item)
	return items


func _write_selected_item() -> void:
	var item := BalanceStore.item(_selected_item)
	if item == null:
		return
	item.id = (_item_fields["id"] as LineEdit).text.strip_edges()
	item.display_name = (_item_fields["name"] as LineEdit).text.strip_edges()
	item.price = int((_item_fields["price"] as LineEdit).text)
	item.category = (_item_fields["category"] as LineEdit).text.strip_edges()
	var active := (_item_fields["active"] as LineEdit).text.strip_edges()
	item.active = active if BalanceStore.ACTIVES.has(active) else "none"
	item.cooldown = float((_item_fields["cooldown"] as LineEdit).text)
	item.reach = float((_item_fields["range"] as LineEdit).text)
	item.duration = float((_item_fields["duration"] as LineEdit).text)
	item.mods.clear()
	for slot in _mod_fields:
		var stat := (slot["stat"] as LineEdit).text.strip_edges()
		if stat.is_empty() or not BalanceStore.STATS.has(stat):
			continue
		var mode := (slot["mode"] as LineEdit).text.strip_edges()
		item.mods.append({
			"stat": stat,
			"mode": "percent" if mode == "percent" else "flat",
			"amount": float((slot["amount"] as LineEdit).text),
		})


func _add_item() -> void:
	var item := ItemDefinition.new()
	item.id = "item_%d" % (BalanceStore.items().size() + 1)
	item.display_name = "New item"
	item.price = 400
	item.category = "damage"
	var items: Array[ItemDefinition] = []
	for existing in BalanceStore.items():
		items.append(existing)
	items.append(item)
	BalanceStore.save(BalanceStore.rules(), _current_heroes(), items)
	_selected_item = item.id
	_show_page("items")


func _delete_item() -> void:
	if _selected_item.is_empty():
		return
	var items: Array[ItemDefinition] = []
	for existing in BalanceStore.items():
		if existing.id != _selected_item:
			items.append(existing)
	_selected_item = items[0].id if not items.is_empty() else ""
	BalanceStore.save(BalanceStore.rules(), _current_heroes(), items)
	_show_page("items")


func _current_heroes() -> Dictionary:
	var heroes := {}
	for id in HeroCatalog.all_ids():
		var overlay := BalanceStore.hero_overlay(id)
		if not overlay.is_empty():
			heroes[id] = overlay
			continue
		var hero := HeroCatalog.by_id(StringName(id))
		if hero == null:
			continue
		var sheet := BalanceStore.sheet(hero)
		sheet["display_name"] = hero.display_name
		sheet["attack"] = "ranged" if hero.stats.attack == UnitStats.Attack.RANGED else "melee"
		heroes[id] = sheet
	return heroes


func _reset() -> void:
	BalanceStore.reset()
	_show_page(_page)


func _split() -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(row)
	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(560, 620)
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left_scroll)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	left_scroll.add_child(left)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	row.add_child(right)
	return [left, right]


func _fill_hero_list(column: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 560)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for id in _hero_draft.keys():
		var button := Button.new()
		button.text = str(_hero_draft[id].get("display_name", id))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if id == _selected_hero:
			button.modulate = Color(1.2, 1.1, 0.7)
		button.pressed.connect(_select_hero.bind(id))
		list.add_child(button)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "New hero name"
	name_edit.text = "New hero"
	column.add_child(name_edit)
	var add_row := HBoxContainer.new()
	var melee := Button.new()
	melee.text = "+ Melee"
	melee.pressed.connect(_add_hero.bind(name_edit, "melee"))
	var ranged := Button.new()
	ranged.text = "+ Ranged"
	ranged.pressed.connect(_add_hero.bind(name_edit, "ranged"))
	add_row.add_child(melee)
	add_row.add_child(ranged)
	column.add_child(add_row)


func _select_hero(id: String) -> void:
	_stash_hero_form()
	_selected_hero = id
	_show_page("heroes")


func _stash_hero_form() -> void:
	if _hero_name == null or not _hero_draft.has(_selected_hero):
		return
	var sheet: Dictionary = _hero_draft[_selected_hero]
	sheet["display_name"] = _hero_name.text.strip_edges()
	var fields: Dictionary = _hero_fields.get(_selected_hero, {})
	for key in fields:
		sheet[key] = float((fields[key] as LineEdit).text)
	_hero_draft[_selected_hero] = sheet


func _add_hero(name_edit: LineEdit, attack: String) -> void:
	_stash_hero_form()
	if not _hero_draft.is_empty():
		BalanceStore.save(BalanceStore.rules(), _hero_draft.duplicate(true), BalanceStore.items())
	var id := BalanceStore.add_hero(name_edit.text, attack)
	_selected_hero = id
	_show_page("heroes")


func _fill_item_list(column: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 560)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for category in ["damage", "tempo", "vitality", "mobility", "guard", "active"]:
		var found := false
		for item in BalanceStore.items():
			if item.category != category:
				continue
			if not found:
				var heading := Label.new()
				heading.text = category.capitalize()
				heading.add_theme_font_size_override("font_size", 16)
				heading.add_theme_color_override("font_color", Color(0.95, 0.84, 0.45))
				list.add_child(heading)
				found = true
			var button := Button.new()
			button.text = "%s    %d" % [item.display_name, item.price]
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			if item.id == _selected_item:
				button.modulate = Color(1.2, 1.1, 0.7)
			button.pressed.connect(_select_item.bind(item.id))
			list.add_child(button)
	var add := Button.new()
	add.text = "+ Add"
	add.pressed.connect(_add_item)
	column.add_child(add)


func _select_item(item_id: String) -> void:
	_write_selected_item()
	_selected_item = item_id
	_show_page("items")


func _number_row(parent: Node, label_text: String, value: String) -> LineEdit:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(280, 24)
	label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.78))
	var edit := LineEdit.new()
	edit.text = value
	edit.custom_minimum_size = Vector2(220, 28)
	row.add_child(label)
	row.add_child(edit)
	parent.add_child(row)
	return edit


func _note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.68))
	_body.add_child(label)
