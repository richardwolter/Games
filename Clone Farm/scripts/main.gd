## The farm, built in code: ground, light, isometric camera, the farmer, the garden beds,
## the three depots (machine, trough, market), the crates harvests drop, the clones and a
## minimal HUD. Also runs the day (DAY_LENGTH seconds, a rising target in money sold; miss
## it and the run is over), the shops at the Venda stall, and the playtest log. Graybox
## only, per docs/scope.md: shapes and flat colours, no Synty.
extends Node3D

const GROUND_SIZE := 30.0
const BED_COLUMNS := 3
const BED_ROWS := 2
## Wide enough that a work spot (Worker.SPOT_GAP out from one bed) is clearly nearer
## that bed than the one across the aisle.
const BED_GAP := 1.4
## Where the bed grid's centre sits, a few steps from where the farmer starts.
const BEDS_AT := Vector3(0.0, 0.0, -4.0)
const MACHINE_AT := Vector3(5.5, 0.0, 1.0)
const TROUGH_AT := Vector3(-5.5, 0.0, 1.0)
const MARKET_AT := Vector3(0.0, 0.0, 4.5)
## Machine stock at the start, enough for the first clone right away.
const START_STOCK := 5
## Traits each new clone rolls before any Máquina upgrade.
const TRAIT_SLOTS := 2
## One day, and its target in money sold that day: GOAL_START on day 1, +GOAL_STEP a day.
const DAY_LENGTH := 240.0
const GOAL_START := 5
const GOAL_STEP := 3
## Where each run's playtest log goes (one file per run, a block per day).
const LOG_DIR := "res://docs/playtests/"

## What the HUD calls each task (the game speaks Portuguese).
const TASK_LABELS := {
	Bed.PLANT: "plantar",
	Bed.WATER: "regar",
	Bed.HARVEST: "colher",
	Bed.FIX: "consertar",
	Crate.PICK_UP: "pegar caixote",
	Depot.DELIVER: "entregar",
	Machine.CLONE: "clonar",
	Depot.EAT: "comer",
	Machine.RECYCLE: "reciclar",
}
const WORKING_LABELS := {
	Bed.PLANT: "plantando",
	Bed.WATER: "regando",
	Bed.HARVEST: "colhendo",
	Bed.FIX: "consertando",
	Crate.PICK_UP: "pegando",
	Depot.DELIVER: "entregando",
	Machine.CLONE: "clonando",
	Depot.EAT: "comendo",
	Machine.RECYCLE: "reciclando",
}

const HELP := """[b]Como jogar[/b]  (H mostra/esconde)
WASD: andar
E (ou Espaço): fazer o que o lugar mais perto pede (plantar, regar, colher, consertar,
    pegar caixote, entregar, clonar). E de novo cancela.
E num clone: painel do clone. 1 Plantar, 2 Regar, 3 Colher, 4 Carregar (depois 1 Máquina,
    2 Cocho, 3 Venda), 0 nenhuma, R reciclar (devolve %d).
E na Venda de mãos vazias: lojas (1 Terra, 2 Máquina, 3 Ferramentas).
Venda a meta do dia antes do relógio zerar. Clones comem do cocho; sem comida, ficam com fome.
""" % Machine.REFUND

var farmer: Farmer
var beds: Array[Bed] = []
var machine: Machine
var trough: Depot
var market: Depot
var clones: Array[Clone] = []
var rng := RandomNumberGenerator.new()

var day := 1
var day_left := DAY_LENGTH
var sold_today := 0
var money := 0
var game_over := false
var trait_slots := TRAIT_SLOTS
var tool_speed := 1.0
## Levels bought per shop id.
var bought := {}
## Crates delivered today per depot label, food eaten today, purchases today.
var delivered_today := {}
var food_today := 0
var bought_today: PackedStringArray = []
## Empty turns the playtest log off (the harness points it elsewhere).
var log_dir := LOG_DIR
var log_path := ""

