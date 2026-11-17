extends Node3D

const CITY_EXTENT := 220.0
const WALK_SPEED := 4.6
const RUN_SPEED := 7.2
const CAR_FORWARD_SPEED := 17.0
const CAR_REVERSE_SPEED := 6.0
const JOB_REWARD := 750
const TRAFFIC_SCRIPT = preload("res://scripts/traffic_vehicle.gd")
const PEDESTRIAN_SCRIPT = preload("res://scripts/pedestrian.gd")
const MINIMAP_SCRIPT = preload("res://scripts/minimap.gd")
const HOME_DOOR_POSITION := Vector3(100.0, 1.0, 98.0)
const HOME_INTERIOR_POSITION := Vector3(150.0, 1.0, 150.0)
const SHOP_DOOR_POSITION := Vector3(-20.0, 1.0, -68.0)
const SHOP_INTERIOR_POSITION := Vector3(180.0, 1.0, 150.0)

var mats: Dictionary = {}
var game_environment: Environment
var procedural_sky: ProceduralSkyMaterial
var sun_light: DirectionalLight3D
var home_interior: Node3D
var home_sign: Label3D
var shop_interior: Node3D
var shop_sign: Label3D
var window_transforms: Array[Transform3D] = []
var trim_transforms: Array[Transform3D] = []
var lane_transforms: Array[Transform3D] = []
var crosswalk_transforms: Array[Transform3D] = []
var player: CharacterBody3D
var car: CharacterBody3D
var bike: CharacterBody3D
var player_legs: Array[MeshInstance3D] = []
var player_arms: Array[MeshInstance3D] = []
var player_animation_clock := 0.0
var active_vehicle: CharacterBody3D
var active_vehicle_kind := "car"
var bike_button: Button
var camera: Camera3D
var pickup_marker: Node3D
var drop_marker: Node3D

var driving := false
var car_speed := 0.0
var camera_yaw := 0.0
var camera_distance := 8.5
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
var time_label: Label
var needs_label: Label
var clock_display_time := 0.0
var perf_label: Label
var toast_label: Label
var bank_panel: PanelContainer
var phone_panel: PanelContainer
var empire_panel: PanelContainer
var job_panel: PanelContainer
var map_panel: PanelContainer
var minimap_display: Control
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
    _build_home_property()
    _build_shop_interior()
    _build_player()
    _build_car()
    if GameState.bike_owned:
        _build_bike()
    _build_job_markers()
    job_stage = GameState.active_job_stage
    job_title = GameState.active_job_title
    job_reward_active = GameState.active_job_reward
    if job_stage > 0:
        pickup_marker.global_position = GameState.active_job_pickup_position
        drop_marker.global_position = GameState.active_job_destination_position
        pickup_marker.visible = job_stage == 1
        drop_marker.visible = job_stage == 2
    _build_hud()
    car.global_position = GameState.car_position
    car.rotation.y = GameState.car_rotation_y
    if is_instance_valid(bike):
        bike.global_position = GameState.bike_position
        bike.rotation.y = GameState.bike_rotation_y
    player.global_position = GameState.player_position
    if player.global_position.y < 0.8:
        player.global_position.y = 1.0
    if GameState.inside_home and GameState.home_owned:
        GameState.inside_shop = false
        home_interior.show()
        shop_interior.hide()
        GameState.was_driving = false
        player.global_position = GameState.player_position
        camera_distance = 5.5
    elif GameState.inside_shop and GameState.shop_owned:
        GameState.inside_home = false
        home_interior.hide()
        shop_interior.show()
        GameState.was_driving = false
        player.global_position = GameState.player_position
        camera_distance = 5.5
    else:
        GameState.inside_home = false
        GameState.inside_shop = false
        home_interior.hide()
        shop_interior.hide()
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
    game_environment = Environment.new()
    var environment := game_environment
    environment.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    sky.sky_material = ProceduralSkyMaterial.new()
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.72, 0.76, 0.82)
    environment.ambient_light_energy = 0.82
    environment.ambient_light_color = Color("#c5d0d8")
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    procedural_sky = sky.sky_material as ProceduralSkyMaterial
    procedural_sky.sky_top_color = Color("#5e8fb8")
    procedural_sky.sky_horizon_color = Color("#c7d7df")
    procedural_sky.ground_bottom_color = Color("#303c43")
    procedural_sky.ground_horizon_color = Color("#a2b1b6")
    world.environment = environment
    add_child(world)

    sun_light = DirectionalLight3D.new()
    sun_light.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
    sun_light.light_energy = 1.15
    # Real-time shadow maps are disproportionately expensive on entry-level phones.
    # Ambient/fill lighting keeps the scene readable without them.
    sun_light.shadow_enabled = false
    add_child(sun_light)
    _update_day_night()

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

