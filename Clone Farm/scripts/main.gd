## The farm, built in code: ground, light, isometric camera and the farmer. Graybox only,
## per docs/scope.md: shapes and flat colours, no Synty.
extends Node3D

const GROUND_SIZE := 24.0

var farmer: Farmer


func _ready() -> void:
	Controls.ensure()
	_build_ground()
	_build_light()
	farmer = _build_farmer()
	_build_camera()


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