var _stock_label: Label
var _clock_label: Label
var _hint_label: RichTextLabel
var _help_label: RichTextLabel
var _summary_label: RichTextLabel
var _bed_origin := Vector3.ZERO
var _bed_rows := 0


func _ready() -> void:
	Controls.ensure()
	rng.randomize()
	_build_ground()
	_build_light()
	_build_beds()
	_build_depots()
	farmer = _build_farmer()
	farmer.buy_requested.connect(buy)
	_build_camera()
	_build_hud()
	var gate := DayGate.new()
	gate.name = "DayGate"
	gate.farm = self
	add_child(gate)


func _process(delta: float) -> void:
	day_left -= delta
	if day_left <= 0.0 and not get_tree().paused:
		day_left = 0.0
		end_day()
	var secs := ceili(day_left)
	_clock_label.text = "Dia %d   %d:%02d   Vendido hoje: $%d / meta $%d" % [
			day, secs / 60, secs % 60, sold_today, goal()]
	_stock_label.text = "Dinheiro: $%d    Máquina: %d    Cocho: %d    Clones: %d" % [
			money, machine.stock, trough.stock, clones.size()]
	_hint_label.text = _hint()


func goal() -> int:
	return GOAL_START + GOAL_STEP * (day - 1)


## The clock ran out: check the target, log the day, and stop the farm on the summary.
func end_day() -> void:
	var passed := sold_today >= goal()
	game_over = not passed
	_write_day_log(passed)
	var lines: PackedStringArray = []
	lines.append("[b]Fim do dia %d[/b]" % day)
	lines.append("Vendido: $%d   Meta: $%d   %s" % [sold_today, goal(),
			"[color=%s]META BATIDA[/color]" % Traits.GOOD if passed
			else "[color=%s]META NÃO BATIDA[/color]" % Traits.BAD])
	lines.append("Clones: %d   Comida usada: %d   Dinheiro: $%d" % [clones.size(), food_today, money])
	if passed:
		lines.append("Amanhã a meta é $%d.   E ou Enter: próximo dia" % (goal() + GOAL_STEP))
	else:
		lines.append("[b]Fim de jogo: %d dia(s) sobrevivido(s).[/b]   E, Enter ou R: jogar de novo"
				% (day - 1))
	_summary_label.text = "\n".join(lines)
	_summary_label.visible = true
	get_tree().paused = true


func next_day() -> void:
	day += 1
	day_left = DAY_LENGTH
	sold_today = 0
	food_today = 0
	delivered_today = {}
	bought_today = []
	for clone in clones:
		clone.reset_tally()
	_summary_label.visible = false
	get_tree().paused = false


func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func toggle_help() -> void:
	_help_label.visible = not _help_label.visible


## Buys the next level of shop `index` (Shop.ITEMS) if there is one and the money covers it.
func buy(index: int) -> bool:
	if index < 0 or index >= Shop.ITEMS.size():
		return false
	var item: Dictionary = Shop.ITEMS[index]
	var level: int = bought.get(item.id, 0)
	if level >= item.prices.size() or money < item.prices[level]:
		return false
	money -= item.prices[level]
	bought[item.id] = level + 1
	bought_today.append("%s %d ($%d)" % [item.label, level + 1, item.prices[level]])
	match item.id:
		&"terra":
			_add_bed_row()
		&"maquina":
			trait_slots += 1
		&"ferramentas":
			tool_speed = 1.0 + Shop.TOOL_STEP * (level + 1)
			farmer.work_speed = tool_speed
			for clone in clones:
				clone.work_speed = tool_speed
	return true


