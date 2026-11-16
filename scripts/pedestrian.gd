extends Node3D

@export var route: PackedVector3Array = PackedVector3Array()
@export var start_index: int = 0
@export var walk_speed: float = 1.25
@export var clothing_color: Color = Color("#315e83")
@export var skin_color: Color = Color("#b9825e")

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
    if offset.length() < 0.65:
        target_index = (target_index + 1) % route.size()
        return
    var direction := offset.normalized()
    global_position += direction * walk_speed * delta
    rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 6.0)

func _build_visual() -> void:
    var clothing := StandardMaterial3D.new()
    clothing.albedo_color = clothing_color
    clothing.roughness = 0.86
    var skin := StandardMaterial3D.new()
    skin.albedo_color = skin_color
    skin.roughness = 0.82

    var torso := MeshInstance3D.new()
    var torso_mesh := CapsuleMesh.new()
    torso_mesh.radius = 0.27
    torso_mesh.height = 1.05
    torso.mesh = torso_mesh
    torso.position.y = 0.85
    torso.material_override = clothing
    add_child(torso)

    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.18
    head_mesh.height = 0.36
    head.mesh = head_mesh
    head.position.y = 1.48
    head.material_override = skin
    add_child(head)
