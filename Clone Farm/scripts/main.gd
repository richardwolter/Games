## The farm, built in code: ground, light, isometric camera, the farmer, the garden beds,
## the cloning machine (and the clones it makes) and a minimal HUD. Graybox only, per docs/scope.md: shapes and flat colours, no Synty.
extends Node3D

const GROUND_SIZE := 24.0
const BED_COLUMNS := 3
const BED_ROWS := 2
## Wide enough that a work spot (Worker.SPOT_GAP out from one bed) is clearly nearer
## that bed than the one across the aisle.
const BED_GAP := 1.4
## Where the bed grid's centre sits, a few steps from where the farmer starts.
const BEDS_AT := Vector3(0.0, 0.0, -4.0)
const MACHINE_AT := Vector3(5.5, 0.0, 1.0)
## Produção at the start, enough for the first clone right away.
const START_STOCK := 5
## Traits each new clone rolls (Máquina upgrades will add more).
const TRAIT_SLOTS := 2

## What the HUD calls each task (the game speaks Portuguese).
const TASK_LABELS := {
	Bed.PLANT: "plantar",
	Bed.WATER: "regar",
	Bed.HARVEST: "colher",
	Machine.CLONE: "clonar",
}
const WORKING_LABELS := {
	Bed.PLANT: "plantando",
	Bed.WATER: "regando",
	Bed.HARVEST: "colhendo",
	Machine.CLONE: "clonando",
}

var farmer: Farmer
var beds: Array[Bed] = []
var machine: Machine
var clones: Array[Clone] = []
## Harvested produce, spent on clones; trough and sale come with Carregar.
var stock := START_STOCK
var rng := RandomNumberGenerator.new()

var _stock_label: Label
var _hint_label: RichTextLabel


func _ready() -> void:
	Controls.ensure()
	rng.randomize()
	_build_ground()
	_build_light()
	_build_beds()
	_build_machine()
	farmer = _build_farmer()
	_build_camera()
	_build_hud()


func _process(_delta: float) -> void:
	_stock_label.text = "Produção: %d   Clones: %d" % [stock, clones.size()]
	_hint_label.text = _hint()


## What the farmer is doing or what E would do, for the HUD.
func _hint() -> String:
	if farmer.is_working():
		return "%s... %d%%   (E: cancelar)" % [WORKING_LABELS[farmer.work_task],
				roundi(farmer.work_progress() * 100.0)]
	if farmer.choosing != null:
		return clone_panel(farmer.choosing, true)
	var target := farmer.nearest_target()
	if target is Clone:
		return clone_panel(target, false)
	if target is Machine:
		if target.next_task() == &"":
			return "Máquina: precisa de %d produção" % Machine.COST
		return "E: clonar (custa %d produção)" % Machine.COST
	if target is Bed:
		var task: StringName = target.next_task()
		return "E: %s" % TASK_LABELS[task] if task != &"" else "crescendo..."
	return ""


## A clone's stat sheet and how much it adds to the farm in each role, so picking a role
## is quick. "(melhor)" only when the best role beats the next by RECOMMEND_GAP points.
const RECOMMEND_GAP := 10

func clone_panel(clone: Clone, choosing: bool) -> String:
	var lines: PackedStringArray = []
	var names := Traits.labels(clone.traits) if not clone.traits.is_empty() else "sem características"
	var role_now: String = Clone.ROLE_LABELS[clone.role] if clone.role != &"" else "nenhuma"
	lines.append("[b]%s[/b]  %s  (função: %s)" % [clone.name, names, role_now])
	lines.append_array(Traits.stat_rows(clone.stats, clone.traits))
	var pcts := {}
	for i in range(1, Clone.ROLES.size()):
		pcts[Clone.ROLES[i]] = roundi(Traits.role_rating(clone.stats, Clone.ROLES[i],
				beds.size()) * 100.0)
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
	lines.append("0 nenhuma      (E: fechar)" if choosing else "E: dar função")
	return "\n".join(lines)


func _build_machine() -> void:
	machine = Machine.new()
	machine.name = "Machine"
	machine.position = MACHINE_AT
	machine.can_afford = func() -> bool: return stock >= Machine.COST
	machine.cloned.connect(_spawn_clone)
	add_child(machine)


## Pays for and places a new clone beside the machine, with random traits and no role.
func _spawn_clone() -> void:
	stock -= Machine.COST
	var clone := Clone.new()
	clone.name = "Clone%d" % (clones.size() + 1)
	var row := clones.size() % 3
	clone.position = MACHINE_AT + Vector3(Machine.SIZE, 1.0, -1.0 + row * 1.0)
	clone.set_traits(Traits.roll(rng, TRAIT_SLOTS))
	_dress_worker(clone, Color(0.35, 0.55, 0.90))
	add_child(clone)
	clones.append(clone)


func _build_beds() -> void:
	var step := Bed.SIZE + BED_GAP
	var origin := BEDS_AT - Vector3((BED_COLUMNS - 1) * step, 0.0, (BED_ROWS - 1) * step) / 2.0
	for row in BED_ROWS:
		for col in BED_COLUMNS:
			var bed := Bed.new()
			bed.name = "Bed%d" % beds.size()
			bed.position = origin + Vector3(col * step, 0.0, row * step)
			bed.harvested.connect(func(amount: int) -> void: stock += amount)
			add_child(bed)
			beds.append(bed)


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "Hud"
	_stock_label = Label.new()
	_stock_label.position = Vector2(16, 12)
	_stock_label.add_theme_font_size_override("font_size", 24)
	hud.add_child(_stock_label)
	_hint_label = RichTextLabel.new()
	_hint_label.bbcode_enabled = true
	_hint_label.fit_content = true
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.position = Vector2(16, 44)
	_hint_label.size = Vector2(1100, 0)
	_hint_label.add_theme_font_size_override("normal_font_size", 20)
	_hint_label.add_theme_font_size_override("bold_font_size", 20)
	_hint_label.add_theme_constant_override("outline_size", 6)
	_hint_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_child(_hint_label)
	add_child(hud)


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
	cam.size = 18.0
	cam.position = Vector3(12.0, 14.0, 12.0)
	add_child(cam)
	cam.look_at(Vector3.ZERO)


func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat
