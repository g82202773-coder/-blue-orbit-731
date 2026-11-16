extends Node3D

@export var speed: float = 5.5
@export var route: PackedVector3Array = PackedVector3Array()
@export var start_index: int = 0
@export var paint_color: Color = Color("#b94c3d")

var target_index: int = 0

func _ready() -> void:
    _build_visual()
    if route.size() >= 2:
        start_index = posmod(start_index, route.size())
        global_position = route[start_index]
        target_index = (start_index + 1) % route.size()

func _process(delta: float) -> void:
    if route.size() < 2:
        return
    var target := route[target_index]
    var offset := target - global_position
    offset.y = 0.0
    if offset.length() < 1.2:
        target_index = (target_index + 1) % route.size()
        return
    var direction := offset.normalized()
    global_position += direction * speed * delta
    rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 4.0)

func _build_visual() -> void:
    var paint := StandardMaterial3D.new()
    paint.albedo_color = paint_color
    paint.roughness = 0.42

    var glass := StandardMaterial3D.new()
    glass.albedo_color = Color("#507080")
    glass.roughness = 0.3

    var rubber := StandardMaterial3D.new()
    rubber.albedo_color = Color("#202326")
    rubber.roughness = 0.95

    _add_box(Vector3(1.85, 0.62, 3.5), Vector3(0.0, 0.0, 0.0), paint)
    _add_box(Vector3(1.42, 0.62, 1.65), Vector3(0.0, 0.55, -0.12), glass)
    for x in [-0.86, 0.86]:
        for z in [-1.12, 1.12]:
            var wheel := MeshInstance3D.new()
            var mesh := CylinderMesh.new()
            mesh.top_radius = 0.29
            mesh.bottom_radius = 0.29
            mesh.height = 0.18
            wheel.mesh = mesh
            wheel.rotation_degrees.z = 90.0
            wheel.position = Vector3(x, -0.19, z)
            wheel.material_override = rubber
            add_child(wheel)

func _add_box(size: Vector3, position: Vector3, material: Material) -> void:
    var instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.position = position
    instance.material_override = material
    add_child(instance)