## The shop menu: each shop's next level, its effect and price, or "esgotado".
func shop_panel() -> String:
	var lines: PackedStringArray = ["[b]Lojas[/b]   Dinheiro: $%d" % money]
	for i in Shop.ITEMS.size():
		var item: Dictionary = Shop.ITEMS[i]
		var level: int = bought.get(item.id, 0)
		if level >= item.prices.size():
			lines.append("%d %s: esgotado" % [i + 1, item.label])
			continue
		var price: int = item.prices[level]
		var color := "#ffffff" if money >= price else Traits.BAD
		lines.append("%d %s (nível %d de %d): %s   [color=%s]$%d[/color]" % [i + 1, item.label,
				level + 1, item.prices.size(), item.effect, color, price])
	lines.append("E: fechar")
	return "\n".join(lines)


## Appends today's block to this run's log: the day's numbers, then each clone.
func _write_day_log(passed: bool) -> void:
	if log_dir == "":
		return
	if log_path == "":
		DirAccess.make_dir_recursive_absolute(log_dir)
		var date := Time.get_date_string_from_system()
		var n := 1
		while FileAccess.file_exists("%s%s_run%d.log" % [log_dir, date, n]):
			n += 1
		log_path = "%s%s_run%d.log" % [log_dir, date, n]
	var file := FileAccess.open(log_path, FileAccess.READ_WRITE) \
			if FileAccess.file_exists(log_path) else FileAccess.open(log_path, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line("== Dia %d: vendido $%d, meta $%d, %s" % [day, sold_today, goal(),
			"batida" if passed else "NÃO batida (fim)"])
	file.store_line("dinheiro $%d, máquina %d, cocho %d, comida usada %d, clones %d" % [
			money, machine.stock, trough.stock, food_today, clones.size()])
	file.store_line("entregue: %s" % [delivered_today])
	if not bought_today.is_empty():
		file.store_line("comprado: %s" % ", ".join(bought_today))
	for clone in clones:
		var t: Dictionary = clone.tally
		file.store_line("  %s [%s] função %s: tarefas %s, pulou %d, cochilou %d, conversou %d, "
				% [clone.name, Traits.labels(clone.traits), Clone.ROLE_LABELS[clone.role],
				t.tasks, t.skips, t.naps, t.chats]
				+ "beliscou %d, pisoteou %d, com fome %ds, parado %ds" % [t.nibbles, t.trampled,
				roundi(t.hungry_secs), roundi(t.idle_secs)])
	file.close()


## What the farmer is doing or what E would do, for the HUD.
func _hint() -> String:
	if farmer.is_working():
		return "%s... %d%%   (E: cancelar)" % [WORKING_LABELS[farmer.work_task],
				roundi(farmer.work_progress() * 100.0)]
	if farmer.shopping:
		return shop_panel()
	if farmer.choosing != null and farmer.choosing_dest:
		return "Carregar para onde?  1 Máquina   2 Cocho   3 Venda      (E: fechar)"
	if farmer.choosing != null:
		return clone_panel(farmer.choosing, true)
	var hands := "Nas mãos: %d caixote\n" % farmer.carrying if farmer.carrying > 0 else ""
	var target := farmer.nearest_target()
	if target is Clone:
		return hands + clone_panel(target, false)
	if target is Workplace:
		var task: StringName = target.next_task_for(farmer)
		if task != &"":
			return hands + "E: %s" % TASK_LABELS[task]
		if target.is_in_group("markets") and farmer.carrying == 0:
			return hands + "E: lojas"

		if target is Machine:
			return hands + "Máquina: precisa de %d (tem %d)" % [Machine.COST, machine.stock]
		if target is Bed and target.state == Bed.State.GROWING:
			return hands + "crescendo..."
	return hands


## A clone's stat sheet and how much it adds to the farm in each role, so picking a role
## is quick. "(melhor)" only when the best role beats the next by RECOMMEND_GAP points.
const RECOMMEND_GAP := 10

func clone_panel(clone: Clone, choosing: bool) -> String:
	var lines: PackedStringArray = []
	var names := Traits.labels(clone.traits) if not clone.traits.is_empty() else "sem características"
	var role_now: String = Clone.ROLE_LABELS[clone.role] if clone.role != &"" else "nenhuma"
	if clone.role == Traits.CARRY and clone.dest != null:
		role_now += " > " + clone.dest.label
	if clone.hungry:
		role_now += ", [color=%s]COM FOME[/color]" % Traits.BAD
	lines.append("[b]%s[/b]  %s  (função: %s)" % [clone.name, names, role_now])
	lines.append_array(Traits.stat_rows(clone.stats, clone.traits))
	var pcts := {}
	for i in range(1, Clone.ROLES.size()):
		pcts[Clone.ROLES[i]] = roundi(Traits.role_rating(clone.stats, Clone.ROLES[i],
				beds.size(), tool_speed) * 100.0)
	var ranked: Array = pcts.keys()
	ranked.sort_custom(func(x: StringName, y: StringName) -> bool: return pcts[x] > pcts[y])
	var best: StringName = ranked[0] if pcts[ranked[0]] - pcts[ranked[1]] >= RECOMMEND_GAP \
			else &""
	lines.append("Produção da fazenda com ele em cada função (100% = clone comum):")
	for i in range(1, Clone.ROLES.size()):
		var role := Clone.ROLES[i]
		var pct: int = pcts[role]
		var color := Traits.GOOD if pct > 100 else (Traits.BAD if pct < 100 else "#ffffff")
		var line := "%s %s  [color=%s]%d%%[/color]" % [
				str(i) if choosing else "-", Clone.ROLE_LABELS[role], color, pct]
		if role == best:
			line = "[b]%s  (melhor)[/b]" % line
		lines.append(line)
	lines.append("0 nenhuma   R reciclar (devolve %d)      (E: fechar)" % Machine.REFUND
			if choosing else "E: dar função")
	return "\n".join(lines)


func _build_depots() -> void:
	machine = Machine.new()
	machine.name = "Machine"
	machine.position = MACHINE_AT
	machine.stock = START_STOCK
	machine.slot = 1
	machine.cloned.connect(_spawn_clone)
	machine.recycled.connect(_recycle_clone)
	add_child(machine)
	trough = Depot.new()
	trough.name = "Trough"
	trough.label = "Cocho"
	trough.color = Color(0.45, 0.60, 0.35)
	trough.slot = 2
	trough.position = TROUGH_AT
	trough.add_to_group("troughs")
	add_child(trough)
	market = Depot.new()
	market.name = "Market"
	market.label = "Venda ($)"
	market.color = Color(0.85, 0.80, 0.35)
	market.slot = 3
	market.position = MARKET_AT
	market.add_to_group("markets")
	add_child(market)
	market.delivered.connect(func(amount: int) -> void:
		money += amount
		sold_today += amount)
	for depot: Depot in [machine, trough, market]:
		depot.delivered.connect(func(amount: int) -> void:
			delivered_today[depot.label] = delivered_today.get(depot.label, 0) + amount)
	trough.eaten.connect(func(amount: int) -> void: food_today += amount)


## Places a new clone beside the machine (already paid for), with random traits and no role.
func _spawn_clone() -> void:
	var clone := Clone.new()
	clone.name = "Clone%d" % (clones.size() + 1)
	var row := clones.size() % 3
	clone.position = MACHINE_AT + Vector3(Machine.SIZE, 1.0, -1.0 + row * 1.0)
	clone.set_traits(Traits.roll(rng, trait_slots))
	clone.work_speed = tool_speed
	_dress_worker(clone, Color(0.35, 0.55, 0.90))
	add_child(clone)
	clones.append(clone)


## A recycled clone went into the machine (the refund is already in its stock).
func _recycle_clone(clone: Clone) -> void:
	clones.erase(clone)
	if farmer.choosing == clone:
		farmer.close_choice()
	clone.queue_free()


## `amount` crates on the ground at the bed's outer corner, side by side.
func _drop_crates(bed: Bed, amount: int) -> void:
	var corner := bed.position + Vector3(Bed.SIZE / 2.0 + 0.45, 0.0, Bed.SIZE / 2.0 + 0.45)
	for i in amount:
		var crate := Crate.new()
		crate.position = corner + Vector3(-i * (Crate.SIZE + 0.15), 0.0, 0.0)
		add_child(crate)


func _build_beds() -> void:
	var step := Bed.SIZE + BED_GAP
	_bed_origin = BEDS_AT - Vector3((BED_COLUMNS - 1) * step, 0.0, (BED_ROWS - 1) * step) / 2.0
	for row in BED_ROWS:
		_add_bed_row()


## One more row of BED_COLUMNS beds; the first rows go down the screen, the bought ones
## up, past the first row.
func _add_bed_row() -> void:
	var step := Bed.SIZE + BED_GAP
	var row := _bed_rows if _bed_rows < BED_ROWS else BED_ROWS - 1 - _bed_rows
	for col in BED_COLUMNS:
		var bed := Bed.new()
		bed.name = "Bed%d" % beds.size()
		bed.position = _bed_origin + Vector3(col * step, 0.0, row * step)
		bed.harvested.connect(func(amount: int) -> void: _drop_crates(bed, amount))
		add_child(bed)
		beds.append(bed)
	_bed_rows += 1


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "Hud"
	_clock_label = Label.new()
	_clock_label.position = Vector2(16, 8)
	_clock_label.add_theme_font_size_override("font_size", 24)
	hud.add_child(_clock_label)
	_stock_label = Label.new()
	_stock_label.position = Vector2(16, 40)
	_stock_label.add_theme_font_size_override("font_size", 20)
	hud.add_child(_stock_label)
	_hint_label = RichTextLabel.new()
	_hint_label.bbcode_enabled = true
	_hint_label.fit_content = true
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.position = Vector2(16, 72)
	_hint_label.size = Vector2(1100, 0)
	_hint_label.add_theme_font_size_override("normal_font_size", 20)
	_hint_label.add_theme_font_size_override("bold_font_size", 20)
	_hint_label.add_theme_constant_override("outline_size", 6)
	_hint_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_child(_hint_label)
	_help_label = _panel_label(Vector2(16, 470), HELP)
	hud.add_child(_help_label)
	_summary_label = _panel_label(Vector2(340, 260), "")
	_summary_label.add_theme_font_size_override("normal_font_size", 26)
	_summary_label.add_theme_font_size_override("bold_font_size", 30)
	_summary_label.visible = false
	hud.add_child(_summary_label)
	add_child(hud)


func _panel_label(at: Vector2, text: String) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = at
	label.size = Vector2(1000, 0)
	label.add_theme_font_size_override("normal_font_size", 18)
	label.add_theme_font_size_override("bold_font_size", 20)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.text = text
	return label


func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	mesh.mesh = plane
	mesh.material_override = _flat(Color(0.42, 0.55, 0.30))
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GROUND_SIZE, 0.2, GROUND_SIZE)
	shape.shape = box
	shape.position.y = -0.1
	body.add_child(shape)
	add_child(body)


func _build_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.78, 0.90)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	add_child(env)


func _build_farmer() -> Farmer:
	var f := Farmer.new()
	f.name = "Farmer"
	f.position = Vector3(0.0, 1.0, 0.0)
	_dress_worker(f, Color(0.85, 0.35, 0.25))
	add_child(f)
	return f


## A capsule body (the "Body" the Worker animates) and its collision shape.
func _dress_worker(worker: Worker, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = "Body"
	mesh.mesh = CapsuleMesh.new()
	mesh.material_override = _flat(color)
	worker.add_child(mesh)
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	worker.add_child(shape)


func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 21.0
	cam.position = Vector3(12.0, 14.0, 10.0)
	add_child(cam)
	cam.look_at(Vector3(0.0, 0.0, -2.0))


func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat
