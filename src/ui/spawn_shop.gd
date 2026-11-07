class_name SpawnShop extends CanvasLayer

## Opens beside your own spawn stall. Buying is a command, so gold only leaves through the simulation.

var _sim: Simulation
var _panel: PanelContainer
var _list: VBoxContainer
var _gold: Label
var _hint: Label
var _built_revision := -1


func bind(sim: Simulation) -> void:
	_sim = sim


func _ready() -> void:
	layer = 24
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_panel.offset_left = -460.0
	_panel.offset_right = -24.0
	_panel.offset_top = -280.0
	_panel.offset_bottom = 280.0
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "Spawn shop"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86))
	box.add_child(title)
	_gold = Label.new()
	_gold.add_theme_font_size_override("font_size", 22)
	_gold.add_theme_color_override("font_color", Color(1.0, 0.86, 0.28))
	box.add_child(_gold)
	_hint = Label.new()
	_hint.text = "Stand at the stall. 1 uses an active you own."
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_color", Color(0.8, 0.78, 0.68))
	box.add_child(_hint)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 420)
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)


func _process(_delta: float) -> void:
	if _sim == null or _panel == null:
		return
	var human := _sim.get_human()
	var open := human != null and human.state.alive and _sim.near_shop(human)
	_panel.visible = open
	if not open:
		return
	_gold.text = "GOLD  %d" % human.state.gold
	if _built_revision != BalanceStore.revision:
		_rebuild(human)
		_built_revision = BalanceStore.revision
	else:
		_paint(human)


func _rebuild(human: SimUnit) -> void:
	for child in _list.get_children():
		child.queue_free()
	var last := ""
	for item in BalanceStore.items():
		if item.category != last:
			last = item.category
			var heading := Label.new()
			heading.text = item.category.capitalize()
			heading.add_theme_font_size_override("font_size", 16)
			heading.add_theme_color_override("font_color", Color(0.95, 0.84, 0.45))
			_list.add_child(heading)
		var row := HBoxContainer.new()
		var name := Label.new()
		name.name = "Name"
		name.custom_minimum_size = Vector2(250, 28)
		name.add_theme_color_override("font_color", Color(0.94, 0.92, 0.84))
		var button := Button.new()
		button.name = "Buy"
		button.custom_minimum_size = Vector2(120, 28)
		button.pressed.connect(_buy.bind(item.id))
		row.set_meta("item_id", item.id)
		row.add_child(name)
		row.add_child(button)
		_list.add_child(row)
	_paint(human)


func _paint(human: SimUnit) -> void:
	for row in _list.get_children():
		if not row.has_meta("item_id"):
			continue
		var item := BalanceStore.item(str(row.get_meta("item_id")))
		if item == null:
			continue
		var name := row.get_node("Name") as Label
		name.text = "%s\n%s" % [item.display_name, item.mod_text()]
		var button := row.get_node("Buy") as Button
		if human.owns(item.id):
			button.text = "Owned"
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