func _build_home_property() -> void:
    var exterior := Node3D.new()
    exterior.name = "StarterHomeExterior"
    exterior.position = Vector3(100.0, 0.0, 104.0)
    add_child(exterior)
    _static_box(exterior, Vector3(0.4, 4.8, 10.0), Vector3(-6.0, 2.4, 0.0), mats["cream"], "HomeWestWall")
    _static_box(exterior, Vector3(0.4, 4.8, 10.0), Vector3(6.0, 2.4, 0.0), mats["cream"], "HomeEastWall")
    _static_box(exterior, Vector3(12.0, 4.8, 0.4), Vector3(0.0, 2.4, 5.0), mats["cream"], "HomeRearWall")
    _static_box(exterior, Vector3(4.8, 4.8, 0.4), Vector3(-3.6, 2.4, -5.0), mats["cream"], "HomeFrontLeft")
    _static_box(exterior, Vector3(4.8, 4.8, 0.4), Vector3(3.6, 2.4, -5.0), mats["cream"], "HomeFrontRight")
    _box_mesh(exterior, Vector3(13.2, 0.48, 11.2), Vector3(0.0, 4.95, 0.0), mats["brick"], "HomeRoof")
    _box_mesh(exterior, Vector3(4.0, 0.18, 2.4), Vector3(0.0, 0.12, -6.1), mats["sidewalk"], "HomePorch")
    _box_mesh(exterior, Vector3(1.6, 2.8, 0.14), Vector3(0.0, 1.48, -5.16), mats["dark"], "HomeDoor")
    _box_mesh(exterior, Vector3(0.18, 3.0, 0.18), Vector3(-0.95, 1.5, -5.1), mats["white"], "DoorFrameLeft")
    _box_mesh(exterior, Vector3(0.18, 3.0, 0.18), Vector3(0.95, 1.5, -5.1), mats["white"], "DoorFrameRight")
    _box_mesh(exterior, Vector3(0.12, 0.12, 0.1), Vector3(0.56, 1.45, -5.27), mats["yellow"], "DoorHandle")
    for window_x in [-4.0, 4.0]:
        _box_mesh(exterior, Vector3(1.4, 1.35, 0.12), Vector3(window_x, 2.7, -5.23), mats["glass"], "HomeFrontWindow")
        _box_mesh(exterior, Vector3(1.55, 0.12, 0.18), Vector3(window_x, 2.7, -5.3), mats["white"], "HomeWindowSill")
    home_sign = Label3D.new()
    home_sign.name = "HomeForSaleSign"
    home_sign.text = "STARTER HOME • ₹3,000"
    home_sign.font_size = 34
    home_sign.outline_size = 6
    home_sign.modulate = Color("#fff2d5")
    home_sign.position = Vector3(0.0, 4.1, -5.28)
    home_sign.pixel_size = 0.009
    exterior.add_child(home_sign)

    # The furnished room is a lightweight interior sector, hidden until entered.
    home_interior = Node3D.new()
    home_interior.name = "StarterHomeInterior"
    home_interior.position = Vector3(150.0, 0.0, 150.0)
    add_child(home_interior)
    _static_box(home_interior, Vector3(14.0, 0.18, 14.0), Vector3(0.0, -0.1, 0.0), mats["concrete"], "InteriorFloorCollision")
    _box_mesh(home_interior, Vector3(5.8, 3.8, 0.25), Vector3(-4.1, 1.8, -7.0), mats["cream"], "InteriorNorthLeft")
    _box_mesh(home_interior, Vector3(5.8, 3.8, 0.25), Vector3(4.1, 1.8, -7.0), mats["cream"], "InteriorNorthRight")
    _box_mesh(home_interior, Vector3(5.8, 3.8, 0.25), Vector3(-4.1, 1.8, 7.0), mats["cream"], "InteriorSouthLeft")
    _box_mesh(home_interior, Vector3(5.8, 3.8, 0.25), Vector3(4.1, 1.8, 7.0), mats["cream"], "InteriorSouthRight")
    _box_mesh(home_interior, Vector3(0.25, 3.8, 14.0), Vector3(-7.0, 1.8, 0.0), mats["cream"], "InteriorWestWall")
    _box_mesh(home_interior, Vector3(0.25, 3.8, 14.0), Vector3(7.0, 1.8, 0.0), mats["cream"], "InteriorEastWall")
    _box_mesh(home_interior, Vector3(1.4, 2.9, 0.12), Vector3(0.0, 1.45, -6.84), mats["dark"], "InteriorFrontDoor")
    _box_mesh(home_interior, Vector3(3.2, 0.28, 4.0), Vector3(-3.7, 0.48, -3.7), mats["brick"], "BedFrame")
    _box_mesh(home_interior, Vector3(3.0, 0.34, 3.8), Vector3(-3.7, 0.77, -3.7), mats["white"], "BedMattress")
    _box_mesh(home_interior, Vector3(1.0, 0.25, 1.0), Vector3(-4.25, 1.02, -5.0), mats["cream"], "BedPillow")
    _box_mesh(home_interior, Vector3(2.8, 0.8, 0.95), Vector3(3.8, 0.55, -4.8), mats["blue"], "InteriorSofa")
    _box_mesh(home_interior, Vector3(2.3, 0.38, 1.3), Vector3(0.8, 0.32, 0.3), mats["brick"], "CoffeeTable")
    _box_mesh(home_interior, Vector3(3.8, 0.95, 0.85), Vector3(4.65, 0.8, 4.5), mats["cream"], "KitchenCounter")
    _box_mesh(home_interior, Vector3(1.1, 0.08, 0.6), Vector3(4.65, 1.34, 4.5), mats["dark"], "KitchenCooktop")
    _box_mesh(home_interior, Vector3(0.7, 1.8, 0.7), Vector3(-5.5, 0.9, 3.8), mats["brick"], "Wardrobe")
    _box_mesh(home_interior, Vector3(0.12, 1.3, 3.0), Vector3(6.82, 2.25, 0.0), mats["glass"], "InteriorWindow")
    var interior_light := StandardMaterial3D.new()
    interior_light.albedo_color = Color("#f1d7a2")
    interior_light.emission_enabled = true
    interior_light.emission = Color("#f1d7a2")
    interior_light.emission_energy_multiplier = 0.55
    _box_mesh(home_interior, Vector3(1.1, 0.12, 1.1), Vector3(0.0, 3.35, 0.0), interior_light, "CeilingLight")
    home_interior.hide()

