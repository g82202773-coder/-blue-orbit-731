extends Node3D

const CITY_EXTENT := 220.0
const WALK_SPEED := 4.6
const RUN_SPEED := 7.2
const CAR_FORWARD_SPEED := 17.0
const CAR_REVERSE_SPEED := 6.0
const JOB_REWARD := 750
const TRAFFIC_SCRIPT = preload("res://scripts/traffic_vehicle.gd")
const PEDESTRIAN_SCRIPT = preload("res://scripts/pedestrian.gd")

var mats: Dictionary = {}
var window_transforms: Array[Transform3D] = []
var trim_transforms: Array[Transform3D] = []
var lane_transforms: Array[Transform3D] = []
var crosswalk_transforms: Array[Transform3D] = []
var player: CharacterBody3D
var car: CharacterBody3D
var bike: CharacterBody3D
var active_vehicle: CharacterBody3D
var active_vehicle_kind := "car"
var bike_button: Button
var camera: Camera3D
var pickup_marker: Node3D
var drop_marker: Node3D

var driving := false
var car_speed := 0.0
var move_touch := Vector2.ZERO
var run_touch := false
var throttle_touch := 0.0
var steer_touch := 0.0
var job_stage := 0
var job_title := ""
var job_reward_active := 0
var toast_time := 0.0
var autosave_time := 20.0
var performance_check_time := 0.0
var low_fps_samples := 0
var high_fps_samples := 0
var perf_display_time := 0.0
var fuel_empty_notified := false

var hud_layer: CanvasLayer
var wallet_label: Label
var location_label: Label
var fuel_label: Label
var perf_label: Label
var toast_label: Label
var bank_panel: PanelContainer
var phone_panel: PanelContainer
var empire_panel: PanelContainer
var job_panel: PanelContainer
var bank_info: Label
var job_info: Label
var phone_info: Label
var empire_info: Label
var status_panel: PanelContainer
var top_buttons: HBoxContainer
var left_pad: PanelContainer
var right_pad: PanelContainer

func _ready() -> void:
    # Target stable 30 FPS on baseline Android hardware. Render the 3D world
    # slightly below native resolution while keeping all HUD elements crisp.
    Engine.max_fps = 60
    get_viewport().scaling_3d_scale = 0.80
    GameState.state_changed.connect(_refresh_ui)
    GameState.toast_requested.connect(_show_toast)
    _create_materials()
    _build_environment()
    _build_city()
    _build_player()
    _build_car()
    if GameState.bike_owned:
        _build_bike()
    _build_job_markers()
    _build_hud()
    car.global_position = GameState.car_position
    car.rotation.y = GameState.car_rotation_y
    if is_instance_valid(bike):
        bike.global_position = GameState.bike_position
        bike.rotation.y = GameState.bike_rotation_y
    player.global_position = GameState.player_position
    if player.global_position.y < 0.8:
        player.global_position.y = 1.0
    if GameState.was_driving:
        active_vehicle_kind = GameState.active_vehicle_kind
        if active_vehicle_kind == "motorbike" and is_instance_valid(bike):
            active_vehicle = bike
        else:
            active_vehicle_kind = "car"
            active_vehicle = car
        driving = true
        player.global_position = active_vehicle.global_position + Vector3(0.0, 0.1, 0.0)
        player.hide()
        player.collision_layer = 0
        player.collision_mask = 0
    _refresh_ui()
    _show_toast("Welcome to Navapura. Start a delivery and build your empire.")

func _create_materials() -> void:
    mats = {
        "asphalt": _material(Color("#34383d"), 0.96),
        "road_line": _material(Color("#e8d58a"), 0.82),
        "sidewalk": _material(Color("#b7b4aa"), 0.92),
        "grass": _material(Color("#657c55"), 1.0),
        "concrete": _material(Color("#b8b1a2"), 0.95),
        "cream": _material(Color("#d8c9ac"), 0.9),
        "blue": _material(Color("#728fa0"), 0.82),
        "brick": _material(Color("#956c58"), 0.95),
        "glass": _material(Color("#446d7d"), 0.34),
        "dark": _material(Color("#282d31"), 0.9),
        "green": _material(Color("#557d50"), 1.0),
        "skin": _material(Color("#b9825e"), 0.8),
        "player": _material(Color("#315e83"), 0.78),
        "car": _material(Color("#246b9b"), 0.38),
        "yellow": _material(Color("#e6b94e"), 0.55),
        "white": _material(Color("#e9e5db"), 0.65),
        "red": _material(Color("#a8493e"), 0.8)
    }

func _material(color: Color, rough: float) -> StandardMaterial3D:
    var result := StandardMaterial3D.new()
    result.albedo_color = color
    result.roughness = rough
    return result

func _box_mesh(parent: Node3D, size: Vector3, position: Vector3, material: Material, node_name := "Mesh") -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    var box := BoxMesh.new()
    box.size = size
    instance.mesh = box
    instance.position = position
    instance.material_override = material
    parent.add_child(instance)
    return instance

func _static_box(parent: Node3D, size: Vector3, position: Vector3, material: Material, node_name := "StaticBox") -> StaticBody3D:
    var body := StaticBody3D.new()
    body.name = node_name
    body.position = position
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    _box_mesh(body, size, Vector3.ZERO, material, "Visual")
    parent.add_child(body)
    return body

func _build_environment() -> void:
    var world := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    sky.sky_material = ProceduralSkyMaterial.new()
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.72, 0.76, 0.82)
    environment.ambient_light_energy = 0.82
    environment.ambient_light_color = Color("#c5d0d8")
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    var sky_material := sky.sky_material as ProceduralSkyMaterial
    sky_material.sky_top_color = Color("#5e8fb8")
    sky_material.sky_horizon_color = Color("#c7d7df")
    sky_material.ground_bottom_color = Color("#303c43")
    sky_material.ground_horizon_color = Color("#a2b1b6")
    world.environment = environment
    add_child(world)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
    sun.light_energy = 1.15
    # Real-time shadow maps are disproportionately expensive on entry-level phones.
    # Ambient/fill lighting keeps the scene readable without them.
    sun.shadow_enabled = false
    add_child(sun)

    _static_box(self, Vector3(CITY_EXTENT, 0.5, CITY_EXTENT), Vector3(0.0, -0.3, 0.0), mats["grass"], "Ground")

