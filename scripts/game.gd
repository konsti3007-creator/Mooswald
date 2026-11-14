extends Node2D
## Game shell: input, user interface, audio and save files.
## Simulation: village.gd (+ sim/), rendering: view/world_view.gd.
const Model = preload("res://scripts/village.gd")
const WorldView = preload("res://scripts/view/world_view.gd")
const Residents = preload("res://scripts/sim/residents.gd")
const Sfx = preload("res://scripts/audio/sfx.gd")
const TILE := Vector2(72,36)
const SAVE := "user://village_v1.json"
const SETTINGS := "user://settings.cfg"
const NAMES := ["Moosbart","Eichela","Farnwin","Lindel","Kieselin","Birkla","Tannjo","Holunda","Wurzelin","Fili","Haselmut","Ilmi","Bucheck","Mirabel","Schlehwin","Ahornia","Rindel","Distelin","Weidrun","Erlo","Brombel","Quendel","Mispel","Ulmo"]
const CATEGORIES := ["Wohnen","Bewohner","Ernte","Tiere","Handwerk","Wege","Natur"]
var village = Model.new()
var world: WorldView
var camera: Camera2D
var art: Dictionary = {}
var selected := "Weg"
var mode := "Bauen"
var category := "Wege"
var last_road := Vector2i(-1,-1)
var hover := Vector2i(-1,-1)
var moving := Vector2i(-1,-1)
var inspected := Vector2i(-1,-1)
var inspected_resident := -1
var stats: Label
var status: Label
var quest_label: Label
var detail: Label
var people_label: Label
var catalog: VBoxContainer
var xp_bar: ProgressBar
var clock_label: Label
var speed_buttons: Dictionary = {}
var grid := false
var dragging := false
var ui_timer := 0.0
var save_timer := 0.0
var dark := false
var show_status := true
var reset_dialog: ConfirmationDialog
var tips: AcceptDialog
var options: AcceptDialog
var quit_dialog: ConfirmationDialog
var wish_button: Button
var stock_label: Label
var crop_selector: OptionButton
var catalog_info: Label
var sell_rows: Dictionary = {}
var crop_keys: Array = []
var crop_for := Vector2i(-2,-2)
var ui_theme: Theme
var catalog_level := 0
var category_selector: OptionButton
var right_tabs: TabContainer
var trade_label: Label
var upgrade_button: Button
var production_button: Button
var ambient: AudioStreamPlayer
var sfx: Node
var volumes := {"Master": 0.8, "Ambience": 0.6, "SFX": 0.8}
var sound_on := false
var panels_visible := true
var layout_panels: Dictionary = {}
var main_panels: Array[Control] = []
var atlas: Texture2D
var happiness_label: Label
var first_start := false

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("4f6e3c"))
	atlas = load("res://assets/painted/village-atlas.png")
	var ordering := ["Haus","Forsthaus","Saegewerk","Muehle","Baeckerei","Steinbruch","Imkerei","Beeren","Kochhaus","Gasthaus","Baum","Blumenbeet","Brunnen","Bank","Laterne","Strauch"]
	var cell_size := Vector2(atlas.get_size())/4.0
	for index in range(ordering.size()):
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		texture.region = Rect2(Vector2(index%4,index/4)*cell_size,cell_size)
		texture.filter_clip = true
		art[ordering[index]] = texture
	art.Feld = load("res://assets/art/Feld.svg")
	art.Wildbaum = art.Baum
	for kind in Model.SPECIAL_HOUSES: art[kind] = art.Haus
	# Placeholder pictures until own paintings exist (marked by their sign).
	for kind in Model.DEFS:
		if Model.DEFS[kind].has("art"): art[kind] = art[Model.DEFS[kind].art]
	camera = Camera2D.new()
	camera.position = cell_pos(Vector2i(14,11))
	camera.zoom = Vector2(1.0,1.0)
	add_child(camera)
	world = WorldView.new()
	add_child(world)
	world.setup(self)
	_setup_audio()
	_theme()
	_setup_ui()
	get_viewport().size_changed.connect(_layout_ui)
	_layout_ui()
	_load_settings()
	if not _load(false):
		village.seed()
		first_start = true
	world.rebuild()
	_update_ui()
	if first_start and not "--capture" in " ".join(OS.get_cmdline_user_args()):
		tips.call_deferred("popup_centered", Vector2i(700,520))
	var capture := ""
	var wait := 2.0
	for argument in OS.get_cmdline_user_args():
		if argument == "--capture": capture = "res://build/screenshot.png"
		elif argument.begins_with("--capture="): capture = argument.trim_prefix("--capture=")
		elif argument.begins_with("--zoom="): camera.zoom = Vector2.ONE * float(argument.trim_prefix("--zoom="))
		elif argument.begins_with("--focus="):
			var xy := argument.trim_prefix("--focus=").split(",")
			camera.position = world.grid_to_screen(Vector2(float(xy[0]), float(xy[1])))
		elif argument.begins_with("--wait="): wait = float(argument.trim_prefix("--wait="))
		elif argument == "--hide-ui":
			for panel in layout_panels.values(): panel.visible = false
		elif argument.begins_with("--speed="): village.speed = float(argument.trim_prefix("--speed="))
	if not capture.is_empty():
		await get_tree().create_timer(wait).timeout
		get_viewport().get_texture().get_image().save_png(capture)
		get_tree().quit()

func cell_pos(c: Vector2i) -> Vector2:
	return Vector2((c.x-c.y)*TILE.x/2,(c.x+c.y)*TILE.y/2)

func world_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x/TILE.x + p.y/TILE.y + 0.5),floori(p.y/TILE.y - p.x/TILE.x + 0.5))

# ------------------------------------------------------------------ theme/UI