func _enter_home() -> void:
    if driving:
        _show_toast("Exit your vehicle before entering your home.")
        return
    if not GameState.home_owned:
        _show_toast("Purchase the starter home from the Empire menu first.")
        return
    if player.global_position.distance_to(HOME_DOOR_POSITION) > 6.0:
        _show_toast("Go to your starter home's front door to enter.")
        return
    GameState.home_return_position = player.global_position
    GameState.inside_home = true
    GameState.was_driving = false
    driving = false
    active_vehicle = null
    car_speed = 0.0
    home_interior.show()
    player.global_position = HOME_INTERIOR_POSITION
    player.rotation.y = 0.0
    player.velocity = Vector3.ZERO
    camera_yaw = 0.0
    camera_distance = 5.5
    GameState.set_player_position(player.global_position)
    GameState.save_game()
    _refresh_ui()
    _show_toast("Welcome home. You can rest here to advance the day.")

func _exit_home() -> void:
    if not GameState.inside_home:
        return
    home_interior.hide()
    GameState.inside_home = false
    player.global_position = GameState.home_return_position
    player.velocity = Vector3.ZERO
    camera_yaw = 0.0
    camera_distance = 8.5
    GameState.set_player_position(player.global_position)
    GameState.save_game()
    _refresh_ui()
    _show_toast("You left your home.")

func _home_action() -> void:
    if GameState.inside_home:
        _exit_home()
    else:
        _enter_home()

func _build_shop_interior() -> void:
    shop_interior = Node3D.new()
    shop_interior.name = "OwnedShopInterior"
    shop_interior.position = Vector3(180.0, 0.0, 150.0)
    add_child(shop_interior)
    _static_box(shop_interior, Vector3(14.0, 0.18, 14.0), Vector3(0.0, -0.1, 0.0), mats["concrete"], "ShopFloorCollision")
    _box_mesh(shop_interior, Vector3(5.8, 3.8, 0.25), Vector3(-4.1, 1.8, -7.0), mats["cream"], "ShopNorthLeft")
    _box_mesh(shop_interior, Vector3(5.8, 3.8, 0.25), Vector3(4.1, 1.8, -7.0), mats["cream"], "ShopNorthRight")
    _box_mesh(shop_interior, Vector3(14.0, 3.8, 0.25), Vector3(0.0, 1.8, 7.0), mats["cream"], "ShopSouthWall")
    _box_mesh(shop_interior, Vector3(0.25, 3.8, 14.0), Vector3(-7.0, 1.8, 0.0), mats["cream"], "ShopWestWall")
    _box_mesh(shop_interior, Vector3(0.25, 3.8, 14.0), Vector3(7.0, 1.8, 0.0), mats["cream"], "ShopEastWall")
    _box_mesh(shop_interior, Vector3(1.4, 2.9, 0.12), Vector3(0.0, 1.45, -6.84), mats["dark"], "ShopFrontDoor")
    # Sales counter and cash register face the entrance.
    _box_mesh(shop_interior, Vector3(5.6, 0.95, 1.0), Vector3(0.0, 0.78, -3.8), mats["brick"], "ShopCounter")
    _box_mesh(shop_interior, Vector3(0.65, 0.42, 0.5), Vector3(-1.7, 1.45, -3.8), mats["dark"], "CashRegister")
    # Merchandise shelves on both walls; stock is represented by compact product blocks.
    for shelf_x in [-5.2, 5.2]:
        for shelf_z in [-3.0, 0.0, 3.0]:
            _box_mesh(shop_interior, Vector3(0.65, 2.4, 2.4), Vector3(shelf_x, 1.2, shelf_z), mats["dark"], "ShopShelf")
            for row in range(3):
                for column in range(2):
                    var product_color: Material = mats["yellow"] if (row + column) % 2 == 0 else mats["red"]
                    _box_mesh(shop_interior, Vector3(0.42, 0.42, 0.48), Vector3(shelf_x - signf(shelf_x) * 0.38, 0.48 + float(row) * 0.68, shelf_z - 0.55 + float(column) * 0.95), product_color, "ShelfProduct")
    _box_mesh(shop_interior, Vector3(1.2, 2.0, 1.1), Vector3(3.9, 1.0, -5.4), mats["blue"], "DrinksFridge")
    _box_mesh(shop_interior, Vector3(3.0, 0.12, 2.2), Vector3(0.0, 0.12, 2.8), mats["cream"], "ShopDisplayTable")
    var shop_light := StandardMaterial3D.new()
    shop_light.albedo_color = Color("#f4dfa9")
    shop_light.emission_enabled = true
    shop_light.emission = Color("#f4dfa9")
    shop_light.emission_energy_multiplier = 0.45
    _box_mesh(shop_interior, Vector3(1.1, 0.12, 1.1), Vector3(0.0, 3.35, 0.0), shop_light, "ShopCeilingLight")
    shop_interior.hide()