func _build_city() -> void:
    # A compact, connected street grid for the first playable city sector.
    for lane in [-80.0, -40.0, 0.0, 40.0, 80.0]:
        _box_mesh(self, Vector3(CITY_EXTENT, 0.12, 12.0), Vector3(0.0, 0.0, lane), mats["asphalt"], "EastWestRoad")
        _box_mesh(self, Vector3(12.0, 0.12, CITY_EXTENT), Vector3(lane, 0.01, 0.0), mats["asphalt"], "NorthSouthRoad")
        # Raised concrete curbs, kept outside the carriageway.
        for side in [-1.0, 1.0]:
            _box_mesh(self, Vector3(CITY_EXTENT, 0.22, 0.28), Vector3(0.0, 0.08, lane + side * 6.2), mats["sidewalk"], "RoadCurb")
            _box_mesh(self, Vector3(0.28, 0.22, CITY_EXTENT), Vector3(lane + side * 6.2, 0.08, 0.0), mats["sidewalk"], "RoadCurb")
        # Short dashed center markings, batched into one draw call later.
        for mark in range(-9, 10):
            if abs(mark) % 2 == 1:
                continue
            lane_transforms.append(Transform3D(Basis.IDENTITY, Vector3(float(mark) * 10.0, 0.09, lane)))
            lane_transforms.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(lane, 0.09, float(mark) * 10.0)))

    # Sidewalks are split at junctions, so pavement never forms long slabs
    # across a perpendicular road.
    var blocks := [[-108.0, -86.0], [-74.0, -46.0], [-34.0, -6.0], [6.0, 34.0], [46.0, 74.0], [86.0, 108.0]]
    for road_z in [-80.0, -40.0, 0.0, 40.0, 80.0]:
        for side in [-1.0, 1.0]:
            for interval in blocks:
                var length: float = float(interval[1]) - float(interval[0])
                var center: float = (float(interval[0]) + float(interval[1])) * 0.5
                _box_mesh(self, Vector3(length, 0.14, 1.8), Vector3(center, 0.055, road_z + side * 6.9), mats["sidewalk"], "BlockSidewalk")
    for road_x in [-80.0, -40.0, 0.0, 40.0, 80.0]:
        for side in [-1.0, 1.0]:
            for interval in blocks:
                var length: float = float(interval[1]) - float(interval[0])
                var center: float = (float(interval[0]) + float(interval[1])) * 0.5
                _box_mesh(self, Vector3(1.8, 0.14, length), Vector3(road_x + side * 6.9, 0.055, center), mats["sidewalk"], "BlockSidewalk")

    var palettes: Array[Material] = [mats["cream"], mats["blue"], mats["brick"], mats["concrete"]]
    var index := 0
    for x in [-60.0, -20.0, 20.0, 60.0]:
        for z in [-60.0, -20.0, 20.0, 60.0]:
            var width := 13.0 + float(index % 3) * 1.4
            var depth := 13.0 + float((index + 1) % 3) * 1.3
            var height := 7.0 + float((index * 5) % 12)
            _build_building(Vector3(x, height * 0.5, z), Vector3(width, height, depth), palettes[index % palettes.size()], index)
            index += 1

    for p in [
        Vector3(-28.0, 0.0, -13.0), Vector3(28.0, 0.0, -13.0),
        Vector3(-28.0, 0.0, 28.0), Vector3(28.0, 0.0, 28.0),
        Vector3(52.0, 0.0, -28.0), Vector3(-52.0, 0.0, 52.0),
        Vector3(12.0, 0.0, 52.0), Vector3(-12.0, 0.0, -52.0)
    ]:
        _build_tree(p)

    _build_window_batch()
    _build_road_markings()
    _build_street_sign(Vector3(0.0, 0.0, -3.0), "NAVAPURA")
    _build_street_lights()
    _build_traffic()
    _build_pedestrians()

func _build_traffic() -> void:
    var route := PackedVector3Array([
        Vector3(-90.0, 0.55, -80.0),
        Vector3(-40.0, 0.55, -80.0),
        Vector3(0.0, 0.55, -80.0),
        Vector3(40.0, 0.55, -80.0),
        Vector3(80.0, 0.55, -80.0),
        Vector3(80.0, 0.55, -40.0),
        Vector3(80.0, 0.55, 0.0),
        Vector3(80.0, 0.55, 40.0),
        Vector3(80.0, 0.55, 80.0),
        Vector3(40.0, 0.55, 80.0),
        Vector3(0.0, 0.55, 80.0),
        Vector3(-40.0, 0.55, 80.0),
        Vector3(-80.0, 0.55, 80.0),
        Vector3(-80.0, 0.55, 40.0),
        Vector3(-80.0, 0.55, 0.0),
        Vector3(-80.0, 0.55, -40.0)
    ])
    var colors: Array[Color] = [Color("#b94c3d"), Color("#d1a33f"), Color("#e5e2d8")]
    for i in range(3):
        var traffic_car := Node3D.new()
        traffic_car.set_script(TRAFFIC_SCRIPT)
        traffic_car.set("route", route)
        traffic_car.set("start_index", i * 5)
        traffic_car.set("speed", 5.0 + float(i) * 0.45)
        traffic_car.set("paint_color", colors[i])
        add_child(traffic_car)

func _build_pedestrians() -> void:
    var routes: Array[PackedVector3Array] = [
        PackedVector3Array([Vector3(-32.0, 0.9, -30.0), Vector3(-32.0, 0.9, 30.0), Vector3(-48.0, 0.9, 30.0), Vector3(-48.0, 0.9, -30.0)]),
        PackedVector3Array([Vector3(32.0, 0.9, 30.0), Vector3(32.0, 0.9, -30.0), Vector3(48.0, 0.9, -30.0), Vector3(48.0, 0.9, 30.0)]),
        PackedVector3Array([Vector3(-30.0, 0.9, -32.0), Vector3(30.0, 0.9, -32.0), Vector3(30.0, 0.9, -48.0), Vector3(-30.0, 0.9, -48.0)]),
        PackedVector3Array([Vector3(30.0, 0.9, 32.0), Vector3(-30.0, 0.9, 32.0), Vector3(-30.0, 0.9, 48.0), Vector3(30.0, 0.9, 48.0)])
    ]
    var clothes: Array[Color] = [Color("#315e83"), Color("#9b5a43"), Color("#4f7550"), Color("#80628c")]
    for i in range(routes.size()):
        var pedestrian := Node3D.new()
        pedestrian.set_script(PEDESTRIAN_SCRIPT)
        pedestrian.set("route", routes[i])
        pedestrian.set("start_index", 0)
        pedestrian.set("walk_speed", 1.0 + float(i % 2) * 0.25)
        pedestrian.set("clothing_color", clothes[i])
        add_child(pedestrian)

func _build_building(center: Vector3, size: Vector3, facade: Material, index: int) -> void:
    var body := StaticBody3D.new()
    body.position = center
    var shape_node := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    shape_node.shape = shape
    body.add_child(shape_node)
    _box_mesh(body, size, Vector3.ZERO, facade, "BuildingFacade")
    _box_mesh(body, Vector3(size.x + 0.35, 0.35, size.z + 0.35), Vector3(0.0, size.y * 0.5 + 0.18, 0.0), mats["dark"], "Roof")
    add_child(body)

    # Repeated facade elements are GPU-instanced across the whole city sector.
    var window_rows := mini(int(size.y / 3.8), 4)
    for row in range(window_rows):
        for column in range(3):
            var wx := (float(column) - 1.0) * size.x * 0.29
            var wy := -size.y * 0.5 + 2.0 + float(row) * 3.2
            window_transforms.append(Transform3D(Basis.IDENTITY, center + Vector3(wx, wy, -size.z * 0.5 - 0.08)))
            window_transforms.append(Transform3D(Basis.IDENTITY, center + Vector3(wx, wy, size.z * 0.5 + 0.08)))
        if row > 0:
            trim_transforms.append(Transform3D(Basis.IDENTITY, center + Vector3(0.0, -size.y * 0.5 + 1.0 + float(row) * 3.2, -size.z * 0.5 - 0.08)))
    if index % 4 == 0:
        _build_shop_front(body, size, index)

func _create_multimesh_batch(mesh: Mesh, material: Material, transforms: Array[Transform3D], node_name: String) -> void:
    if transforms.is_empty():
        return
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = mesh
    mm.instance_count = transforms.size()
    mm.visible_instance_count = transforms.size()
    for i in range(transforms.size()):
        mm.set_instance_transform(i, transforms[i])
    var instance := MultiMeshInstance3D.new()
    instance.name = node_name
    instance.multimesh = mm
    instance.material_override = material
    add_child(instance)

func _build_window_batch() -> void:
    var window_mesh := BoxMesh.new()
    window_mesh.size = Vector3(1.5, 1.05, 0.10)
    _create_multimesh_batch(window_mesh, mats["glass"], window_transforms, "InstancedCityWindows")
    var trim_mesh := BoxMesh.new()
    trim_mesh.size = Vector3(11.5, 0.13, 0.18)
    _create_multimesh_batch(trim_mesh, mats["white"], trim_transforms, "InstancedFacadeTrims")

func _build_road_markings() -> void:
    var dash := BoxMesh.new()
    dash.size = Vector3(2.6, 0.035, 0.15)
    _create_multimesh_batch(dash, mats["road_line"], lane_transforms, "InstancedLaneDashes")
    var zebra := BoxMesh.new()
    zebra.size = Vector3(0.55, 0.04, 4.8)
    var crossings: Array[Transform3D] = []
    for intersection in [-80.0, -40.0, 0.0, 40.0, 80.0]:
        for offset in range(-4, 5):
            crossings.append(Transform3D(Basis.IDENTITY, Vector3(intersection + float(offset) * 0.85, 0.095, intersection - 8.5)))
            crossings.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(intersection - 8.5, 0.095, intersection + float(offset) * 0.85)))
    _create_multimesh_batch(zebra, mats["white"], crossings, "InstancedZebraCrossings")

func _build_shop_front(parent: Node3D, size: Vector3, index: int) -> void:
    var sign_color: Material = mats["red"] if index % 8 == 0 else mats["blue"]
    _box_mesh(parent, Vector3(4.5, 0.72, 0.24), Vector3(0.0, -size.y * 0.5 + 1.65, -size.z * 0.5 - 0.18), sign_color, "ShopCanopy")
    _box_mesh(parent, Vector3(2.7, 1.7, 0.10), Vector3(0.0, -size.y * 0.5 + 0.75, -size.z * 0.5 - 0.08), mats["glass"], "ShopfrontWindow")
    var sign := Label3D.new()
    var names := ["MARKET", "TEA HOUSE", "MOBILE HUB", "GROCERY"]
    sign.text = names[(index / 4) % names.size()]
    sign.font_size = 28
    sign.outline_size = 5
    sign.modulate = Color("#fff4d8")
    sign.position = Vector3(0.0, -size.y * 0.5 + 1.75, -size.z * 0.5 - 0.33)
    sign.pixel_size = 0.012
    parent.add_child(sign)

func _build_street_lights() -> void:
    for x in [-68.0, -28.0, 28.0, 68.0]:
        for z in [-68.0, 68.0]:
            var pole := MeshInstance3D.new()
            var pole_mesh := CylinderMesh.new()
            pole_mesh.top_radius = 0.07
            pole_mesh.bottom_radius = 0.12
            pole_mesh.height = 6.5
            pole.mesh = pole_mesh
            pole.position = Vector3(x, 3.25, z)
            pole.material_override = mats["dark"]
            add_child(pole)
            _box_mesh(self, Vector3(1.1, 0.12, 0.22), Vector3(x + 0.42, 6.3, z), mats["dark"], "StreetLightArm")
            var lamp := _box_mesh(self, Vector3(0.7, 0.16, 0.45), Vector3(x + 0.78, 6.23, z), mats["yellow"], "StreetLamp")
            var glow := StandardMaterial3D.new()
            glow.albedo_color = Color("#f3d69b")
            glow.emission_enabled = true
            glow.emission = Color("#f1c878")
            glow.emission_energy_multiplier = 0.35
            lamp.material_override = glow

func _build_tree(position: Vector3) -> void:
    var trunk := MeshInstance3D.new()
    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.18
    trunk_mesh.bottom_radius = 0.28
    trunk_mesh.height = 2.8
    trunk.mesh = trunk_mesh
    trunk.position = position + Vector3(0.0, 1.4, 0.0)
    trunk.material_override = mats["brick"]
    add_child(trunk)

    var crown := MeshInstance3D.new()
    var crown_mesh := SphereMesh.new()
    crown_mesh.radius = 1.45
    crown_mesh.height = 2.9
    crown.mesh = crown_mesh
    crown.position = position + Vector3(0.0, 3.25, 0.0)
    crown.material_override = mats["green"]
    add_child(crown)

func _build_street_sign(position: Vector3, label_text: String) -> void:
    var pole := MeshInstance3D.new()
    var pole_mesh := CylinderMesh.new()
    pole_mesh.top_radius = 0.07
    pole_mesh.bottom_radius = 0.07
    pole_mesh.height = 3.5
    pole.mesh = pole_mesh
    pole.position = position + Vector3(0.0, 1.75, 0.0)
    pole.material_override = mats["dark"]
    add_child(pole)
    _box_mesh(self, Vector3(4.0, 0.75, 0.16), position + Vector3(0.0, 3.0, 0.0), mats["blue"], "CitySign")

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3(0.0, 1.0, 4.5)
    player.floor_snap_length = 0.25

    var collider := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.38
    capsule.height = 1.8
    collider.shape = capsule
    player.add_child(collider)

    # A readable, low-poly human silhouette instead of a single capsule.
    _add_capsule_piece(player, 0.29, 1.02, Vector3(0.0, 0.22, 0.0), mats["player"], "Torso")
    _box_mesh(player, Vector3(0.48, 0.28, 0.30), Vector3(0.0, -0.27, 0.0), mats["blue"], "Waist")
    for side in [-1.0, 1.0]:
        _add_capsule_piece(player, 0.13, 0.78, Vector3(side * 0.15, -0.63, 0.0), mats["dark"], "Leg")
        _box_mesh(player, Vector3(0.22, 0.13, 0.36), Vector3(side * 0.15, -1.01, -0.05), mats["dark"], "Shoe")
        var arm := _add_capsule_piece(player, 0.105, 0.72, Vector3(side * 0.36, 0.22, 0.0), mats["player"], "Arm")
        arm.rotation.z = side * -0.12

    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.205
    head_mesh.height = 0.41
    head.mesh = head_mesh
    head.position = Vector3(0.0, 0.93, 0.0)
    head.material_override = mats["skin"]
    player.add_child(head)
    var hair := MeshInstance3D.new()
    var hair_mesh := SphereMesh.new()
    hair_mesh.radius = 0.21
    hair_mesh.height = 0.22
    hair.mesh = hair_mesh
    hair.position = Vector3(0.0, 1.08, 0.0)
    hair.material_override = mats["dark"]
    player.add_child(hair)
    add_child(player)

    camera = Camera3D.new()
    camera.name = "FollowCamera"
    camera.position = player.global_position + Vector3(0.0, 5.0, 8.5)
    camera.current = true
    camera.fov = 68.0
    camera.near = 0.1
    camera.far = 240.0
    add_child(camera)
    camera.look_at(player.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)

func _add_capsule_piece(parent: Node3D, radius: float, height: float, position: Vector3, material: Material, node_name: String) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    var capsule := CapsuleMesh.new()
    capsule.radius = radius
    capsule.height = height
    instance.mesh = capsule
    instance.position = position
    instance.material_override = material
    parent.add_child(instance)
    return instance

func _build_car() -> void:
    car = CharacterBody3D.new()
    car.name = "StarterCar"
    car.position = Vector3(0.0, 0.72, 0.0)
    car.floor_snap_length = 0.25

    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(2.1, 1.0, 4.0)
    collider.shape = shape
    car.add_child(collider)

    # Sculpted body layers, glazing, lamps, grille and properly grounded wheels.
    _box_mesh(car, Vector3(2.0, 0.66, 3.8), Vector3(0.0, 0.0, 0.0), mats["car"], "CarBody")
    _box_mesh(car, Vector3(1.55, 0.68, 1.82), Vector3(0.0, 0.57, -0.10), mats["glass"], "Cabin")
    _box_mesh(car, Vector3(1.70, 0.12, 0.95), Vector3(0.0, 0.36, -1.28), mats["car"], "Bonnet")
    _box_mesh(car, Vector3(1.72, 0.12, 0.70), Vector3(0.0, 0.37, 1.45), mats["car"], "Boot")
    _box_mesh(car, Vector3(2.04, 0.18, 0.18), Vector3(0.0, -0.21, -1.98), mats["dark"], "FrontBumper")
    _box_mesh(car, Vector3(2.04, 0.18, 0.18), Vector3(0.0, -0.21, 1.98), mats["dark"], "RearBumper")
    _box_mesh(car, Vector3(0.72, 0.18, 0.07), Vector3(0.0, -0.02, -2.015), mats["dark"], "FrontGrille")
    for x in [-0.68, 0.68]:
        _box_mesh(car, Vector3(0.38, 0.20, 0.07), Vector3(x, 0.12, -2.02), mats["yellow"], "HeadLamp")
        _box_mesh(car, Vector3(0.34, 0.18, 0.07), Vector3(x, 0.10, 2.02), mats["red"], "TailLamp")
        _box_mesh(car, Vector3(0.08, 0.12, 0.32), Vector3(x * 1.42, 0.44, -0.48), mats["dark"], "SideMirror")
        _box_mesh(car, Vector3(0.10, 0.08, 0.36), Vector3(x * 1.01, 0.05, 0.25), mats["white"], "DoorHandle")
    _box_mesh(car, Vector3(1.36, 0.08, 0.08), Vector3(0.0, 0.91, -0.16), mats["dark"], "RoofTrim")
    for x in [-0.94, 0.94]:
        for z in [-1.25, 1.25]:
            var wheel := MeshInstance3D.new()
            var wheel_mesh := CylinderMesh.new()
            wheel_mesh.top_radius = 0.36
            wheel_mesh.bottom_radius = 0.36
            wheel_mesh.height = 0.27
            wheel.mesh = wheel_mesh
            wheel.rotation_degrees.z = 90.0
            wheel.position = Vector3(x, -0.34, z)
            wheel.material_override = mats["dark"]
            car.add_child(wheel)
            var hub := MeshInstance3D.new()
            var hub_mesh := CylinderMesh.new()
            hub_mesh.top_radius = 0.16
            hub_mesh.bottom_radius = 0.16
            hub_mesh.height = 0.285
            hub.mesh = hub_mesh
            hub.rotation_degrees.z = 90.0
            hub.position = Vector3(x * 1.01, -0.34, z)
            hub.material_override = mats["white"]
            car.add_child(hub)
    add_child(car)

func _build_bike() -> void:
    if is_instance_valid(bike):
        return
    bike = CharacterBody3D.new()
    bike.name = "StarterMotorbike"
    bike.position = Vector3(6.0, 0.58, 0.0)
    bike.floor_snap_length = 0.25

    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(0.88, 0.95, 2.25)
    collider.shape = shape
    bike.add_child(collider)

    # Low-poly commuter motorcycle with separate wheels, frame, tank and cockpit.
    for wheel_z in [-0.88, 0.88]:
        var wheel := MeshInstance3D.new()
        var wheel_mesh := TorusMesh.new()
        wheel_mesh.inner_radius = 0.29
        wheel_mesh.outer_radius = 0.43
        wheel_mesh.rings = 8
        wheel_mesh.ring_segments = 12
        wheel.mesh = wheel_mesh
        wheel.rotation_degrees.y = 90.0
        wheel.position = Vector3(0.0, -0.12, wheel_z)
        wheel.material_override = mats["dark"]
        bike.add_child(wheel)

        var hub := MeshInstance3D.new()
        var hub_mesh := CylinderMesh.new()
        hub_mesh.top_radius = 0.12
        hub_mesh.bottom_radius = 0.12
        hub_mesh.height = 0.22
        hub.mesh = hub_mesh
        hub.rotation_degrees.z = 90.0
        hub.position = Vector3(0.0, -0.12, wheel_z)
        hub.material_override = mats["white"]
        bike.add_child(hub)

    _box_mesh(bike, Vector3(0.20, 0.20, 1.30), Vector3(0.0, 0.12, 0.0), mats["red"], "BikeFrame")
    _box_mesh(bike, Vector3(0.48, 0.42, 0.48), Vector3(0.0, -0.14, 0.12), mats["dark"], "Engine")
    _box_mesh(bike, Vector3(0.42, 0.16, 0.62), Vector3(0.0, 0.48, 0.48), mats["dark"], "Seat")
    _box_mesh(bike, Vector3(0.52, 0.42, 0.70), Vector3(0.0, 0.43, -0.18), mats["yellow"], "FuelTank")
    _box_mesh(bike, Vector3(0.12, 0.80, 0.12), Vector3(0.0, 0.28, -0.78), mats["white"], "FrontFork")
    _box_mesh(bike, Vector3(1.0, 0.08, 0.10), Vector3(0.0, 0.78, -0.84), mats["dark"], "Handlebar")
    _box_mesh(bike, Vector3(0.24, 0.22, 0.18), Vector3(0.0, 0.65, -0.91), mats["yellow"], "Headlight")
    _box_mesh(bike, Vector3(0.15, 0.12, 0.12), Vector3(0.0, 0.48, 0.96), mats["red"], "RearLight")

    var exhaust := MeshInstance3D.new()
    var exhaust_mesh := CylinderMesh.new()
    exhaust_mesh.top_radius = 0.07
    exhaust_mesh.bottom_radius = 0.07
    exhaust_mesh.height = 0.88
    exhaust.mesh = exhaust_mesh
    exhaust.rotation_degrees.x = 90.0
    exhaust.position = Vector3(0.34, -0.25, 0.42)
    exhaust.material_override = mats["white"]
    bike.add_child(exhaust)
    add_child(bike)

