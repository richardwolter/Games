extends Control
## Standalone sprite browser — run this scene directly to see every image the
## game ships, grouped by category, without booting a battle.
##
## The folder scan is the source of truth for WHAT exists; ASSET_INVENTORY.json
## only annotates it (category, status, where it is wired in). A PNG dropped
## into assets/sprites/ therefore shows up immediately, tagged "unlisted" until
## someone adds its inventory entry — the tool can never quietly disagree with
## the disk.

## Preloaded rather than reached via class_name: this scene is run directly and
## standalone, and a freshly added script isn't in the global class cache until
## the editor has re-imported.
const SpritePreview = preload("res://scenes/tools/sprite_preview.gd")

const INVENTORY_PATH := "res://assets/ASSET_INVENTORY.json"
const SPRITE_DIRS := ["res://assets/sprites", "res://assets"]

const CATEGORY_ORDER := ["hero", "villain", "minion", "unit", "obstacle",
		"scenery", "hazard", "ability_vfx", "ui", "uncategorised"]

## Categories whose art stands on the ground (tall props, characters) vs. art
## that reads centred (rocks, rings, projectiles) — matches the two draw
## conventions in LaneField.
const BASE_ANCHORED := ["hero", "villain", "minion", "unit", "scenery"]

## Categories that never collide, so a collision circle over them is noise.
const NON_COLLIDING := ["ui", "ability_vfx"]

## Mobile units — the scope of the proposed oval footprint (Designer,
## 2026-07-25: heroes, minions and villains only; obstacles stay circles).
const UNIT_CATEGORIES := ["hero", "villain", "minion", "unit"]

## Read from the game's own constant, never a copy — the whole point of the
## preview is that it shows what the field actually does.
const DEFAULT_COVERAGE := SpriteFootprint.COVERAGE

## Flag a sprite as over-padded once its collision circle is this much wider
## than the art inside it.
const PADDING_WARN_RATIO := 1.25

const CARD_SIZE := Vector2(300.0, 330.0)
const PREVIEW_HEIGHT := 190.0

var _entries: Array[Dictionary] = []
var _previews: Array[SpritePreview] = []
var _scale_slider: HSlider
var _reference_check: CheckBox
var _bounds_check: CheckBox
var _oval_check: CheckBox
var _coverage_slider: HSlider
var _coverage_label: Label
var _filter_edit: LineEdit
var _tabs: TabContainer
var _summary: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_entries = _collect_entries()
	_build_ui()

# -- Data ---------------------------------------------------------------------

## Disk scan merged with the inventory. Every returned dictionary has:
## path, filename, category, status, used_by, notes.
func _collect_entries() -> Array[Dictionary]:
	var meta := _load_inventory()
	var out: Array[Dictionary] = []
	var seen := {}
	for dir_path in SPRITE_DIRS:
		for file_name in _list_pngs(dir_path):
			var path := "%s/%s" % [dir_path, file_name]
			# assets/ holds older duplicates of several assets/sprites/ files;
			# the first directory scanned wins so the live copy is the one shown.
			if seen.has(file_name):
				continue
			seen[file_name] = true
			var m: Dictionary = meta.get(file_name, {})
			out.append({
				"path": path,
				"filename": file_name,
				"category": m.get("category", "uncategorised"),
				"status": m.get("status", "? unlisted"),
				"used_by": m.get("used_by", "not in ASSET_INVENTORY.json"),
				"notes": m.get("notes", ""),
			})
	out.sort_custom(func(a, b): return a["filename"] < b["filename"])
	return out

func _list_pngs(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("SpriteGallery: cannot open %s" % dir_path)
		return out
	for f in dir.get_files():
		# Exported builds rename .png to .png.import on disk; strip either.
		if f.ends_with(".png"):
			out.append(f)
		elif f.ends_with(".png.import"):
			out.append(f.trim_suffix(".import"))
	return out

## filename -> inventory entry.
func _load_inventory() -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(INVENTORY_PATH):
		push_warning("SpriteGallery: %s missing — everything reads as unlisted." % INVENTORY_PATH)
		return out
	var text := FileAccess.get_file_as_string(INVENTORY_PATH)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SpriteGallery: %s is not valid JSON." % INVENTORY_PATH)
		return out
	for row in parsed.get("assets", []):
		if typeof(row) == TYPE_DICTIONARY and row.has("filename"):
			out[row["filename"]] = row
	return out

# -- UI -----------------------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = UIStyle.PAGE_SOLID
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 28)
	pad.add_theme_constant_override("margin_right", 28)
	pad.add_theme_constant_override("margin_top", 20)
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	pad.add_child(col)

	col.add_child(UIStyle.label("SPRITE GALLERY", UIStyle.SIZE_TITLE))
	_summary = UIStyle.label(_summary_text(), UIStyle.SIZE_SMALL, UIStyle.INK_MUTED)
	col.add_child(_summary)
	col.add_child(_build_controls())

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_tabs)
	_build_tabs()