func _enter_shop() -> void:
    if driving:
        _show_toast("Exit your vehicle before entering the shop.")
        return
    if not GameState.shop_owned:
        _show_toast("Purchase the corner shop from the Empire menu first.")
        return
    if player.global_position.distance_to(SHOP_DOOR_POSITION) > 6.0:
        _show_toast("Go to your shop's front entrance to enter.")
        return
    GameState.shop_return_position = player.global_position
    GameState.inside_shop = true
    GameState.inside_home = false
    GameState.was_driving = false
    driving = false
    active_vehicle = null
    car_speed = 0.0
    shop_interior.show()
    home_interior.hide()
    player.global_position = SHOP_INTERIOR_POSITION
    player.rotation.y = 0.0
    player.velocity = Vector3.ZERO
    camera_yaw = 0.0
    camera_distance = 5.5
    GameState.set_player_position(player.global_position)
    GameState.save_game()
    _refresh_ui()
    _show_toast("Welcome to your shop. Restock inventory and manage daily sales here.")

func _exit_shop() -> void:
    if not GameState.inside_shop:
        return
    shop_interior.hide()
    GameState.inside_shop = false
    player.global_position = GameState.shop_return_position
    player.velocity = Vector3.ZERO
    camera_yaw = 0.0
    camera_distance = 8.5
    GameState.set_player_position(player.global_position)
    GameState.save_game()
    _refresh_ui()
    _show_toast("You left your shop.")

func _shop_action() -> void:
    if GameState.inside_shop:
        _exit_shop()
    else:
        _enter_shop()

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
            # Embed facade glazing slightly into the wall so it never appears to float.
            window_transforms.append(Transform3D(Basis.IDENTITY, center + Vector3(wx, wy, -size.z * 0.5 - 0.045)))
            window_transforms.append(Transform3D(Basis.IDENTITY, center + Vector3(wx, wy, size.z * 0.5 + 0.045)))
            var wz := (float(column) - 1.0) * size.z * 0.29
            var side_basis := Basis(Vector3.UP, PI * 0.5)
            window_transforms.append(Transform3D(side_basis, center + Vector3(-size.x * 0.5 - 0.045, wy, wz)))
            window_transforms.append(Transform3D(side_basis, center + Vector3(size.x * 0.5 + 0.045, wy, wz)))
        if row > 0:
            var trim_y := -size.y * 0.5 + 1.0 + float(row) * 3.2
            trim_transforms.append(Transform3D(Basis.IDENTITY, center + Vector3(0.0, trim_y, -size.z * 0.5 - 0.02)))
            trim_transforms.append(Transform3D(Basis.IDENTITY, center + Vector3(0.0, trim_y, size.z * 0.5 + 0.02)))
            trim_transforms.append(Transform3D(Basis(Vector3.UP, PI * 0.5), center + Vector3(-size.x * 0.5 - 0.02, trim_y, 0.0)))
            trim_transforms.append(Transform3D(Basis(Vector3.UP, PI * 0.5), center + Vector3(size.x * 0.5 + 0.02, trim_y, 0.0)))
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
    _box_mesh(parent, Vector3(4.5, 0.72, 0.24), Vector3(0.0, -size.y * 0.5 + 1.65, -size.z * 0.5 - 0.08), sign_color, "ShopCanopy")
    _box_mesh(parent, Vector3(2.7, 1.7, 0.10), Vector3(0.0, -size.y * 0.5 + 0.75, -size.z * 0.5 - 0.045), mats["glass"], "ShopfrontWindow")
    var sign := Label3D.new()
    var names := ["MARKET", "TEA HOUSE", "MOBILE HUB", "GROCERY"]
    sign.text = names[(index / 4) % names.size()]
    sign.font_size = 28
    sign.outline_size = 5
    sign.modulate = Color("#fff4d8")
    sign.position = Vector3(0.0, -size.y * 0.5 + 1.75, -size.z * 0.5 - 0.13)
    sign.pixel_size = 0.012
    if index == 4:
        shop_sign = sign
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
        var leg := _add_capsule_piece(player, 0.13, 0.78, Vector3(side * 0.15, -0.63, 0.0), mats["dark"], "Leg")
        player_legs.append(leg)
        _box_mesh(player, Vector3(0.22, 0.13, 0.36), Vector3(side * 0.15, -1.01, -0.05), mats["dark"], "Shoe")
        var arm := _add_capsule_piece(player, 0.105, 0.72, Vector3(side * 0.36, 0.22, 0.0), mats["player"], "Arm")
        arm.rotation.z = side * -0.12
        player_arms.append(arm)

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
    time_label = Label.new()
    time_label.add_theme_font_size_override("font_size", 15)
    time_label.modulate = Color("#f0dca8")
    status_box.add_child(time_label)
    needs_label = Label.new()
    needs_label.add_theme_font_size_override("font_size", 14)
    needs_label.modulate = Color("#d8e1d4")
    status_box.add_child(needs_label)
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
    _add_button(top_buttons, "MAP", _toggle_map)
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
    var map_size := map_panel.get_combined_minimum_size()
    bank_panel.position = (view_size - bank_size) * 0.5
    phone_panel.position = (view_size - phone_size) * 0.5
    map_panel.position = (view_size - map_size) * 0.5
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
    _add_button(action_box, "HOME / EXIT", _home_action, 112.0)
    _add_button(action_box, "SHOP / EXIT", _shop_action, 112.0)
    _add_button(action_box, "EXIT CAR", _exit_car, 112.0)