func _theme() -> void:
	var theme := Theme.new()
	theme.default_font_size = 15
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("fff4d9")
	panel.border_color = Color("ae8d56")
	panel.shadow_color = Color("304b3540")
	panel.shadow_size = 5
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(14)
	panel.content_margin_left = 16
	panel.content_margin_right = 16
	panel.content_margin_top = 12
	panel.content_margin_bottom = 12
	theme.set_stylebox("panel","PanelContainer",panel)
	theme.set_stylebox("panel","TooltipPanel",panel)
	var dialog := panel.duplicate()
	theme.set_stylebox("panel","AcceptDialog",dialog)
	theme.set_stylebox("panel","ConfirmationDialog",dialog)
	theme.set_color("font_color","TooltipLabel",Color("2b493b"))
	theme.set_color("font_color","Label",Color("2b493b"))
	theme.set_color("font_color","CheckBox",Color("2b493b"))
	theme.set_color("font_hover_color","CheckBox",Color("203d30"))
	theme.set_color("font_pressed_color","CheckBox",Color("203d30"))
	for state in ["normal","hover","pressed","disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color({"normal":"e6e2c8","hover":"d0ddad","pressed":"b4c68e","disabled":"ebe6d8"}[state])
		box.set_corner_radius_all(7)
		box.content_margin_top = 7
		box.content_margin_bottom = 7
		box.content_margin_left = 10
		box.content_margin_right = 10
		theme.set_stylebox(state,"Button",box)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0,0,0,0)
	focus.border_color = Color("8fa866")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(7)
	theme.set_stylebox("focus","Button",focus)
	theme.set_color("font_focus_color","Button",Color("203d30"))
	theme.set_color("font_color","Button",Color("2d493b"))
	theme.set_color("font_hover_color","Button",Color("203d30"))
	theme.set_color("font_pressed_color","Button",Color("203d30"))
	theme.set_color("font_disabled_color","Button",Color("96988b"))
	var tab_panel := StyleBoxFlat.new()
	tab_panel.bg_color = Color("fff4d9")
	tab_panel.content_margin_top = 12
	theme.set_stylebox("panel","TabContainer",tab_panel)
	theme.set_font_size("font_size","TabBar",12)
	theme.set_font_size("font_size","TabContainer",12)
	for tab_state in ["tab_selected","tab_unselected","tab_hovered"]:
		var tab_style := StyleBoxFlat.new()
		tab_style.bg_color = Color("d5dfb6") if tab_state == "tab_selected" else Color("ece5c9")
		tab_style.content_margin_left = 6
		tab_style.content_margin_right = 6
		tab_style.content_margin_top = 8
		tab_style.content_margin_bottom = 8
		tab_style.set_corner_radius_all(6)
		theme.set_stylebox(tab_state,"TabBar",tab_style)
		theme.set_stylebox(tab_state,"TabContainer",tab_style)
	theme.set_color("font_selected_color","TabBar",Color("2b493b"))
	theme.set_color("font_selected_color","TabContainer",Color("2b493b"))
	theme.set_color("font_unselected_color","TabContainer",Color("61704d"))
	theme.set_color("font_unselected_color","TabBar",Color("61704d"))
	ui_theme = theme

func _panel(at: Vector2, size: Vector2, parent: Node, key: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme = ui_theme
	panel.position = at
	panel.custom_minimum_size = size
	parent.add_child(panel)
	layout_panels[key] = panel
	if key in ["left","right"]: main_panels.append(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",7)
	panel.add_child(box)
	return box

func _label(text_value: String, parent: Node, font_size := 15) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size",font_size)
	parent.add_child(label)
	return label

func _button(text_value: String, parent: Node, action: Callable) -> Button:
	var b := Button.new()
	b.text = text_value
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := _panel(Vector2(18,16),Vector2(1328,105),layer,"top")
	var row := HBoxContainer.new()
	top.add_child(row)
	var title := _label("MOOSWINKEL",row,26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_label = _label("",row,16)
	for value in [0,1,2,4]:
		speed_buttons[value] = _button("Pause" if value == 0 else "%d×" % value,row,func(): village.speed = value; _update_ui())
	_button("Optionen",row,func(): options.popup_centered(Vector2i(520,470)))
	_button("Beenden",row,func(): quit_dialog.popup_centered())
	_button("?",row,func(): tips.popup_centered(Vector2i(700,520)))
	stats = _label("",top,14)
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size.y = 8
	xp_bar.show_percentage = false
	top.add_child(xp_bar)
	var left := _panel(Vector2(18,152),Vector2(250,600),layer,"left")
	_label("DEIN WALDDORF",left,19)
	var tools := HBoxContainer.new()
	left.add_child(tools)
	for tool in ["Bauen","Info","Bewegen","Abriss"]:
		var b := _button(tool,tools,func(): mode = tool; moving = Vector2i(-1,-1); _update_ui())
		b.add_theme_font_size_override("font_size",12)
		b.tooltip_text = {"Bauen":"Ausgewähltes Motiv in die Welt setzen","Info":"Gebäude oder Waldlinge anklicken","Bewegen":"Gebäude anklicken, dann Zielplatz","Abriss":"Gebäude entfernen, Hälfte der Kosten zurück"}[tool]
	var categories := OptionButton.new()
	category_selector = categories
	for name in CATEGORIES: categories.add_item(name)
	categories.select(CATEGORIES.find("Wege"))
	categories.item_selected.connect(func(index): category = categories.get_item_text(index); _catalog())
	left.add_child(categories)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(230,170)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	catalog = VBoxContainer.new()
	catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(catalog)
	# Always visible: what the chosen building does / who moves in.
	var info_panel := PanelContainer.new()
	var info_style := StyleBoxFlat.new()
	info_style.bg_color = Color("f3e8c8")
	info_style.set_corner_radius_all(8)
	info_style.content_margin_left = 8
	info_style.content_margin_right = 8
	info_style.content_margin_top = 6
	info_style.content_margin_bottom = 6
	info_panel.add_theme_stylebox_override("panel", info_style)
	left.add_child(info_panel)
	catalog_info = _label("", info_panel, 12)
	catalog_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	catalog_info.custom_minimum_size = Vector2(214, 96)
	var harvest := _button("Alle reifen Felder ernten",left,func():
		for c in village.buildings.keys():
			if village.buildings.has(c) and village.buildings[c].get("progress",0.0) >= 1.0: village.harvest(c)
		_update_ui())
	harvest.tooltip_text = "Erntet sofort von Hand. Freie Waldlinge ernten reife Beete auch selbst."
	_button("Im Wald sammeln",left,func(): village.gather(); _update_ui())
	_button("Erzeugnisse verkaufen",left,func(): village.sell(); _update_ui())
	var actions := HBoxContainer.new()
	left.add_child(actions)
	_button("Speichern",actions,_save)
	_button("Laden",actions,func():
		if _load(true): world.rebuild()
		_update_ui())
	_button("Neues Dorf",actions,func(): reset_dialog.popup_centered())
	var right := _panel(Vector2(1040,152),Vector2(300,475),layer,"right")
	var tabs := TabContainer.new()
	right_tabs = tabs
	tabs.custom_minimum_size = Vector2(268,440)
	right.add_child(tabs)
	for page in ["Aufträge","Gebäude","Bewohner","Lager"]:
		var content := VBoxContainer.new()
		content.name = page
		content.add_theme_constant_override("separation",12)
		tabs.add_child(content)
		if page == "Aufträge":
			quest_label = _label("",content)
			quest_label.custom_minimum_size.x = 209
			quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_label("DEINE LICHTUNG",content,17)
			happiness_label = _label("",content,14)
			happiness_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			wish_button = _button("Anderer Dorfwunsch",content,func(): village.skip_wish(); _update_ui())
			wish_button.add_theme_font_size_override("font_size",12)
			_button("Neues Land erschließen",content,func(): village.expand(); _update_ui())
		elif page == "Gebäude":
			detail = _label("",content,14)
			detail.custom_minimum_size = Vector2(209,220)
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			upgrade_button = _button("Gebäude ausbauen",content,func(): village.upgrade(inspected); _update_ui())
			production_button = _button("Betrieb pausieren / fortsetzen",content,func(): village.toggle_production(inspected); _update_ui())
			production_button.add_theme_font_size_override("font_size",12)
			crop_selector = OptionButton.new()
			crop_selector.add_theme_font_size_override("font_size",13)
			crop_selector.item_selected.connect(func(index):
				if not village.buildings.has(inspected): return
				var bed: Dictionary = village.buildings[inspected]
				if bed.type != "Feld": return
				bed.next_crop = crop_keys[index]
				if not bed.sown: bed.crop = crop_keys[index]
				village.notice = "Nächste Aussaat: %s." % Model.CROPS[crop_keys[index]].label
				_update_ui())
			content.add_child(crop_selector)
		elif page == "Bewohner":
			people_label = _label("",content,14)
			people_label.custom_minimum_size = Vector2(209,260)
			people_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		else:
			stock_label = _label("",content,13)
			stock_label.custom_minimum_size.x = 209
			stock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			# Direct sale per good: 10 pieces or everything above half the store.
			var sell_scroll := ScrollContainer.new()
			sell_scroll.custom_minimum_size = Vector2(250, 190)
			sell_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			content.add_child(sell_scroll)
			var grid := GridContainer.new()
			grid.columns = 3
			grid.add_theme_constant_override("h_separation", 4)
			sell_scroll.add_child(grid)
			for k in Model.PRICES:
				var name_l := _label("", grid, 12)
				name_l.custom_minimum_size.x = 112
				var b10 := _button("10", grid, func(): village.sell_good(k, 10); _update_ui())
				b10.add_theme_font_size_override("font_size", 11)
				var bmore := _button("Überschuss", grid, func(): village.sell_good(k, int(village.resources.get(k,0)) - village.capacity(k) / 2); _update_ui())
				bmore.add_theme_font_size_override("font_size", 11)
				sell_rows[k] = [name_l, b10, bmore]
			_label("WALDHANDEL",content,16)
			trade_label = _label("",content,13)
			trade_label.custom_minimum_size = Vector2(209,120)
			trade_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_button("Auftrag liefern",content,func(): village.deliver(); _update_ui())
			_button("Erzeugnisse verkaufen",content,func(): village.sell(); _update_ui())
	var bottom := _panel(Vector2(284,744),Vector2(1062,62),layer,"bottom")
	status = _label("",bottom)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.x = 1020
	_label("Linke Maustaste: bauen / auswählen  ·  Rechtsklick: Info & Ernte  ·  Mausrad: Zoom  ·  Mittlere Maustaste / WASD: Kamera  ·  Leertaste: Pause  ·  Tab: Leisten",bottom,12)
	reset_dialog = ConfirmationDialog.new()
	reset_dialog.theme = ui_theme
	reset_dialog.title = "Ein neues Dorf?"
	reset_dialog.dialog_text = "Das aktuelle Dorf wird zurückgesetzt. Der gespeicherte Stand bleibt bis zum nächsten Speichern erhalten."
	reset_dialog.ok_button_text = "Neu beginnen"
	reset_dialog.cancel_button_text = "Abbrechen"
	reset_dialog.confirmed.connect(func():
		village = Model.new()
		village.seed()
		moving = Vector2i(-1,-1)
		inspected = moving
		inspected_resident = -1
		world.rebuild()
		_update_ui())
	layer.add_child(reset_dialog)
	quit_dialog = ConfirmationDialog.new()
	quit_dialog.theme = ui_theme
	quit_dialog.title = "Mooswinkel beenden?"
	quit_dialog.dialog_text = "Dein Dorf wird gespeichert und das Spiel geschlossen."
	quit_dialog.ok_button_text = "Speichern und beenden"
	quit_dialog.cancel_button_text = "Weiterspielen"
	quit_dialog.confirmed.connect(quit_game)
	layer.add_child(quit_dialog)
	tips = AcceptDialog.new()
	tips.theme = ui_theme
	tips.title = "Willkommen in Mooswinkel"
	tips.ok_button_text = "Los geht's"
	tips.dialog_text = "Baue dein eigenes kleines Walddorf – ganz ohne Echtgeld.\n\nDEINE WALDLINGE arbeiten selbst: Holzfäller gehen von der Forsthütte zu den Bäumen,\nfällen sie Schlag für Schlag und tragen das Holz zurück. Kieselsammler holen Stein\nvon Findlingen. Freie Waldlinge säen, gießen und ernten die Beete und bringen\ndie Körbe nach Hause. Werkstätten brauchen einen Waldling, der Rohstoffe holt\nund dort arbeitet. Gefällte Bäume wachsen nach; Förster pflanzen neue.\n\nBAUEN: Kategorie und Motiv links wählen, dann in die Welt klicken.\nGrüne Vorschau: frei und bezahlbar. Waldwege zieht man mit gedrückter Maustaste.\nINFO: Gebäude oder Waldlinge anklicken. Rechtsklick erntet reife Beete sofort.\nSymbole über Gebäuden: ? kein Arbeiter · … wartet auf Waren · II pausiert · ! kein Weg.\n\nMehr Häuser = mehr Waldlinge. Jede Ausbaustufe einer Werkstatt schafft einen\nweiteren Arbeitsplatz. Waldlinge brauchen Nahrung, sonst werden sie langsamer.\nDer Waldspaziergang hilft jederzeit aus einer Flaute.\n\nPause: Leertaste · Zoom: Mausrad · Kamera: WASD · Speichern: F5 · Vollbild: F11"
	layer.add_child(tips)
	_setup_options(layer)
	_catalog()

func _setup_options(layer: CanvasLayer) -> void:
	options = AcceptDialog.new()
	options.theme = ui_theme
	options.title = "Optionen"
	options.ok_button_text = "Fertig"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",10)
	options.add_child(box)
	var sound := CheckBox.new()
	sound.text = "Klang einschalten"
	sound.button_pressed = sound_on
	sound.toggled.connect(func(on): sound_on = on; _apply_audio(); _save_settings())
	box.add_child(sound)
	for bus in [["Master","Gesamtlautstärke"],["Ambience","Waldatmosphäre"],["SFX","Arbeitsgeräusche"]]:
		_label(bus[1],box,14)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.05
		slider.value = volumes[bus[0]]
		slider.custom_minimum_size.x = 420
		slider.value_changed.connect(func(value): volumes[bus[0]] = value; _apply_audio(); _save_settings())
		box.add_child(slider)
	for flag in [["Vollbild (F11)","fullscreen"],["Nachtlicht: Nächte bleiben hell","dark"],["Raster anzeigen (G)","grid"],["Statussymbole über Gebäuden","status"]]:
		var check := CheckBox.new()
		check.text = flag[0]
		check.set_meta("flag",flag[1])
		box.add_child(check)
		check.toggled.connect(func(on):
			match flag[1]:
				"fullscreen": get_window().mode = Window.MODE_FULLSCREEN if on else Window.MODE_WINDOWED
				"dark": dark = on
				"grid": grid = on; world.ground_revision = -1
				"status": show_status = on
			_save_settings())
	options.about_to_popup.connect(func():
		sound.set_pressed_no_signal(sound_on)
		for child in box.get_children():
			if child is CheckBox and child.has_meta("flag"):
				var value := false
				match child.get_meta("flag"):
					"fullscreen": value = get_window().mode in [Window.MODE_FULLSCREEN,Window.MODE_EXCLUSIVE_FULLSCREEN]
					"dark": value = dark
					"grid": value = grid
					"status": value = show_status
				child.set_pressed_no_signal(value))
	layer.add_child(options)

func _catalog() -> void:
	catalog_level = village.level()
	if category_selector != null:
		category_selector.select(CATEGORIES.find(category))
	for child in catalog.get_children():
		catalog.remove_child(child)
		child.queue_free()
	for kind in Model.DEFS:
		var d: Dictionary = Model.DEFS[kind]
		if d.category != category: continue
		var unlocked: bool = village.level() >= d.level
		var b := Button.new()
		b.custom_minimum_size = Vector2(218,92)
		b.pressed.connect(func(): selected = kind; mode = "Bauen"; moving = Vector2i(-1,-1); _catalog(); _update_ui())
		b.disabled = not unlocked
		b.tooltip_text = _describe(kind)
		catalog.add_child(b)
		var row := HBoxContainer.new()
		row.position = Vector2(6,5)
		row.size = Vector2(204,82)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(row)
		if art.has(kind):
			var icon := TextureRect.new()
			icon.texture = art[kind]
			icon.custom_minimum_size = Vector2(48,56)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(icon)
		var labels := VBoxContainer.new()
		labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(labels)
		var name_label := _label(("› " if selected == kind else "")+d.label,labels,13)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.custom_minimum_size.x = 140
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var does := _label(_summary(kind),labels,11)
		does.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		does.mouse_filter = Control.MOUSE_FILTER_IGNORE
		does.add_theme_color_override("font_color", Color("4f6a3a"))
		var sub := _cost(d.cost) if unlocked else "Ab Stufe %d" % d.level
		if d.has("special") and village.count(kind) > 0: sub = "%s wohnt schon hier." % Model.SPECIALISTS[d.special].name
		var cost_label := _label(sub,labels,11)
		cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if unlocked and not village.afford(d.cost): cost_label.add_theme_color_override("font_color", Color("b0433a"))
		if not unlocked: b.modulate = Color(0.65,0.7,0.62)

## One line on the catalog card: what it makes or who moves in.
func _summary(kind: String) -> String:
	var d: Dictionary = Model.DEFS[kind]
	if d.has("special"):
		var sp: Dictionary = Model.SPECIALISTS[d.special]
		return "Bringt %s, %s" % [sp.name, sp.role]
	match kind:
		"Haus": return "2 Waldlinge je Ausbaustufe"
		"Feld": return "8 Sorten: Korn, Gemüse, Flachs …"
		"Beeren": return "→ 5 Beeren, 2 Nahrung"
		"Forsthaus": return "Holzfäller: 8 Holz je Gang"
		"Steinbruch": return "Steinsammler: 5 Stein je Gang"
		"Angler": return "Angler: 4 Fisch je Fang"
		"Lager": return "+150 Platz je Ware"
		"Weg": return "Waldlinge gehen schneller"
		"Wildbaum": return "Wächst für Holzfäller nach"
		"Gasthaus": return "Brot + Marmelade → Münzen"
		"Huehnerhof": return "Hühner: 2 Korn → 4 Eier"
		"Schafweide": return "Schafe: 2 Korn → 3 Wolle"
		"Ziegenstall": return "Ziegen: 1 Korn → 3 Milch"
	if d.has("output"):
		var ins := _cost(d.input) if not d.input.is_empty() else "Wiese"
		return "%s → %s" % [ins, _cost(d.output)]
	return "Schmuck für das Dorf"

func _describe(kind: String) -> String:
	var d: Dictionary = Model.DEFS[kind]
	var text := "%s · %d × %d Bauplatz · ab Dorfstufe %d" % [d.label,d.size.x,d.size.y,d.level]
	if d.has("special"):
		var sp: Dictionary = Model.SPECIALISTS[d.special]
		return text + "\nBringt %s, %s, ins Dorf.\n%s\nNur einmal baubar." % [sp.name,sp.role,sp.effect]
	match kind:
		"Haus": text += "\nPlatz für 2 Waldlinge pro Ausbaustufe."
		"Feld": text += "\nFreie Waldlinge säen, gießen und ernten. Sorte im Info-Feld wählbar: Korn, Karotten, Kohl, Kartoffeln, Zwiebeln, Kürbisse, Flachs, Sonnenblumen."
		"Angler": text += "\nAngler fangen Fische am Ufer (im Sommer schneller, im Winter langsamer). Nur in Wassernähe baubar."
		"Lager": text += "\nJede Ausbaustufe schafft Platz für 150 weitere Stück jeder Ware."
		"Huehnerhof", "Schafweide", "Ziegenstall":
			text += "\nGehege 3 × 3. Eine Hirtin oder ein Hirte holt Futter und versorgt die Tiere: %s → %s in %d Sekunden. Mehr Tiere und Arbeitsplätze je Ausbaustufe." % [_cost(d.input), _cost(d.output), int(d.duration)]
		"Beeren": text += "\nFreie Waldlinge pflücken reife Beeren: 5 Beeren, 2 Nahrung."
		"Forsthaus": text += "\nHolzfäller fällen Bäume im Umkreis von 8 Feldern und pflanzen nach. 8 Holz pro Gang."
		"Steinbruch": text += "\nSammelt Stein an Findlingen in der Nähe, sonst am eigenen Fels."
		"Wildbaum": text += "\nWächst zu einem Baum heran, den Holzfäller ernten können."
		_:
			if d.has("output"): text += "\n%s → %s, %d Sekunden. Braucht einen Waldling." % [_cost(d.input) if not d.input.is_empty() else "Wiese", _cost(d.output), int(d.duration)]
	return text

func _cost(items: Dictionary) -> String:
	var parts: Array[String] = []
	for k in items: parts.append("%d %s" % [items[k],Model.NAMES.get(k,k.capitalize())])
	return ", ".join(parts) if not parts.is_empty() else "kostenlos"

func resident_name(r: Dictionary) -> String:
	if Model.SPECIALISTS.has(r.get("special","")):
		var sp: Dictionary = Model.SPECIALISTS[r.special]
		return "%s, %s" % [sp.name,sp.role]
	return NAMES[(int(r.id) * 7) % NAMES.size()] + ("" if r.id < NAMES.size() else " %d" % (r.id / NAMES.size() + 1))

func _workers_of(id: int) -> Array:
	var list: Array = []
	for r in village.residents:
		if r.job == id: list.append(r)
	return list

## Building state shown as an icon in the world and in the info panel.
func building_state(b: Dictionary) -> String:
	if village.is_house(b.type):
		return "trapped" if village.entrances(village.anchor_of(b.id)).is_empty() else ""
	if not village.is_workplace(b.type): return ""
	if b.paused: return "paused"
	var d0: Dictionary = Model.DEFS[b.type]
	var goods: Array = [d0.gather] if d0.has("gather") else d0.get("output", {}).keys()
	for k in goods:
		if k != "muenzen" and not village.has_space(k, 3): return "full"
	var crew := _workers_of(b.id)
	if crew.is_empty(): return "no_worker"
	for r in crew:
		if r.get("blocked",0) > 1 and r.task.is_empty(): return "blocked"
	if b.get("crew",0) > 0 or b.working: return "working"
	var d: Dictionary = Model.DEFS[b.type]
	if d.has("input") and not d.input.is_empty() and b.supply <= 0:
		if not village.afford(d.input): return "waiting"
	return ""

func _update_ui() -> void:
	if catalog_level != village.level(): _catalog()
	var r: Dictionary = village.resources
	stats.text = "Holz %d  ·  Stein %d  ·  Nahrung %d  ·  Korn %d  ·  Mehl %d  ·  Bretter %d  ·  Brot %d  ·  Münzen %d\nDorfstufe %d · %d/%d Erfahrung     Beeren %d  ·  Honig %d  ·  Marmelade %d" % [r.holz,r.stein,r.nahrung,r.getreide,r.mehl,r.bretter,r.brot,r.muenzen,village.level(),village.xp,Model.xp_for_level(village.level()+1),r.beeren,r.honig,r.marmelade]
	xp_bar.value = village.level_progress() * 100.0
	clock_label.text = "%s, Tag %d · %02d:%02d · %d Waldlinge  " % [Model.SEASONS[village.season()].name,village.season_day(),int(fmod(village.elapsed/240*24+7,24)),int(fmod(village.elapsed,10)*6),village.population()]
	for value in speed_buttons:
		speed_buttons[value].modulate = Color(0.75,0.95,0.7) if float(value) == village.speed else Color.WHITE
	status.text = village.notice
	if village.quest < Model.QUESTS.size():
		var q: Dictionary = Model.QUESTS[village.quest]
		var n: int = village.quest_progress(q)
		quest_label.text = "%d / %d · %s\n\n%s\n\nFortschritt: %d / %d\nBelohnung: %d Münzen · %d Erfahrung" % [village.quest+1,Model.QUESTS.size(),q.title,q.hint,mini(n,q.goal),q.goal,q.coins,q.xp]
	elif not village.wish.is_empty():
		var p: Array = village.wish_progress()
		quest_label.text = "Dorfwunsch Nr. %d\n\n%s\n\nFortschritt: %d / %d\nBelohnung: %d Münzen · %d Erfahrung" % [village.wishes_done+1,village.wish.title,maxi(0,p[0]),p[1],village.wish.coins,village.wish.xp]
	else: quest_label.text = "Ein Dorf voller Leben"
	wish_button.visible = village.quest >= Model.QUESTS.size()
	var lines: Array[String] = ["LAGER · Platz je Ware: %d" % village.capacity("holz")]
	for group in Model.RESOURCE_GROUPS:
		var parts: Array[String] = []
		for k in group[1]: parts.append("%s %d" % [Model.NAMES[k],r.get(k,0)])
		lines.append("%s: %s" % [group[0],", ".join(parts)])
	stock_label.text = "\n".join(lines)
	for k in sell_rows:
		var row: Array = sell_rows[k]
		var have: int = int(r.get(k, 0))
		var price: int = int(Model.PRICES[k]) * (13 if village.has_special("handel") else 10) / 10
		row[0].text = "%s %d (%d/St.)" % [Model.NAMES[k], have, price]
		row[1].disabled = have <= 0
		row[2].disabled = have <= village.capacity(k) / 2
	_update_catalog_info()
	_update_building_panel()
	_update_people_panel()
	var q: Dictionary = village.contract()
	trade_label.text = "%s\n\nLieferung: %d %s\nBelohnung: %d Münzen + %d Erfahrung\n\n%s\n\nDer freie Verkauf kauft jeweils drei Waren." % [q.title,q.amount,Model.NAMES[q.kind],q.coins,q.xp,"Bereit zur Lieferung" if village.contract_time <= 0 else "Neue Lieferung in %ds" % ceili(village.contract_time)]
	var idle := 0
	for res in village.residents:
		if res.job < 0: idle += 1
	happiness_label.text = "%d Waldlinge · %d frei für Beete\n%d Nahrung pro Minute\n%s\n\nLichtung %d/3\nNächste Fläche: %s" % [village.population(),idle,ceili(village.population()/2.0),"Alle sind satt." if not village.hungry else "Zu wenig Nahrung: Die Waldlinge arbeiten langsamer.",village.expansion+1,_cost(village.expansion_cost()) if village.expansion < 2 else "Alles erschlossen"]

func _update_catalog_info() -> void:
	var d: Dictionary = Model.DEFS[selected]
	var text := _describe(selected) + "\nKosten: " + _cost(d.cost)
	var gap: String = village.missing_text(d.cost)
	if village.level() < d.level: text += "\nNoch gesperrt (ab Dorfstufe %d)." % d.level
	elif gap != "": text += "\n" + gap
	catalog_info.text = text

func _update_building_panel() -> void:
	upgrade_button.disabled = not village.buildings.has(inspected)
	upgrade_button.text = "Gebäude ausbauen"
	if village.buildings.has(inspected):
		var bb: Dictionary = village.buildings[inspected]
		if bb.type in Model.DECORATIONS or Model.DEFS[bb.type].has("special"):
			upgrade_button.disabled = true
			upgrade_button.text = "Kein Ausbau möglich"
		elif bb.tier >= 3:
			upgrade_button.disabled = true
			upgrade_button.text = "Höchste Stufe erreicht"
		else:
			var uc: Dictionary = village.upgrade_cost(inspected)
			upgrade_button.text = "Ausbauen: " + _cost(uc)
			if village.level() < bb.tier + 2: upgrade_button.text = "Ausbau ab Dorfstufe %d" % (bb.tier + 2)
			elif not village.afford(uc): upgrade_button.text = village.missing_text(uc)
	var is_bed: bool = village.buildings.has(inspected) and village.buildings[inspected].type == "Feld"
	crop_selector.visible = is_bed
	if is_bed and (crop_for != inspected or crop_keys.size() != _unlocked_crops().size()):
		crop_for = inspected
		crop_keys = _unlocked_crops()
		crop_selector.clear()
		for k in crop_keys: crop_selector.add_item("Säen: %s (%d Münzen)" % [Model.CROPS[k].label, Model.CROPS[k].seed])
		crop_selector.select(maxi(0, crop_keys.find(village.buildings[inspected].get("next_crop","korn"))))
	production_button.disabled = not village.buildings.has(inspected) or not village.is_workplace(village.buildings[inspected].type)
	if not village.buildings.has(inspected):
		detail.text = "%s: %s\n%s\n\nKlicke im Info-Modus auf ein Gebäude oder einen Waldling." % [mode,Model.DEFS[selected].label,_cost(Model.DEFS[selected].cost)]
		return
	var b: Dictionary = village.buildings[inspected]
	var d: Dictionary = Model.DEFS[b.type]
	var text := "%s · Ausbau %d/3\n" % [d.label,b.tier]
	var state := building_state(b)
	match b.type:
		"Feld":
			var crop: Dictionary = village.crop_of(b)
			text += "Sorte: %s\n" % crop.label
			if not b.sown: text += "Wartet auf Aussaat (Saatgut %d Münzen)." % Model.CROPS[b.get("next_crop","korn")].seed
			elif village.overripe(b): text += "Überreif! Nur noch halber Ertrag."
			elif b.progress >= 1.0: text += "Reif! Ein freier Waldling erntet es, oder Rechtsklick."
			else: text += "Wachstum: %d%%%s" % [int(b.progress*100), " · gegossen" if b.get("tended",false) else ""]
			text += "\nErtrag: %s" % _cost(crop.harvest)
			text += "\nNächste Aussaat: %s" % Model.CROPS[b.get("next_crop","korn")].label
		"Beeren":
			text += "Reif zum Pflücken." if b.progress >= 1.0 else "Beeren reifen: %d%%" % int(b.progress*100)
		"Wildbaum":
			text = "Waldbaum\n" + ("Holz für %d Gänge." % b.stock if b.stock > 0 else "Wächst nach: %d%%" % int(b.progress*100))
		"Felsen":
			text = "Findling\nStein für %d Gänge. Wächst langsam nach." % b.stock
		"Haus":
			var homes := 0
			for res in village.residents:
				if res.home == b.id: homes += 1
			text += "Zuhause für %d Waldlinge." % homes
			if state == "trapped": text += "\nKein Ausgang! Lege einen Weg oder räume Platz frei."
		"Weg":
			text += "Verbindungen: %d\nWaldlinge gehen auf Wegen schneller." % village.mask(inspected)
		"HausHolz","HausGarten","HausStein","HausBau","HausBaecker","HausImker","HausKraeuter","HausHandel":
			var sp: Dictionary = Model.SPECIALISTS[d.special]
			text = "%s\nHier wohnt %s, %s.\n\n%s" % [d.label,sp.name,sp.role,sp.effect]
			if state == "trapped": text += "\n\nKein Ausgang! Lege einen Weg oder räume Platz frei."
		_:
			if village.is_workplace(b.type):
				var crew := _workers_of(b.id)
				var names: Array[String] = []
				for res in crew: names.append(resident_name(res))
				text += "Arbeitsplätze: %d/%d%s\n" % [crew.size(),b.tier,(" (" + ", ".join(names) + ")") if not names.is_empty() else ""]
				if d.has("gather"):
					text += "Liefert %s durch Arbeitsgänge.\n" % Model.NAMES[d.gather]
				else:
					text += "%s → %s · %d s\nVorrat: %d Zyklen · %d%%\n" % [_cost(d.input) if not d.input.is_empty() else "Wiese",_cost(d.output),int(d.duration),b.supply,int(b.progress*100)]
				text += {"paused":"Pausiert.","no_worker":"Kein Waldling frei – baue ein weiteres Haus.","blocked":"Kein Weg zum Arbeitsort!","waiting":"Wartet auf Rohstoffe.","working":"Arbeitet.","":"Bereit."}.get(state,"")
			else:
				text += "Ein schöner Ort für deine Waldlinge."
	if b.tier < 3 and not b.type in Model.DECORATIONS: text += "\n\nNächster Ausbau: %s" % _cost(village.upgrade_cost(inspected))
	if state == "full": text += "\nLager voll: Baue oder erweitere eine Vorratsscheune oder verkaufe Waren."
	detail.text = text

func _unlocked_crops() -> Array:
	var list: Array = []
	for k in Model.CROPS:
		if village.level() >= int(Model.CROPS[k].level): list.append(k)
	return list

func _update_people_panel() -> void:
	var r: Dictionary = {}
	for res in village.residents:
		if res.id == inspected_resident: r = res
	if r.is_empty():
		var working := 0
		for res in village.residents:
			if not res.task.is_empty() and res.task.type in ["wood","stone","reap","berries","sow","tend","fetch","work","plant"]: working += 1
		people_label.text = "%d Waldlinge, %d gerade bei der Arbeit.\n\nKlicke im Info-Modus auf einen Waldling, um zu sehen, was er gerade tut." % [village.residents.size(),working]
		return
	var job := "Helfer auf den Beeten"
	if r.job >= 0:
		var b: Dictionary = village.building_by_id(r.job)
		if not b.is_empty(): job = Model.DEFS[b.type].label
	var doing: String = Residents.STATE_LABEL.get(r.task.get("type","idle"),"Ruht") if not r.task.is_empty() else "Ruht"
	var carry := ""
	for k in r.carry: carry += "%d %s " % [r.carry[k],Model.NAMES.get(k,k)]
	people_label.text = "%s\n\nArbeit: %s\nTut gerade: %s\nTrägt: %s\nKraft: %d%%%s%s" % [resident_name(r),job,doing,carry if carry != "" else "nichts",int(r.energy*100),"\nHungrig" if village.hungry else "",("\n" + str(r.status)) if r.get("status","") != "" and r.task.is_empty() else ""]

# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			moving = Vector2i(-1,-1)
			mode = "Info"
			inspected_resident = -1
			world.selected_resident = -1
		if event.keycode == KEY_F5: _save()
		if event.keycode == KEY_Q and event.ctrl_pressed: quit_dialog.popup_centered()
		if event.keycode == KEY_F11: get_window().mode = Window.MODE_WINDOWED if get_window().mode in [Window.MODE_FULLSCREEN,Window.MODE_EXCLUSIVE_FULLSCREEN] else Window.MODE_FULLSCREEN
		if event.keycode == KEY_SPACE: village.speed = 1 if village.speed == 0 else 0
		if event.keycode == KEY_G: grid = not grid; world.ground_revision = -1
		if event.keycode == KEY_HOME: camera.position = cell_pos(Vector2i(14,11))
		if event.keycode == KEY_TAB:
			panels_visible = not panels_visible
			for panel in main_panels: panel.visible = panels_visible
		_update_ui()
	if event is InputEventMouseMotion:
		if dragging: camera.position -= event.relative / camera.zoom
		elif mode == "Bauen" and selected == "Weg" and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_paint_roads(last_road,world_cell(get_global_mouse_position()))
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE: dragging = event.pressed
		if not event.pressed: last_road = Vector2i(-1,-1); return
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var before := get_global_mouse_position()
			camera.zoom = Vector2.ONE * clampf(camera.zoom.x * (1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1/1.12),0.45,2.2)
			camera.position += before-get_global_mouse_position()
			return
		var world_pos: Vector2 = get_canvas_transform().affine_inverse()*event.position
		var c := world_cell(world_pos)
		# Selecting, moving, demolishing and harvesting hit the picture of a
		# building (roof, walls, crown), not just its ground cell.
		if event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and mode in ["Info","Abriss"]) or (mode == "Bewegen" and moving.x < 0):
			var picked: Vector2i = world.building_at(world_pos)
			if picked.x >= 0 and not (village.occupied.has(c) and village.anchor(c) != picked and village.buildings[village.anchor(c)].type != "Weg"):
				c = picked
		if event.button_index == MOUSE_BUTTON_LEFT and mode == "Info":
			var rid: int = world.resident_at(world_pos)
			if rid >= 0:
				inspected_resident = rid
				world.selected_resident = rid
				inspected = Vector2i(-1,-1)
				right_tabs.current_tab = 2
				_update_ui()
				return
			var animal: Dictionary = world.animals_view.animal_at(world_pos)
			if not animal.is_empty():
				var label: String = world.animals_view.LABELS.get(animal.species, "Ein Tier")
				if not village.animal_bonus(label): village.notice = "%s schaut dich an." % label
				world.hearts(world.grid_to_screen(Vector2(animal.x, animal.y)))
				_update_ui()
				return
		if not village.inside(c): return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_inspect(c)
			village.harvest(c)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			match mode:
				"Bauen":
					if village.place(c,selected):
						if selected == "Weg": last_road = c
						_catalog()
				"Info": _inspect(c)
				"Abriss":
					village.remove(c)
				"Bewegen":
					if moving.x < 0:
						moving = village.anchor(c)
						if moving.x >= 0: village.notice = "Neuen Bauplatz für %s wählen. Esc bricht ab." % Model.DEFS[village.buildings[moving].type].label
					elif village.move_building(moving,c): moving = Vector2i(-1,-1)
		_update_ui()

func _inspect(c: Vector2i) -> void:
	inspected = village.anchor(c)
	inspected_resident = -1
	world.selected_resident = -1
	right_tabs.current_tab = 1

func _process(delta: float) -> void:
	hover = world_cell(get_global_mouse_position())
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE): dragging = false
	var direction := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	camera.position += direction * delta*650 / camera.zoom.x
	camera.position.x = clampf(camera.position.x,-1250,1650)
	camera.position.y = clampf(camera.position.y,100,1550)
	var dt: float = minf(delta, 0.25)*village.speed
	village.tick(dt)
	world.update(delta, dt)
	ui_timer += delta
	save_timer += delta
	if ui_timer >= 0.3:
		ui_timer = 0
		_update_ui()
	if save_timer >= 60:
		save_timer = 0
		_save()

func _paint_roads(from: Vector2i, to: Vector2i) -> void:
	if not village.unlocked(to): return
	var cursor := from if village.inside(from) else to
	while true:
		if not village.has_road(cursor):
			if not village.can_place(cursor,"Weg") or not village.afford(Model.DEFS.Weg.cost): break
			village.place(cursor,"Weg")
		if cursor == to: break
		if cursor.x != to.x: cursor.x += 1 if cursor.x < to.x else -1
		else: cursor.y += 1 if cursor.y < to.y else -1
	last_road = cursor
	_update_ui()

# ------------------------------------------------------------------ save/load

func _save() -> void:
	var file := FileAccess.open(SAVE+".tmp",FileAccess.WRITE)
	if file == null: village.notice = "Speichern fehlgeschlagen: Datei nicht beschreibbar."; return
	var saved_data: Dictionary = village.serialize()
	saved_data.settings = {"nightlight":dark,"grid":grid,"sound":sound_on,"zoom":camera.zoom.x,"camera_x":camera.position.x,"camera_y":camera.position.y}
	file.store_string(JSON.stringify(saved_data,"  "))
	file.close()
	var temp := FileAccess.open(SAVE+".tmp",FileAccess.READ)
	var check: Variant = JSON.parse_string(temp.get_as_text())
	temp.close()
	var verification = Model.new()
	if not verification.restore(check): village.notice = "Spielstandprüfung fehlgeschlagen. Der bisherige Stand bleibt erhalten."; return
	if FileAccess.file_exists(SAVE):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE),ProjectSettings.globalize_path(SAVE+".bak"))
	var result := DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE+".tmp"),ProjectSettings.globalize_path(SAVE))
	village.notice = "Dorf gespeichert. Eine Sicherung des vorherigen Standes bleibt erhalten." if result == OK else "Speichern fehlgeschlagen. Bisheriger Stand bleibt erhalten."
	_update_ui()