func _build_job_markers() -> void:
    pickup_marker = _make_marker(mats["yellow"])
    pickup_marker.position = Vector3(-16.0, 0.85, 0.0)
    drop_marker = _make_marker(mats["green"])
    drop_marker.position = Vector3(0.0, 0.85, 40.0)
    add_child(pickup_marker)
    add_child(drop_marker)
    pickup_marker.hide()
    drop_marker.hide()

func _make_marker(material: Material) -> Node3D:
    var root := Node3D.new()
    var orb := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.75
    sphere.height = 1.5
    orb.mesh = sphere
    orb.material_override = material
    root.add_child(orb)
    return root

func _build_hud() -> void:
    hud_layer = CanvasLayer.new()
    add_child(hud_layer)

    status_panel = PanelContainer.new()
    status_panel.position = Vector2(18.0, 16.0)
    status_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.07, 0.10, 0.88)))
    hud_layer.add_child(status_panel)
    var status_box := VBoxContainer.new()
    status_panel.add_child(status_box)
    wallet_label = Label.new()
    wallet_label.add_theme_font_size_override("font_size", 21)
    status_box.add_child(wallet_label)
    location_label = Label.new()
    location_label.text = "NAVAPURA • ON FOOT"
    status_box.add_child(location_label)
    fuel_label = Label.new()
    fuel_label.add_theme_font_size_override("font_size", 14)
    fuel_label.modulate = Color("#e4d8a7")
    status_box.add_child(fuel_label)
    perf_label = Label.new()
    perf_label.add_theme_font_size_override("font_size", 12)
    perf_label.modulate = Color("#d2dce2")
    status_box.add_child(perf_label)

    top_buttons = HBoxContainer.new()
    top_buttons.position = Vector2(410.0, 18.0)
    top_buttons.add_theme_constant_override("separation", 8)
    hud_layer.add_child(top_buttons)
    _add_button(top_buttons, "PHONE", _toggle_phone)
    _add_button(top_buttons, "BANK", _toggle_bank)
    _add_button(top_buttons, "JOBS", _job_action)
    _add_button(top_buttons, "EMPIRE", _toggle_empire)
    _add_button(top_buttons, "SAVE", _save_now)

    toast_label = Label.new()
    toast_label.position = Vector2(300.0, 90.0)
    toast_label.custom_minimum_size = Vector2(680.0, 38.0)
    toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast_label.add_theme_font_size_override("font_size", 18)
    hud_layer.add_child(toast_label)

    _build_panels()
    _build_touch_controls()
    get_viewport().size_changed.connect(_layout_hud)
    call_deferred("_layout_hud")

func _layout_hud() -> void:
    if not is_instance_valid(hud_layer):
        return
    var view_size := get_viewport().get_visible_rect().size
    var left_size := left_pad.get_combined_minimum_size()
    var right_size := right_pad.get_combined_minimum_size()
    var top_size := top_buttons.get_combined_minimum_size()
    status_panel.position = Vector2(16.0, 14.0)
    top_buttons.position = Vector2(maxf(status_panel.get_combined_minimum_size().x + 22.0, (view_size.x - top_size.x) * 0.5), 16.0)
    left_pad.position = Vector2(18.0, maxf(12.0, view_size.y - left_size.y - 16.0))
    right_pad.position = Vector2(maxf(12.0, view_size.x - right_size.x - 18.0), maxf(12.0, view_size.y - right_size.y - 16.0))
    toast_label.position = Vector2(maxf(12.0, (view_size.x - toast_label.custom_minimum_size.x) * 0.5), 82.0)
    var bank_size := bank_panel.get_combined_minimum_size()
    var phone_size := phone_panel.get_combined_minimum_size()
    var empire_size := empire_panel.get_combined_minimum_size()
    var job_size := job_panel.get_combined_minimum_size()
    bank_panel.position = (view_size - bank_size) * 0.5
    phone_panel.position = (view_size - phone_size) * 0.5
    empire_panel.position = (view_size - empire_size) * 0.5
    job_panel.position = (view_size - job_size) * 0.5

func _panel_style(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(12)
    style.content_margin_left = 14.0
    style.content_margin_right = 14.0
    style.content_margin_top = 12.0
    style.content_margin_bottom = 12.0
    return style

func _add_button(parent: Node, text_value: String, action: Callable, width := 112.0) -> Button:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(width, 44.0)
    button.add_theme_font_size_override("font_size", 15)
    button.pressed.connect(action)
    parent.add_child(button)
    return button

func _add_hold_button(parent: Node, text_value: String, down_action: Callable, up_action: Callable, width := 72.0) -> Button:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(width, 52.0)
    button.add_theme_font_size_override("font_size", 16)
    button.button_down.connect(down_action)
    button.button_up.connect(up_action)
    parent.add_child(button)
    return button

func _build_touch_controls() -> void:
    left_pad = PanelContainer.new()
    left_pad.position = Vector2(20.0, 510.0)
    left_pad.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.07, 0.10, 0.62)))
    hud_layer.add_child(left_pad)
    var dpad := GridContainer.new()
    dpad.columns = 3
    dpad.add_theme_constant_override("h_separation", 4)
    dpad.add_theme_constant_override("v_separation", 4)
    left_pad.add_child(dpad)
    _add_hold_button(dpad, " ", func(): pass, func(): pass, 66.0)
    _add_hold_button(dpad, "▲", func(): _set_move_y(-1.0), func(): _set_move_y(0.0), 66.0)
    _add_hold_button(dpad, " ", func(): pass, func(): pass, 66.0)
    _add_hold_button(dpad, "◀", func(): _set_move_x(-1.0), func(): _set_move_x(0.0), 66.0)
    _add_hold_button(dpad, "▼", func(): _set_move_y(1.0), func(): _set_move_y(0.0), 66.0)
    _add_hold_button(dpad, "▶", func(): _set_move_x(1.0), func(): _set_move_x(0.0), 66.0)
    _add_hold_button(dpad, "RUN", func(): run_touch = true, func(): run_touch = false, 66.0)

    right_pad = PanelContainer.new()
    right_pad.position = Vector2(1010.0, 500.0)
    right_pad.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.07, 0.10, 0.62)))
    hud_layer.add_child(right_pad)
    var action_box := VBoxContainer.new()
    action_box.add_theme_constant_override("separation", 6)
    right_pad.add_child(action_box)
    _add_hold_button(action_box, "ACCEL", func(): throttle_touch = 1.0, func(): throttle_touch = 0.0, 112.0)
    _add_hold_button(action_box, "BRAKE", func(): throttle_touch = -1.0, func(): throttle_touch = 0.0, 112.0)
    _add_button(action_box, "INTERACT", _interact, 112.0)
    _add_button(action_box, "EXIT CAR", _exit_car, 112.0)

