class_name SpawnShop extends CanvasLayer

## Opens anywhere with B or `. Buying still requires standing at your stall.

const CATEGORIES: PackedStringArray = ["all", "damage", "tempo", "vitality", "mobility", "guard", "active"]

var _sim: Simulation
var _panel: PanelContainer
var _cards: GridContainer
var _gold: Label
var _hint: Label
var _filter := "all"
var _open := false
var _built_revision := -1
var _filter_buttons: Array[Button] = []


func bind(sim: Simulation) -> void:
	_sim = sim


func _ready() -> void:
	layer = 24
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 48.0
	_panel.offset_top = 48.0
	_panel.offset_right = -48.0
	_panel.offset_bottom = -48.0
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.06, 0.96)
	style.border_color = Color(0.86, 0.74, 0.32)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	_panel.add_child(root)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(180, 0)
	side.add_theme_constant_override("separation", 6)
	root.add_child(side)
	var title := Label.new()
	title.text = "Shop"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86))
	side.add_child(title)
	_gold = Label.new()
	_gold.add_theme_font_size_override("font_size", 22)
	_gold.add_theme_color_override("font_color", Color(1.0, 0.86, 0.28))
	side.add_child(_gold)
	for category in CATEGORIES:
		var button := Button.new()
		button.text = "All" if category == "all" else category.capitalize()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_set_filter.bind(category))
		side.add_child(button)
		_filter_buttons.append(button)
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(170, 80)
	_hint.add_theme_color_override("font_color", Color(0.8, 0.78, 0.68))
	side.add_child(_hint)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void: _open = false)
	side.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_cards = GridContainer.new()
	_cards.columns = 4
	_cards.add_theme_constant_override("h_separation", 12)
	_cards.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_cards)


func _input(event: InputEvent) -> void:
	if not InputMap.has_action(&"shop") or not event.is_action_pressed(&"shop"):
		return
	_open = not _open
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _sim == null or _panel == null:
		return
	var human := _sim.get_human()
	_panel.visible = _open and human != null and human.state.alive
	if not _panel.visible:
		return
	var at_stall := _sim.near_shop(human)
	_gold.text = "GOLD  %d" % human.state.gold
	_hint.text = "At your stall. Buy what you can carry." if at_stall else "You can look from anywhere. Walk to your stall to buy."
	if _built_revision != BalanceStore.revision:
		_rebuild()
		_built_revision = BalanceStore.revision
	_paint(human, at_stall)


func _set_filter(category: String) -> void:
	_filter = category
	_built_revision = -1


func _rebuild() -> void:
	for child in _cards.get_children():
		child.queue_free()
	for index in CATEGORIES.size():
		_filter_buttons[index].modulate = Color(1.2, 1.1, 0.7) if CATEGORIES[index] == _filter else Color.WHITE
	for item in BalanceStore.items():
		if _filter != "all" and item.category != _filter:
			continue
		_cards.add_child(_card(item))


func _card(item: ItemDefinition) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 150)
	card.set_meta("item_id", item.id)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.13, 0.11, 1.0)
	style.border_color = Color(0.55, 0.48, 0.28)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	card.add_child(box)
	var name := Label.new()
	name.name = "Name"
	name.text = item.display_name
	name.add_theme_font_size_override("font_size", 20)
	name.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86))
	box.add_child(name)
	var detail := Label.new()
	detail.name = "Detail"
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(190, 48)
	detail.text = item.mod_text() if not item.mod_text().is_empty() else item.category.capitalize()
	detail.add_theme_color_override("font_color", Color(0.82, 0.8, 0.7))
	box.add_child(detail)
	var button := Button.new()
	button.name = "Buy"
	button.pressed.connect(_buy.bind(item.id))
	box.add_child(button)
	return card


func _paint(human: SimUnit, at_stall: bool) -> void:
	var rules := BalanceStore.rules()
	var full := human.owned.size() >= int(rules["inventory_slots"])
	var actives := 0
	for owned_id in human.owned:
		var owned := BalanceStore.item(owned_id)
		if owned != null and owned.active != "none":
			actives += 1
	for card in _cards.get_children():
		var item := BalanceStore.item(str(card.get_meta("item_id")))
		if item == null:
			continue
		var button := card.get_node("Buy") as Button
		if human.owns(item.id):
			button.text = "Owned"
			button.disabled = true
		elif not at_stall:
			button.text = "%d gold" % item.price
			button.disabled = true
		elif full:
			button.text = "Bag full"
			button.disabled = true
		elif item.active != "none" and actives >= int(rules["active_slots"]):
			button.text = "Active full"
			button.disabled = true
		else:
			button.text = "%d gold" % item.price
			button.disabled = human.state.gold < item.price


func _buy(item_id: String) -> void:
	if _sim == null:
		return
	var human := _sim.get_human()
	if human == null:
		return
	var cmd := Command.new()
	cmd.unit_id = human.unit_id
	cmd.kind = Command.Kind.BUY
	cmd.item_id = item_id
	_sim.submit_command(cmd)
