## The farm, built in code: ground, light, isometric camera, the farmer, the garden beds
## and a minimal HUD. Graybox only, per docs/scope.md: shapes and flat colours, no Synty.
extends Node3D

const GROUND_SIZE := 24.0
const BED_COLUMNS := 3
const BED_ROWS := 2
## Wide enough that a work spot (Worker.SPOT_GAP out from one bed) is clearly nearer
## that bed than the one across the aisle.
const BED_GAP := 1.4
## Where the bed grid's centre sits, a few steps from where the farmer starts.
const BEDS_AT := Vector3(0.0, 0.0, -4.0)

## What the HUD calls each task (the game speaks Portuguese).
const TASK_LABELS := {
	Bed.PLANT: "plantar",
	Bed.WATER: "regar",
	Bed.HARVEST: "colher",
}
const WORKING_LABELS := {
	Bed.PLANT: "plantando",
	Bed.WATER: "regando",
	Bed.HARVEST: "colhendo",
}

var farmer: Farmer
var beds: Array[Bed] = []
## Harvested produce, waiting for its use (machine, trough, sale come with Carregar).
var stock := 0

var _stock_label: Label
var _hint_label: Label


func _ready() -> void:
	Controls.ensure()
	_build_ground()
	_build_light()
	_build_beds()
	farmer = _build_farmer()
	_build_camera()
	_build_hud()


func _process(_delta: float) -> void:
	_stock_label.text = "Produção: %d" % stock
	var bed := farmer.nearest_bed()
	var task: StringName = bed.next_task() if bed != null else &""
	if farmer.is_working():
		_hint_label.text = "%s... %d%%   (E: cancelar)" % [WORKING_LABELS[farmer.work_task],
				roundi(farmer.work_progress() * 100.0)]
	else:
		_hint_label.text = "E: %s" % TASK_LABELS[task] if task != &"" else ""


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
	_hint_label = Label.new()
	_hint_label.position = Vector2(16, 44)
	_hint_label.add_theme_font_size_override("font_size", 20)
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
	var mesh := MeshInstance3D.new()
	mesh.name = "Body"
	mesh.mesh = CapsuleMesh.new()
	mesh.material_override = _flat(Color(0.85, 0.35, 0.25))
	f.add_child(mesh)
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	f.add_child(shape)
	add_child(f)
	return f


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