func _set_move_x(value: float) -> void:
    move_touch.x = value

func _set_move_y(value: float) -> void:
    move_touch.y = value

func _build_panels() -> void:
    bank_panel = PanelContainer.new()
    bank_panel.position = Vector2(430.0, 150.0)
    bank_panel.custom_minimum_size = Vector2(420.0, 360.0)
    bank_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.08, 0.12, 0.97)))
    hud_layer.add_child(bank_panel)
    var bank_box := VBoxContainer.new()
    bank_box.add_theme_constant_override("separation", 9)
    bank_panel.add_child(bank_box)
    _add_title(bank_box, "NAVAPURA CITY BANK")
    bank_info = Label.new()
    bank_box.add_child(bank_info)
    _add_button(bank_box, "DEPOSIT ₹500", func(): GameState.deposit(500), 180.0)
    _add_button(bank_box, "WITHDRAW ₹500", func(): GameState.withdraw(500), 180.0)
    _add_button(bank_box, "CLOSE", _hide_panels, 120.0)
    bank_panel.hide()

    phone_panel = PanelContainer.new()
    phone_panel.position = Vector2(430.0, 120.0)
    phone_panel.custom_minimum_size = Vector2(420.0, 430.0)
    phone_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.08, 0.12, 0.97)))
    hud_layer.add_child(phone_panel)
    var phone_box := VBoxContainer.new()
    phone_box.add_theme_constant_override("separation", 9)
    phone_panel.add_child(phone_box)
    _add_title(phone_box, "NAVAPURA SMARTPHONE")
    phone_info = Label.new()
    phone_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    phone_box.add_child(phone_info)
    _add_button(phone_box, "OPEN BANK", _toggle_bank, 180.0)
    _add_button(phone_box, "REFUEL VEHICLE • ₹300", _refuel_vehicle, 180.0)
    _add_button(phone_box, "JOB BOARD", _job_action, 180.0)
    _add_button(phone_box, "MY EMPIRE", _toggle_empire, 180.0)
    _add_button(phone_box, "CLOSE PHONE", _hide_panels, 180.0)
    phone_panel.hide()

    job_panel = PanelContainer.new()
    job_panel.custom_minimum_size = Vector2(440.0, 390.0)
    job_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.08, 0.12, 0.98)))
    hud_layer.add_child(job_panel)
    var job_box := VBoxContainer.new()
    job_box.add_theme_constant_override("separation", 8)
    job_panel.add_child(job_box)
    _add_title(job_box, "NAVAPURA JOB BOARD")
    job_info = Label.new()
    job_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    job_box.add_child(job_info)
    _add_button(job_box, "FOOD DELIVERY • ₹650", _start_food_job, 280.0)
    _add_button(job_box, "TAXI PICKUP • ₹500", _start_taxi_job, 280.0)
    _add_button(job_box, "COURIER PARCEL • ₹900", _start_courier_job, 280.0)
    _add_button(job_box, "CANCEL CURRENT JOB", _cancel_job, 280.0)
    _add_button(job_box, "CLOSE", _hide_panels, 120.0)
    job_panel.hide()

    empire_panel = PanelContainer.new()
    empire_panel.position = Vector2(400.0, 100.0)
    empire_panel.custom_minimum_size = Vector2(480.0, 500.0)
    empire_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.08, 0.12, 0.97)))
    hud_layer.add_child(empire_panel)
    var empire_box := VBoxContainer.new()
    empire_box.add_theme_constant_override("separation", 8)
    empire_panel.add_child(empire_box)
    _add_title(empire_box, "LIFE EMPIRE • ASSETS")
    empire_info = Label.new()
    empire_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    empire_box.add_child(empire_info)
    _add_button(empire_box, "BUY STARTER HOME • ₹3,000", _buy_home, 280.0)
    bike_button = _add_button(empire_box, "BUY MOTORBIKE • ₹2,500", _buy_bike, 280.0)
    _add_button(empire_box, "BUY CORNER SHOP • ₹4,000", _buy_shop, 280.0)
    _add_button(empire_box, "COLLECT SHOP INCOME", _collect_shop, 280.0)
    _add_button(empire_box, "SLEEP / NEXT DAY", _next_day, 280.0)
    _add_button(empire_box, "CLOSE", _hide_panels, 120.0)
    empire_panel.hide()

func _add_title(parent: Node, title_text: String) -> void:
    var title := Label.new()
    title.text = title_text
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 22)
    parent.add_child(title)

func _physics_process(delta: float) -> void:
    if player == null or car == null:
        return
    autosave_time -= delta
    if autosave_time <= 0.0:
        _sync_save_state()
        GameState.save_game()
        autosave_time = 20.0
    if Input.is_action_just_pressed("interact"):
        _interact()
    if Input.is_action_just_pressed("ui_cancel"):
        _hide_panels()
    _update_performance(delta)
    if driving:
        _drive_car(delta)
    else:
        _move_player(delta)
    _update_camera(delta)
    _update_job_progress()
    if toast_time > 0.0:
        toast_time -= delta
        if toast_time <= 0.0 and is_instance_valid(toast_label):
            toast_label.text = ""

func _update_performance(delta: float) -> void:
    performance_check_time += delta
    perf_display_time += delta
    if perf_display_time >= 1.0 and is_instance_valid(perf_label):
        var scale_percent := int(round(get_viewport().scaling_3d_scale * 100.0))
        perf_label.text = "FPS %d  •  3D %d%%" % [Engine.get_frames_per_second(), scale_percent]
        perf_display_time = 0.0
    if performance_check_time < 2.0:
        return
    performance_check_time = 0.0
    var fps := Engine.get_frames_per_second()
    var viewport := get_viewport()
    if fps < 42:
        low_fps_samples += 1
        high_fps_samples = 0
        if low_fps_samples >= 2 and viewport.scaling_3d_scale > 0.65:
            viewport.scaling_3d_scale = maxf(0.65, viewport.scaling_3d_scale - 0.05)
            low_fps_samples = 0
    elif fps > 56:
        high_fps_samples += 1
        low_fps_samples = 0
        if high_fps_samples >= 5 and viewport.scaling_3d_scale < 0.85:
            viewport.scaling_3d_scale = minf(0.85, viewport.scaling_3d_scale + 0.05)
            high_fps_samples = 0
    else:
        low_fps_samples = 0
        high_fps_samples = 0