func _summary_text() -> String:
	var counts := {}
	for e in _entries:
		var s: String = e["status"]
		counts[s] = int(counts.get(s, 0)) + 1
	var parts: Array[String] = []
	for k in counts:
		parts.append("%s %d" % [k, counts[k]])
	parts.sort()
	return "%d files · %s · sizes are design-canvas px (player sees 0.67x)" % [
			_entries.size(), " · ".join(parts)]

func _build_controls() -> VBoxContainer:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	rows.add_child(bar)

	bar.add_child(UIStyle.label("Height", UIStyle.SIZE_SMALL))
	_scale_slider = HSlider.new()
	_scale_slider.min_value = 40.0
	_scale_slider.max_value = 400.0
	_scale_slider.value = PREVIEW_HEIGHT
	_scale_slider.custom_minimum_size.x = 260.0
	_scale_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_scale_slider.value_changed.connect(_on_scale_changed)
	bar.add_child(_scale_slider)

	_reference_check = CheckBox.new()
	_reference_check.text = "Thundaar 67px reference"
	_reference_check.add_theme_font_size_override("font_size", UIStyle.SIZE_SMALL)
	_reference_check.toggled.connect(_on_reference_toggled)
	bar.add_child(_reference_check)

	_bounds_check = CheckBox.new()
	_bounds_check.text = "Art bounds vs collision"
	_bounds_check.add_theme_font_size_override("font_size", UIStyle.SIZE_SMALL)
	_bounds_check.toggled.connect(_on_bounds_toggled)
	bar.add_child(_bounds_check)

	var legend := UIStyle.label("(dashed = art · red = collision now · blue = proposed oval)",
			UIStyle.SIZE_TINY, UIStyle.INK_MUTED)
	legend.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(legend)

	bar.add_child(UIStyle.label("Filter", UIStyle.SIZE_SMALL))
	_filter_edit = LineEdit.new()
	_filter_edit.placeholder_text = "filename…"
	_filter_edit.custom_minimum_size.x = 260.0
	_filter_edit.text_changed.connect(_on_filter_changed)
	bar.add_child(_filter_edit)

	rows.add_child(_build_oval_controls())
	return rows

## Second row — the proposed unit footprint. Kept separate because it is a
## proposal being evaluated, not a description of what the game does today.
func _build_oval_controls() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)

	_oval_check = CheckBox.new()
	_oval_check.text = "Proposed oval footprint (units only)"
	_oval_check.add_theme_font_size_override("font_size", UIStyle.SIZE_SMALL)
	_oval_check.toggled.connect(_on_oval_toggled)
	bar.add_child(_oval_check)

	bar.add_child(UIStyle.label("Coverage", UIStyle.SIZE_SMALL))
	_coverage_slider = HSlider.new()
	_coverage_slider.min_value = 0.5
	_coverage_slider.max_value = 1.0
	_coverage_slider.step = 0.01
	_coverage_slider.value = DEFAULT_COVERAGE
	_coverage_slider.custom_minimum_size.x = 260.0
	_coverage_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_coverage_slider.value_changed.connect(_on_coverage_changed)
	bar.add_child(_coverage_slider)

	_coverage_label = UIStyle.label(_coverage_text(DEFAULT_COVERAGE), UIStyle.SIZE_SMALL)
	bar.add_child(_coverage_label)
	return bar

func _coverage_text(v: float) -> String:
	return "%d%% of art" % roundi(v * 100.0)

func _build_tabs() -> void:
	var by_category := {}
	for e in _entries:
		var c: String = e["category"]
		if not by_category.has(c):
			by_category[c] = []
		by_category[c].append(e)

	var ordered: Array[String] = []
	for c in CATEGORY_ORDER:
		if by_category.has(c):
			ordered.append(c)
	for c in by_category:
		if not ordered.has(c):
			ordered.append(c)

	for c in ordered:
		var rows: Array = by_category[c]
		var scroll := ScrollContainer.new()
		scroll.name = "%s (%d)" % [c.to_upper(), rows.size()]
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

		var flow := HFlowContainer.new()
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_theme_constant_override("h_separation", 16)
		flow.add_theme_constant_override("v_separation", 16)
		scroll.add_child(flow)

		for row in rows:
			flow.add_child(_build_card(row))
		_tabs.add_child(scroll)