func _set_move_x(value: float) -> void:
    move_touch.x = value

func _set_move_y(value: float) -> void:
    move_touch.y = value

func _build_panels() -> void:
    bank_panel = PanelContainer.new()
    bank_panel.position = Vector2(430.0, 150.0)
    bank_panel.custom_minimum_size = Vector2(460.0, 480.0)
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
    _add_button(bank_box, "TAKE LOAN ₹2,000", _take_loan, 200.0)
    _add_button(bank_box, "REPAY LOAN ₹500", _repay_loan, 200.0)
    _add_button(bank_box, "CLOSE", _hide_panels, 120.0)
    bank_panel.hide()

    phone_panel = PanelContainer.new()
    phone_panel.position = Vector2(430.0, 120.0)
    phone_panel.custom_minimum_size = Vector2(460.0, 520.0)
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
    _add_button(phone_box, "BUY MEAL • ₹100", _buy_meal, 180.0)
    _add_button(phone_box, "REFUEL VEHICLE • ₹300", _refuel_vehicle, 180.0)
    _add_button(phone_box, "RESET CAMERA", _reset_camera, 180.0)
    _add_button(phone_box, "JOB BOARD", _job_action, 180.0)
    _add_button(phone_box, "MY EMPIRE", _toggle_empire, 180.0)
    _add_button(phone_box, "CLOSE PHONE", _hide_panels, 180.0)
    phone_panel.hide()

    map_panel = PanelContainer.new()
    map_panel.custom_minimum_size = Vector2(390.0, 330.0)
    map_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.08, 0.12, 0.98)))
    hud_layer.add_child(map_panel)
    var map_box := VBoxContainer.new()
    map_box.add_theme_constant_override("separation", 6)
    map_panel.add_child(map_box)
    _add_title(map_box, "NAVAPURA CITY MAP")
    minimap_display = Control.new()
    minimap_display.custom_minimum_size = Vector2(360.0, 270.0)
    minimap_display.set_script(MINIMAP_SCRIPT)
    map_box.add_child(minimap_display)
    _add_button(map_box, "CLOSE MAP", _hide_panels, 140.0)
    map_panel.hide()

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
    empire_panel.custom_minimum_size = Vector2(500.0, 560.0)
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
    _add_button(empire_box, "ENTER / EXIT HOME", _home_action, 280.0)
    _add_button(empire_box, "ENTER / EXIT SHOP", _shop_action, 280.0)
    bike_button = _add_button(empire_box, "BUY MOTORBIKE • ₹2,500", _buy_bike, 280.0)
    _add_button(empire_box, "BUY CORNER SHOP • ₹4,000", _buy_shop, 280.0)
    _add_button(empire_box, "RESTOCK SHOP • ₹300", _restock_shop, 280.0)
    _add_button(empire_box, "HIRE SHOP EMPLOYEE • ₹500", _hire_shop_employee, 280.0)
    _add_button(empire_box, "COLLECT SHOP INCOME", _collect_shop, 280.0)
    _add_button(empire_box, "SLEEP AT HOME", _next_day, 280.0)
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
    GameState.advance_clock(delta)
    _update_day_night()
    clock_display_time += delta
    if clock_display_time >= 1.0:
        if is_instance_valid(time_label):
            time_label.text = "DAY %d  •  %s" % [GameState.day_number, GameState.clock_text()]
        clock_display_time = 0.0
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
    if is_instance_valid(map_panel) and map_panel.visible:
        _update_minimap()
    if toast_time > 0.0:
        toast_time -= delta
        if toast_time <= 0.0 and is_instance_valid(toast_label):
            toast_label.text = ""