func _move_player(delta: float) -> void:
    var keyboard := Vector2(
        float(Input.is_action_pressed("move_right")) - float(Input.is_action_pressed("move_left")),
        float(Input.is_action_pressed("move_back")) - float(Input.is_action_pressed("move_forward"))
    )
    var input_axis := (keyboard + move_touch).limit_length(1.0)
    var direction := Vector3(input_axis.x, 0.0, input_axis.y)
    var speed := RUN_SPEED if (run_touch or Input.is_action_pressed("run")) else WALK_SPEED
    if direction.length_squared() > 0.001:
        direction = direction.normalized()
        player.rotation.y = lerp_angle(player.rotation.y, atan2(-direction.x, -direction.z), delta * 9.0)
        player.velocity.x = direction.x * speed
        player.velocity.z = direction.z * speed
    else:
        player.velocity.x = move_toward(player.velocity.x, 0.0, speed * 5.0 * delta)
        player.velocity.z = move_toward(player.velocity.z, 0.0, speed * 5.0 * delta)
    if not player.is_on_floor():
        player.velocity.y -= 9.8 * delta
    else:
        player.velocity.y = -0.5
    player.move_and_slide()
    GameState.set_player_position(player.global_position)

func _drive_car(delta: float) -> void:
    if not is_instance_valid(active_vehicle):
        _exit_car()
        return
    var keyboard_throttle := float(Input.is_action_pressed("move_forward")) - float(Input.is_action_pressed("move_back"))
    var throttle := throttle_touch if absf(throttle_touch) > 0.01 else keyboard_throttle
    var bike_mode := active_vehicle_kind == "motorbike"
    if GameState.fuel_percent <= 0.0:
        if not fuel_empty_notified:
            _show_toast("Fuel empty. Open PHONE and refuel for ₹300.")
            fuel_empty_notified = true
        throttle = minf(throttle, 0.0)
        car_speed = move_toward(car_speed, 0.0, 18.0 * delta)
    else:
        fuel_empty_notified = false
    var top_speed := 21.0 if bike_mode else CAR_FORWARD_SPEED
    var reverse_speed := 4.5 if bike_mode else CAR_REVERSE_SPEED
    var acceleration := 15.0 if bike_mode else 12.0
    if throttle > 0.0:
        car_speed = move_toward(car_speed, top_speed, acceleration * delta)
    elif throttle < 0.0:
        if car_speed > 1.0:
            car_speed = move_toward(car_speed, 0.0, 22.0 * delta)
        else:
            car_speed = move_toward(car_speed, -reverse_speed, 8.0 * delta)
    else:
        car_speed = move_toward(car_speed, 0.0, (4.8 if bike_mode else 4.0) * delta)

    var keyboard_steer := float(Input.is_action_pressed("move_right")) - float(Input.is_action_pressed("move_left"))
    var steer := steer_touch if absf(steer_touch) > 0.01 else (move_touch.x if absf(move_touch.x) > 0.01 else keyboard_steer)
    if absf(car_speed) > 0.25:
        var steering_rate := 1.45 if bike_mode else 1.15
        active_vehicle.rotate_y(-steer * delta * steering_rate * clampf(absf(car_speed) / 5.0, 0.2, 1.0) * signf(car_speed))
    var forward := -active_vehicle.global_basis.z
    active_vehicle.velocity.x = forward.x * car_speed
    active_vehicle.velocity.z = forward.z * car_speed
    if not active_vehicle.is_on_floor():
        active_vehicle.velocity.y -= 9.8 * delta
    else:
        active_vehicle.velocity.y = -0.5
    active_vehicle.move_and_slide()
    player.global_position = active_vehicle.global_position + Vector3(0.0, 0.1, 0.0)
    GameState.set_player_position(player.global_position)
    GameState.set_vehicle_state(active_vehicle_kind, active_vehicle.global_position, active_vehicle.rotation.y, true)
    if absf(car_speed) > 0.5:
        GameState.consume_fuel(delta * (0.08 + absf(car_speed) * 0.004))
        _update_fuel_hud()

func _update_camera(delta: float) -> void:
    var focus := active_vehicle.global_position if driving and is_instance_valid(active_vehicle) else player.global_position
    var desired := focus + Vector3(0.0, 5.0, 8.5)
    camera.global_position = camera.global_position.lerp(desired, clampf(delta * 5.0, 0.0, 1.0))
    camera.look_at(focus + Vector3(0.0, 1.0, 0.0), Vector3.UP)

func _update_job_progress() -> void:
    if job_stage == 0:
        return
    var target := pickup_marker.global_position if job_stage == 1 else drop_marker.global_position
    var actor := car.global_position if driving else player.global_position
    if actor.distance_to(target) < 5.0:
        if job_stage == 1:
            job_stage = 2
            pickup_marker.hide()
            drop_marker.show()
            _show_toast("%s pickup complete. Go to the destination." % job_title)
            _refresh_ui()
        else:
            job_stage = 0
            drop_marker.hide()
            var completed_title := job_title
            var completed_reward := job_reward_active
            job_title = ""
            job_reward_active = 0
            GameState.complete_mission(completed_reward, completed_title)
            _show_toast("%s completed. Reward: ₹%d" % [completed_title, completed_reward])
            _refresh_ui()

func _job_action() -> void:
    var should_open := not job_panel.visible
    _hide_panels()
    job_panel.visible = should_open
    _refresh_ui()

func _start_food_job() -> void:
    _start_job("Food delivery", 650, Vector3(-16.0, 0.85, 0.0), Vector3(0.0, 0.85, 40.0))

func _start_taxi_job() -> void:
    _start_job("Taxi passenger", 500, Vector3(40.0, 0.85, 0.0), Vector3(-40.0, 0.85, 40.0))

func _start_courier_job() -> void:
    _start_job("Courier parcel", 900, Vector3(0.0, 0.85, -40.0), Vector3(80.0, 0.85, 0.0))

func _start_job(title: String, reward: int, pickup_position: Vector3, destination_position: Vector3) -> void:
    if job_stage != 0:
        _show_toast("Finish or cancel your current job first.")
        return
    job_title = title
    job_reward_active = reward
    pickup_marker.global_position = pickup_position
    drop_marker.global_position = destination_position
    job_stage = 1
    pickup_marker.show()
    drop_marker.hide()
    _hide_panels()
    _show_toast("%s accepted. Follow the yellow pickup marker." % title)
    _refresh_ui()

