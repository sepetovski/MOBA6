class_name BalanceAdmin extends CanvasLayer

## F8. Match gold, champion sheets, and the item list. Saved on this machine only.

var _root: Control
var _page := "match"
var _match_fields: Dictionary = {}
var _hero_fields: Dictionary = {}
var _item_list: ItemList
var _item_fields: Dictionary = {}
var _mod_fields: Array[Dictionary] = []
var _body: VBoxContainer


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	BalanceStore.boot()
	_root = Control.new()
	_root.visible = false
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -460.0
	panel.offset_right = 460.0
	panel.offset_top = -340.0
	panel.offset_bottom = 340.0
	_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Balance    F8"
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
	scroll.custom_minimum_size = Vector2(860, 500)
	box.add_child(scroll)
	_body = VBoxContainer.new()
	_body.custom_minimum_size = Vector2(840, 0)
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


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.physical_keycode != KEY_F8:
		return
	_root.visible = not _root.visible
	if _root.visible:
		_show_page(_page)
	get_viewport().set_input_as_handled()


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
	for key in ["match_seconds", "gold_per_second", "kill_gold", "kill_streak_gold", "kill_streak_cap", "assist_gold", "assist_seconds", "start_gold"]:
		_match_fields[key] = _number_row(_body, key.replace("_", " "), str(rules[key]))
	_note("Match length and gold apply on the next tick. Champion sheets apply to the next unit that spawns.")


func _build_heroes() -> void:
	_hero_fields.clear()
	for id in ["gladiator", "skirmisher", "slinger"]:
		var hero := HeroCatalog.by_id(StringName(id))
		var heading := Label.new()
		heading.text = hero.display_name
		heading.add_theme_font_size_override("font_size", 20)
		heading.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
		_body.add_child(heading)
		var sheet := BalanceStore.sheet(hero)
		var fields := {}
		for key in BalanceStore.HERO_FIELDS:
			fields[key] = _number_row(_body, key.replace("_", " "), str(sheet[key]))
		_hero_fields[id] = fields


func _build_items() -> void:
	_item_fields.clear()
	_mod_fields.clear()
	_item_list = ItemList.new()
	_item_list.custom_minimum_size = Vector2(820, 160)
	for item in BalanceStore.items():
		_item_list.add_item("%s    %d    %s" % [item.display_name, item.price, item.category])
	_item_list.item_selected.connect(func(index: int) -> void: _fill_item(index))
	_body.add_child(_item_list)
	_item_fields["id"] = _number_row(_body, "id", "")
	_item_fields["name"] = _number_row(_body, "name", "")
	_item_fields["price"] = _number_row(_body, "price", "400")
	_item_fields["category"] = _number_row(_body, "category", "damage")
	_item_fields["active"] = _number_row(_body, "active none blink leap stun", "none")
	_item_fields["cooldown"] = _number_row(_body, "cooldown", "8")
	_item_fields["range"] = _number_row(_body, "range", "8")
	_item_fields["duration"] = _number_row(_body, "duration", "0.6")
	for _slot in 3:
		var stat := _number_row(_body, "stat", "")
		var mode := _number_row(_body, "mode flat or percent", "flat")
		var amount := _number_row(_body, "amount", "0")
		_mod_fields.append({"stat": stat, "mode": mode, "amount": amount})
	var row := HBoxContainer.new()
	var add := Button.new()
	add.text = "Add item"
	add.pressed.connect(_add_item)
	var remove := Button.new()
	remove.text = "Delete selected"
	remove.pressed.connect(_delete_item)
	row.add_child(add)
	row.add_child(remove)
	_body.add_child(row)
	_note("Stats: health, attack_damage, attack_interval, magazine, reload, run_speed, dash_charges, dash_recharge, damage_taken. Percent on attack_interval, reload, and dash_recharge makes them shorter.")
	if _item_list.item_count > 0:
		_item_list.select(0)
		_fill_item(0)


func _fill_item(index: int) -> void:
	var catalog := BalanceStore.items()
	if index < 0 or index >= catalog.size():
		return
	var item := catalog[index]
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
		for id in _hero_fields:
			var sheet := {}
			var fields: Dictionary = _hero_fields[id]
			for key in fields:
				sheet[key] = float((fields[key] as LineEdit).text)
			heroes[id] = sheet
	else:
		for id in ["gladiator", "skirmisher", "slinger"]:
			heroes[id] = BalanceStore.hero_overlay(id)
			if heroes[id].is_empty():
				heroes[id] = BalanceStore.sheet(HeroCatalog.by_id(StringName(id)))
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
	var selected := _item_list.get_selected_items()
	if selected.is_empty():
		return
	var index := int(selected[0])
	var catalog := BalanceStore.items()
	if index < 0 or index >= catalog.size():
		return
	var item := catalog[index]
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
	_item_list.set_item_text(index, "%s    %d    %s" % [item.display_name, item.price, item.category])


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
	_show_page("items")
	_item_list.select(items.size() - 1)
	_fill_item(items.size() - 1)


func _delete_item() -> void:
	var selected := _item_list.get_selected_items()
	if selected.is_empty():
		return
	var index := int(selected[0])
	var items: Array[ItemDefinition] = []
	var catalog := BalanceStore.items()
	for i in catalog.size():
		if i != index:
			items.append(catalog[i])
	BalanceStore.save(BalanceStore.rules(), _current_heroes(), items)
	_show_page("items")


func _current_heroes() -> Dictionary:
	var heroes := {}
	for id in ["gladiator", "skirmisher", "slinger"]:
		var overlay := BalanceStore.hero_overlay(id)
		heroes[id] = overlay if not overlay.is_empty() else BalanceStore.sheet(HeroCatalog.by_id(StringName(id)))
	return heroes


func _reset() -> void:
	BalanceStore.reset()
	_show_page(_page)


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