func _update_day_night() -> void:
    if not is_instance_valid(sun_light) or not is_instance_valid(game_environment) or not is_instance_valid(procedural_sky):
        return
    # The simulation runs at one in-game minute per real second: a full day
    # takes 24 real minutes. Lighting and sky colours blend continuously.
    var phase := GameState.game_minutes / 1440.0
    var solar_angle := (phase - 0.25) * TAU
    var daylight := clampf((sin(solar_angle) + 0.18) / 1.05, 0.035, 1.0)
    var warm_horizon := Color("#e5a06d")
    var day_horizon := Color("#c7d7df")
    var night_horizon := Color("#202b43")
    var dusk_mix := clampf(1.0 - absf(GameState.game_minutes - 1080.0) / 240.0, 0.0, 1.0)
    var dawn_mix := clampf(1.0 - absf(GameState.game_minutes - 360.0) / 240.0, 0.0, 1.0)
    var horizon := night_horizon.lerp(day_horizon, daylight).lerp(warm_horizon, maxf(dusk_mix, dawn_mix) * 0.45)
    var sky_top := Color("#0d1730").lerp(Color("#5e8fb8"), daylight)
    procedural_sky.sky_top_color = sky_top
    procedural_sky.sky_horizon_color = horizon
    procedural_sky.ground_horizon_color = night_horizon.lerp(Color("#a2b1b6"), daylight)
    game_environment.ambient_light_color = Color("#253149").lerp(Color("#c5d0d8"), daylight)
    game_environment.ambient_light_energy = lerpf(0.22, 0.82, daylight)
    sun_light.light_energy = lerpf(0.04, 1.15, daylight)
    sun_light.rotation_degrees.x = lerpf(18.0, -58.0, daylight)
    sun_light.rotation_degrees.y = -32.0 + sin(phase * TAU) * 22.0

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
    # Walk relative to the orbiting follow camera, matching standard third-person controls.
    var direction := Vector3(input_axis.x, 0.0, input_axis.y).rotated(Vector3.UP, camera_yaw)
    var speed := RUN_SPEED if (run_touch or Input.is_action_pressed("run")) else WALK_SPEED
    if direction.length_squared() > 0.001:
        direction = direction.normalized()
        var energy_factor := 0.72 if GameState.energy_percent < 18.0 else 1.0
        var hunger_factor := 0.82 if GameState.hunger_percent < 12.0 else 1.0
        speed *= energy_factor * hunger_factor
        GameState.consume_energy(delta * (0.022 if (run_touch or Input.is_action_pressed("run")) else 0.009))
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
    if GameState.inside_home:
        player.global_position.x = clampf(player.global_position.x, 143.4, 156.6)
        player.global_position.z = clampf(player.global_position.z, 143.4, 156.6)
    elif GameState.inside_shop:
        player.global_position.x = clampf(player.global_position.x, 173.4, 186.6)
        player.global_position.z = clampf(player.global_position.z, 143.4, 156.6)
    _animate_player(delta, input_axis.length() > 0.05, speed)
    GameState.set_player_position(player.global_position)

func _animate_player(delta: float, moving: bool, move_speed: float) -> void:
    if player_legs.size() < 2 or player_arms.size() < 2:
        return
    if moving:
        player_animation_clock += delta * (11.5 if move_speed > WALK_SPEED + 0.5 else 8.0)
    var swing := sin(player_animation_clock) * (0.48 if moving else 0.0)
    var target_leg_left := swing
    var target_leg_right := -swing
    var target_arm_left := -swing * 0.72
    var target_arm_right := swing * 0.72
    var blend := clampf(delta * (12.0 if moving else 8.0), 0.0, 1.0)
    player_legs[0].rotation.x = lerpf(player_legs[0].rotation.x, target_leg_left, blend)
    player_legs[1].rotation.x = lerpf(player_legs[1].rotation.x, target_leg_right, blend)
    player_arms[0].rotation.x = lerpf(player_arms[0].rotation.x, target_arm_left, blend)
    player_arms[1].rotation.x = lerpf(player_arms[1].rotation.x, target_arm_right, blend)

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
        GameState.consume_energy(delta * 0.0025)
        _update_fuel_hud()