func _cancel_job() -> void:
    if job_stage == 0:
        _show_toast("There is no active job to cancel.")
        return
    job_stage = 0
    job_title = ""
    job_reward_active = 0
    pickup_marker.hide()
    drop_marker.hide()
    _hide_panels()
    _show_toast("Job cancelled. No reward was paid.")
    _refresh_ui()

func _interact() -> void:
    if driving:
        _exit_car()
        return
    var nearest_vehicle: CharacterBody3D = car
    var nearest_distance := player.global_position.distance_to(car.global_position)
    var vehicle_kind := "car"
    if is_instance_valid(bike):
        var bike_distance := player.global_position.distance_to(bike.global_position)
        if bike_distance < nearest_distance:
            nearest_vehicle = bike
            nearest_distance = bike_distance
            vehicle_kind = "motorbike"
    if nearest_distance <= 5.5:
        active_vehicle = nearest_vehicle
        active_vehicle_kind = vehicle_kind
        driving = true
        player.hide()
        player.collision_layer = 0
        player.collision_mask = 0
        car_speed = 0.0
        GameState.set_vehicle_state(active_vehicle_kind, active_vehicle.global_position, active_vehicle.rotation.y, true)
        _show_toast("You entered your %s. Use ACCEL and BRAKE." % vehicle_kind)
        _refresh_ui()
    else:
        _show_toast("Walk closer to your car or motorbike to enter.")

func _exit_car() -> void:
    if not driving:
        return
    driving = false
    if is_instance_valid(active_vehicle):
        var side_offset := 1.6 if active_vehicle_kind == "motorbike" else 2.4
        player.global_position = active_vehicle.global_position + active_vehicle.global_basis.x * side_offset + Vector3(0.0, 0.35, 0.0)
    player.show()
    player.collision_layer = 1
    player.collision_mask = 1
    player.velocity = Vector3.ZERO
    car_speed = 0.0
    if is_instance_valid(active_vehicle):
        GameState.set_vehicle_state(active_vehicle_kind, active_vehicle.global_position, active_vehicle.rotation.y, false)
    _show_toast("You left the %s." % active_vehicle_kind)
    active_vehicle = null
    _refresh_ui()

func _toggle_bank() -> void:
    var should_open := not bank_panel.visible
    _hide_panels()
    bank_panel.visible = should_open

func _toggle_phone() -> void:
    var should_open := not phone_panel.visible
    _hide_panels()
    phone_panel.visible = should_open

func _toggle_empire() -> void:
    var should_open := not empire_panel.visible
    _hide_panels()
    empire_panel.visible = should_open

func _hide_panels() -> void:
    bank_panel.hide()
    phone_panel.hide()
    job_panel.hide()
    empire_panel.hide()

func _buy_home() -> void:
    GameState.buy_home()

func _refuel_vehicle() -> void:
    if GameState.refuel_vehicle():
        fuel_empty_notified = false
        _update_fuel_hud()
        _refresh_ui()

func _buy_bike() -> void:
    if GameState.bike_owned:
        _show_toast("Your motorbike is parked beside the central road.")
        return
    if GameState.buy_bike():
        _build_bike()
        _refresh_ui()

func _buy_shop() -> void:
    GameState.buy_shop()

func _collect_shop() -> void:
    GameState.collect_shop_income()

func _next_day() -> void:
    GameState.advance_day()

func _sync_save_state() -> void:
    if is_instance_valid(player):
        GameState.set_player_position(player.global_position)
    if driving and is_instance_valid(active_vehicle):
        GameState.set_vehicle_state(active_vehicle_kind, active_vehicle.global_position, active_vehicle.rotation.y, true)
    else:
        GameState.was_driving = false

func _save_now() -> void:
    _sync_save_state()
    GameState.save_game()
    _show_toast("Game saved on this device.")

func _refresh_ui() -> void:
    if not is_instance_valid(wallet_label):
        return
    wallet_label.text = "WALLET  ₹%d     BANK  ₹%d" % [GameState.wallet, GameState.bank_balance]
    _update_fuel_hud()
    var travel_state := "DRIVING %s" % active_vehicle_kind.to_upper() if driving else "ON FOOT"
    location_label.text = "NAVAPURA  •  %s  •  NET WORTH ₹%d" % [travel_state, GameState.net_worth()]
    if is_instance_valid(bank_info):
        var recent := ""
        for i in range(mini(GameState.transactions.size(), 5)):
            recent += "• %s\n" % GameState.transactions[i]
        bank_info.text = "Wallet: ₹%d\nBank: ₹%d\nNet worth: ₹%d\n\nRECENT TRANSACTIONS\n%s" % [GameState.wallet, GameState.bank_balance, GameState.net_worth(), recent]
    if is_instance_valid(phone_info):
        phone_info.text = "Day %d\nWallet ₹%d  •  Bank ₹%d\nFuel: %d%%\nCompleted jobs: %d\nYour phone connects your jobs, bank and empire." % [GameState.day_number, GameState.wallet, GameState.bank_balance, int(round(GameState.fuel_percent)), GameState.missions_completed]
    if is_instance_valid(job_info):
        if job_stage == 0:
            job_info.text = "Choose a job. Complete the pickup and reach the destination to earn your reward.\nCompleted jobs: %d" % GameState.missions_completed
        else:
            job_info.text = "ACTIVE: %s\nReward: ₹%d\nStep: %s" % [job_title, job_reward_active, "Go to pickup" if job_stage == 1 else "Deliver to destination"]
    if is_instance_valid(bike_button):
        bike_button.text = "MOTORBIKE OWNED • ₹2,500 VALUE" if GameState.bike_owned else "BUY MOTORBIKE • ₹2,500"
    if is_instance_valid(empire_info):
        empire_info.text = "Day %d\nWallet: ₹%d  |  Bank: ₹%d\nHome: %s\nCorner shop: %s\nMotorbike: %s\nUncollected income: ₹%d\nLifetime earnings: ₹%d\nNet worth: ₹%d" % [
            GameState.day_number,
            GameState.wallet,
            GameState.bank_balance,
            "Owned" if GameState.home_owned else "Not owned",
            "Owned" if GameState.shop_owned else "Not owned",
            "Owned" if GameState.bike_owned else "Not owned",
            GameState.uncollected_shop_income,
            GameState.lifetime_earnings,
            GameState.net_worth()
        ]

func _update_fuel_hud() -> void:
    if is_instance_valid(fuel_label):
        fuel_label.text = "FUEL  %d%%" % int(round(GameState.fuel_percent))
        fuel_label.modulate = Color("#e4d8a7") if GameState.fuel_percent > 20.0 else Color("#e28b78")

func _show_toast(message: String) -> void:
    if is_instance_valid(toast_label):
        toast_label.text = message
        toast_time = 3.5

func _notification(what: int) -> void:
    if (what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED) and is_instance_valid(player):
        _sync_save_state()
        GameState.save_game()