func _load(manual: bool) -> bool:
	for path in [SAVE,SAVE+".bak"]:
		if not FileAccess.file_exists(path): continue
		var file := FileAccess.open(path,FileAccess.READ)
		if file == null: continue
		var parser := JSON.new()
		var error := parser.parse(file.get_as_text())
		file.close()
		if error != OK: continue
		var data: Variant = parser.data
		var old_version: int = int(data.get("version",0)) if data is Dictionary and (data.get("version") is int or data.get("version") is float) else 0
		if village.restore(data):
			var settings: Variant = data.get("settings",{})
			if settings is Dictionary:
				dark = settings.get("nightlight",false) == true
				grid = settings.get("grid",false) == true
				if settings.has("sound"): sound_on = settings.get("sound",false) == true
				_apply_audio()
				if settings.get("zoom") is float or settings.get("zoom") is int:
					camera.zoom = Vector2.ONE*clampf(float(settings.zoom),0.45,2.2)
				if (settings.get("camera_x") is float or settings.get("camera_x") is int) and (settings.get("camera_y") is float or settings.get("camera_y") is int):
					camera.position = Vector2(clampf(float(settings.camera_x),-1250,1650),clampf(float(settings.camera_y),100,1550))
			village.notice = "Gespeichertes Dorf geladen." if path == SAVE else "Sicherung geladen: Der Hauptspielstand war beschädigt."
			if old_version < Model.SCHEMA:
				village.notice = "Dorf aus einer früheren Fassung übernommen. Neu: Waldlinge fällen Bäume, sammeln Stein und arbeiten in den Werkstätten."
			inspected = Vector2i(-1,-1)
			inspected_resident = -1
			moving = inspected
			_catalog()
			return true
	if manual: village.notice = "Kein gültiger Spielstand gefunden. Das aktuelle Dorf bleibt erhalten."
	return false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()

func quit_game() -> void:
	_save()
	_save_settings()
	get_tree().quit()

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in volumes: cfg.set_value("audio",k,volumes[k])
	cfg.set_value("audio","on",sound_on)
	cfg.set_value("display","status",show_status)
	cfg.set_value("display","nightlight",dark)
	cfg.save(SETTINGS)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) != OK:
		_apply_audio()
		return
	for k in volumes: volumes[k] = clampf(float(cfg.get_value("audio",k,volumes[k])),0.0,1.0)
	sound_on = cfg.get_value("audio","on",false) == true
	show_status = cfg.get_value("display","status",true) == true
	dark = cfg.get_value("display","nightlight",false) == true
	_apply_audio()

# ------------------------------------------------------------------ audio

func _setup_audio() -> void:
	for bus in ["Ambience","SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
			AudioServer.set_bus_send(AudioServer.bus_count-1,"Master")
	ambient = AudioStreamPlayer.new()
	ambient.bus = "Ambience"
	add_child(ambient)
	ambient.stream = Sfx.ambience()
	sfx = Sfx.new()
	add_child(sfx)

func _apply_audio() -> void:
	for bus in volumes:
		var index := AudioServer.get_bus_index(bus)
		if index >= 0:
			AudioServer.set_bus_volume_db(index,linear_to_db(maxf(volumes[bus],0.0001)))
			AudioServer.set_bus_mute(index,volumes[bus] <= 0.001)
	if ambient != null:
		if sound_on and not ambient.playing: ambient.play()
		elif not sound_on and ambient.playing: ambient.stop()

func play_sfx(kind: String, at: Vector2) -> void:
	if not sound_on or sfx == null: return
	# Only audible near the camera; quieter further away.
	var distance := at.distance_to(camera.position) * camera.zoom.x
	if distance > 900: return
	sfx.play(kind, at, village.speed)

func _layout_ui() -> void:
	if layout_panels.size() < 4: return
	var extent := get_viewport_rect().size
	var top: Control = layout_panels.top
	top.custom_minimum_size.x = extent.x-36
	top.size.x = extent.x-36
	var right: Control = layout_panels.right
	right.position.x = extent.x-right.size.x-20
	var left: Control = layout_panels.left
	left.custom_minimum_size.y = extent.y-168
	left.size.y = extent.y-168
	var bottom: Control = layout_panels.bottom
	bottom.position = Vector2(304,extent.y-80)
	bottom.custom_minimum_size.x = extent.x-324
	status.custom_minimum_size.x = extent.x-356
	bottom.size.x = extent.x-324