func _update_camera(delta: float) -> void:
    var focus := active_vehicle.global_position if driving and is_instance_valid(active_vehicle) else player.global_position
    var inside_building := GameState.inside_home or GameState.inside_shop
    var offset := Vector3(0.0, 2.35 if inside_building else 5.0, camera_distance).rotated(Vector3.UP, camera_yaw)
    var desired := focus + offset
    if GameState.inside_home:
        desired.x = clampf(desired.x, 143.5, 156.5)
        desired.y = clampf(desired.y, 0.8, 3.55)
        desired.z = clampf(desired.z, 143.5, 156.5)
    elif GameState.inside_shop:
        desired.x = clampf(desired.x, 173.5, 186.5)
        desired.y = clampf(desired.y, 0.8, 3.55)
        desired.z = clampf(desired.z, 143.5, 156.5)
    camera.global_position = camera.global_position.lerp(desired, clampf(delta * 5.0, 0.0, 1.0))
    camera.look_at(focus + Vector3(0.0, 1.0, 0.0), Vector3.UP)

func _reset_camera() -> void:
    camera_yaw = 0.0
    camera_distance = 8.5
    _show_toast("Camera reset.")

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenDrag:
        camera_yaw -= event.relative.x * 0.004
        camera_distance = clampf(camera_distance + event.relative.y * 0.018, 6.0, 13.0)
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        camera_yaw -= event.relative.x * 0.004
        camera_distance = clampf(camera_distance + event.relative.y * 0.018, 6.0, 13.0)

func _update_job_progress() -> void:
    if job_stage == 0:
        return
    var target := pickup_marker.global_position if job_stage == 1 else drop_marker.global_position
    # Missions can be completed on foot, in the starter car, or on the owned bike.
    var actor := active_vehicle.global_position if driving and is_instance_valid(active_vehicle) else player.global_position
    if actor.distance_to(target) < 5.0:
        if job_stage == 1:
            job_stage = 2
            GameState.active_job_stage = 2
            GameState.save_game()
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
            GameState.active_job_stage = 0
            GameState.active_job_title = ""
            GameState.active_job_reward = 0
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
    GameState.active_job_stage = 1
    GameState.active_job_title = title
    GameState.active_job_reward = reward
    GameState.active_job_pickup_position = pickup_position
    GameState.active_job_destination_position = destination_position
    GameState.save_game()
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
    GameState.active_job_stage = 0
    GameState.active_job_title = ""
    GameState.active_job_reward = 0
    GameState.save_game()
    pickup_marker.hide()
    drop_marker.hide()
    _hide_panels()
    _show_toast("Job cancelled. No reward was paid.")
    _refresh_ui()

func _interact() -> void:
    if GameState.inside_home:
        _exit_home()
        return
    if GameState.inside_shop:
        _exit_shop()
        return
    if driving:
        _exit_car()
        return
    if GameState.home_owned and player.global_position.distance_to(HOME_DOOR_POSITION) <= 5.5:
        _enter_home()
        return
    if GameState.shop_owned and player.global_position.distance_to(SHOP_DOOR_POSITION) <= 5.5:
        _enter_shop()
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

func _toggle_map() -> void:
    var should_open := not map_panel.visible
    _hide_panels()
    map_panel.visible = should_open
    _update_minimap()

func _take_loan() -> void:
    if GameState.take_loan(2000):
        _refresh_ui()

func _repay_loan() -> void:
    if GameState.repay_loan(500):
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
    map_panel.hide()
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

func _restock_shop() -> void:
    if GameState.restock_shop():
        _refresh_ui()

func _hire_shop_employee() -> void:
    if GameState.hire_shop_employee():
        _refresh_ui()

func _collect_shop() -> void:
    GameState.collect_shop_income()

func _buy_meal() -> void:
    if GameState.buy_meal():
        _refresh_ui()

func _next_day() -> void:
    if not GameState.inside_home:
        _show_toast("You must enter your home before sleeping.")
        return
    if GameState.sleep_at_home():
        _refresh_ui()

func _sync_save_state() -> void:
    if is_instance_valid(player):
        GameState.set_player_position(player.global_position)
    if driving and is_instance_valid(active_vehicle):
        GameState.set_vehicle_state(active_vehicle_kind, active_vehicle.global_position, active_vehicle.rotation.y, true)
    else:
        GameState.was_driving = false
    if GameState.inside_home and not GameState.home_owned:
        GameState.inside_home = false
    if GameState.inside_shop and not GameState.shop_owned:
        GameState.inside_shop = false

func _save_now() -> void:
    _sync_save_state()
    GameState.save_game()
    _show_toast("Game saved on this device.")