func _build_card(entry: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	# Stable variant so the hand-drawn corner wobble doesn't crawl on redraw.
	card.add_theme_stylebox_override("panel",
			UIStyle.card(UIStyle.INK, 12, entry["filename"].length() % 4))
	card.set_meta("filename", entry["filename"])

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	var preview := SpritePreview.new()
	preview.custom_minimum_size = Vector2(CARD_SIZE.x - 40.0, 210.0)
	preview.texture = load(entry["path"]) as Texture2D
	preview.draw_height = PREVIEW_HEIGHT
	preview.preview_anchor = (SpritePreview.AnchorMode.BASE
			if entry["category"] in BASE_ANCHORED
			else SpritePreview.AnchorMode.CENTER)
	col.add_child(preview)
	_previews.append(preview)

	col.add_child(UIStyle.label(entry["filename"], UIStyle.SIZE_SMALL))

	var native := "—"
	if preview.texture != null:
		var s := preview.texture.get_size()
		native = "%d x %d px" % [int(s.x), int(s.y)]
	var meta := UIStyle.label("%s · %s" % [entry["status"], native],
			UIStyle.SIZE_TINY, _status_color(entry["status"]))
	col.add_child(meta)

	if preview.texture != null:
		preview.opaque_rect = _opaque_rect_of(preview.texture)
		preview.collides = not (entry["category"] in NON_COLLIDING)
		preview.is_unit = entry["category"] in UNIT_CATEGORIES
		preview.oval_coverage = DEFAULT_COVERAGE
		var padding := _padding_line(preview.texture, preview.opaque_rect, preview.collides)
		if padding != "":
			col.add_child(UIStyle.label(padding, UIStyle.SIZE_TINY,
					_padding_color(preview.texture, preview.opaque_rect)))

	var used := UIStyle.label(entry["used_by"], UIStyle.SIZE_TINY, UIStyle.INK_MUTED)
	used.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	used.custom_minimum_size.x = CARD_SIZE.x - 40.0
	col.add_child(used)

	if entry["notes"] != "":
		card.tooltip_text = entry["notes"]
	return card

## Tight bounds of the non-transparent pixels, in texture pixel space.
## Image.get_used_rect does the scan natively — doing it per-pixel in GDScript
## across 44 textures was measurably slow.
func _opaque_rect_of(tex: Texture2D) -> Rect2:
	var img := tex.get_image()
	if img == null:
		return Rect2()
	if img.is_compressed():
		# get_used_rect needs raw pixels; imported PNGs may arrive compressed.
		if img.decompress() != OK:
			return Rect2()
	return Rect2(img.get_used_rect())

## How much wider the collision circle is than the art it contains. The game
## scales art so the LONGEST image edge spans the collision diameter, so that
## edge is the one being paid for.
func _padding_ratio(tex: Texture2D, opaque: Rect2) -> float:
	var tex_size := tex.get_size()
	var img_long := maxf(tex_size.x, tex_size.y)
	var art_long := maxf(opaque.size.x, opaque.size.y)
	if art_long <= 0.0 or img_long <= 0.0:
		return 1.0
	return img_long / art_long

func _padding_line(tex: Texture2D, opaque: Rect2, collides: bool) -> String:
	var ratio := _padding_ratio(tex, opaque)
	var pct := 100.0 * (1.0 - 1.0 / ratio)
	if pct < 1.0:
		return "no padding"
	if not collides:
		return "%.0f%% padding" % pct
	return "%.0f%% padding · collision %.1fx art" % [pct, ratio]

func _padding_color(tex: Texture2D, opaque: Rect2) -> Color:
	if _padding_ratio(tex, opaque) >= PADDING_WARN_RATIO:
		return UIStyle.DANGER
	return UIStyle.INK_MUTED

func _status_color(status: String) -> Color:
	if status.begins_with("✓"):
		return UIStyle.GOOD
	if status.begins_with("⊘") or status.begins_with("❌"):
		return UIStyle.DANGER
	return UIStyle.GOLD

# -- Signals ------------------------------------------------------------------

func _on_scale_changed(v: float) -> void:
	for p in _previews:
		p.draw_height = v

func _on_reference_toggled(on: bool) -> void:
	for p in _previews:
		p.show_reference = on

func _on_bounds_toggled(on: bool) -> void:
	for p in _previews:
		p.show_bounds = on

func _on_oval_toggled(on: bool) -> void:
	for p in _previews:
		p.show_oval = on

func _on_coverage_changed(v: float) -> void:
	_coverage_label.text = _coverage_text(v)
	for p in _previews:
		p.oval_coverage = v

func _on_filter_changed(text: String) -> void:
	var needle := text.strip_edges().to_lower()
	for p in _previews:
		var card := p.get_parent().get_parent()
		card.visible = (needle == ""
				or String(card.get_meta("filename")).to_lower().contains(needle))