func _refresh_ui() -> void:
    if not is_instance_valid(wallet_label):
        return
    wallet_label.text = "WALLET  ₹%d     BANK  ₹%d" % [GameState.wallet, GameState.bank_balance]
    if is_instance_valid(time_label):
        time_label.text = "DAY %d  •  %s" % [GameState.day_number, GameState.clock_text()]
    if is_instance_valid(needs_label):
        needs_label.text = "HUNGER %d%%  •  ENERGY %d%%" % [int(round(GameState.hunger_percent)), int(round(GameState.energy_percent))]
        needs_label.modulate = Color("#e28b78") if GameState.hunger_percent < 20.0 or GameState.energy_percent < 20.0 else Color("#d8e1d4")
    _update_fuel_hud()
    if is_instance_valid(map_panel) and map_panel.visible:
        _update_minimap()
    var travel_state := "HOME INTERIOR" if GameState.inside_home else ("SHOP INTERIOR" if GameState.inside_shop else ("DRIVING %s" % active_vehicle_kind.to_upper() if driving else "ON FOOT"))
    location_label.text = "%s  •  NET WORTH ₹%d" % [travel_state, GameState.net_worth()]
    if is_instance_valid(home_sign):
        home_sign.text = "YOUR STARTER HOME" if GameState.home_owned else "STARTER HOME • ₹3,000"
    if is_instance_valid(shop_sign):
        shop_sign.text = "YOUR TEA HOUSE" if GameState.shop_owned else "TEA HOUSE • FOR SALE"
    if is_instance_valid(bank_info):
        var recent := ""
        for i in range(mini(GameState.transactions.size(), 5)):
            recent += "• %s\n" % GameState.transactions[i]
        bank_info.text = "Wallet: ₹%d\nBank: ₹%d\nOutstanding loan: ₹%d\nDaily interest: 2%%\nNet worth: ₹%d\n\nRECENT TRANSACTIONS\n%s" % [GameState.wallet, GameState.bank_balance, GameState.loan_balance, GameState.net_worth(), recent]
    if is_instance_valid(phone_info):
        phone_info.text = "Day %d  •  %s\nWallet ₹%d  •  Bank ₹%d\nLoan: ₹%d\nFuel: %d%%  •  Hunger: %d%%\nEnergy: %d%%  •  Jobs completed: %d\nBuy meals to restore hunger. Sleep at your home to restore energy." % [GameState.day_number, GameState.clock_text(), GameState.wallet, GameState.bank_balance, GameState.loan_balance, int(round(GameState.fuel_percent)), int(round(GameState.hunger_percent)), int(round(GameState.energy_percent)), GameState.missions_completed]
    if is_instance_valid(job_info):
        if job_stage == 0:
            job_info.text = "Choose a job. Complete the pickup and reach the destination to earn your reward.\nCompleted jobs: %d" % GameState.missions_completed
        else:
            job_info.text = "ACTIVE: %s\nReward: ₹%d\nStep: %s" % [job_title, job_reward_active, "Go to pickup" if job_stage == 1 else "Deliver to destination"]
    if is_instance_valid(bike_button):
        bike_button.text = "MOTORBIKE OWNED • ₹2,500 VALUE" if GameState.bike_owned else "BUY MOTORBIKE • ₹2,500"
    if is_instance_valid(empire_info):
        empire_info.text = "Day %d\nWallet: ₹%d  |  Bank: ₹%d\nHome: %s\nCorner shop: %s\nShop employees: %d / 3\nShop stock: %d units\nDaily shop income: ₹%d\nMotorbike: %s\nUncollected income: ₹%d\nLifetime earnings: ₹%d\nLoan outstanding: ₹%d\nNet worth: ₹%d" % [
            GameState.day_number,
            GameState.wallet,
            GameState.bank_balance,
            "Owned" if GameState.home_owned else "Not owned",
            "Owned" if GameState.shop_owned else "Not owned",
            GameState.shop_employee_count,
            GameState.shop_stock_units,
            mini(GameState.shop_stock_units, 5 + GameState.shop_employee_count * 2) * 50 if GameState.shop_owned else 0,
            "Owned" if GameState.bike_owned else "Not owned",
            GameState.uncollected_shop_income,
            GameState.lifetime_earnings,
            GameState.loan_balance,
            GameState.net_worth()
        ]

func _update_minimap() -> void:
    if not is_instance_valid(minimap_display) or not is_instance_valid(player):
        return
    var map_player_position: Vector3 = HOME_DOOR_POSITION if GameState.inside_home else (SHOP_DOOR_POSITION if GameState.inside_shop else player.global_position)
    minimap_display.set("player_position", map_player_position)
    minimap_display.set("home_position", HOME_DOOR_POSITION)
    minimap_display.set("has_home", true)
    minimap_display.set("shop_position", SHOP_DOOR_POSITION)
    minimap_display.set("has_shop", GameState.shop_owned)
    var shown_vehicle: Node3D = active_vehicle if driving and is_instance_valid(active_vehicle) else car
    if is_instance_valid(shown_vehicle):
        minimap_display.set("vehicle_position", shown_vehicle.global_position)
        minimap_display.set("has_vehicle", true)
    else:
        minimap_display.set("has_vehicle", false)
    if is_instance_valid(pickup_marker):
        minimap_display.set("pickup_position", pickup_marker.global_position)
    if is_instance_valid(drop_marker):
        minimap_display.set("destination_position", drop_marker.global_position)
    minimap_display.set("job_stage", job_stage)

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
