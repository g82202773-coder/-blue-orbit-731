extends Node3D

const CITY_EXTENT := 220.0
const WALK_SPEED := 4.6
const RUN_SPEED := 7.2
const CAR_FORWARD_SPEED := 17.0
const CAR_REVERSE_SPEED := 6.0
const JOB_REWARD := 750

var mats: Dictionary = {}
var player: CharacterBody3D
var car: CharacterBody3D
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
var toast_time := 0.0

var hud_layer: CanvasLayer
var wallet_label: Label
var location_label: Label
var toast_label: Label
var bank_panel: PanelContainer
var phone_panel: PanelContainer
var empire_panel: PanelContainer
var bank_info: Label
var phone_info: Label
var empire_info: Label

func _ready() -> void:
    GameState.state_changed.connect(_refresh_ui)
    GameState.toast_requested.connect(_show_toast)
    _create_materials()
    _build_environment()
    _build_city()
    _build_player()
    _build_car()
    _build_job_markers()
    _build_hud()
    player.global_position = GameState.player_position
    if player.global_position.y < 0.8:
        player.global_position.y = 1.0
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
    environment.ambient_light_energy = 0.72
    world.environment = environment
    add_child(world)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
    sun.light_energy = 1.05
    sun.shadow_enabled = true
    add_child(sun)

    _static_box(self, Vector3(CITY_EXTENT, 0.5, CITY_EXTENT), Vector3(0.0, -0.3, 0.0), mats["grass"], "Ground")

func _build_city() -> void:
    # A compact, connected street grid for the first playable city sector.
    for lane in [-80.0, -40.0, 0.0, 40.0, 80.0]:
        _box_mesh(self, Vector3(CITY_EXTENT, 0.12, 12.0), Vector3(0.0, 0.0, lane), mats["asphalt"], "EastWestRoad")
        _box_mesh(self, Vector3(12.0, 0.12, CITY_EXTENT), Vector3(lane, 0.01, 0.0), mats["asphalt"], "NorthSouthRoad")
        _box_mesh(self, Vector3(CITY_EXTENT, 0.035, 0.13), Vector3(0.0, 0.085, lane), mats["road_line"], "RoadCenterLine")
        _box_mesh(self, Vector3(0.13, 0.035, CITY_EXTENT), Vector3(lane, 0.095, 0.0), mats["road_line"], "RoadCenterLine")

    # Sidewalk strips around the main blocks.
    for z in [-73.0, -47.0, -33.0, -7.0, 7.0, 33.0, 47.0, 73.0]:
        _box_mesh(self, Vector3(CITY_EXTENT, 0.18, 2.2), Vector3(0.0, 0.02, z), mats["sidewalk"], "Sidewalk")
    for x in [-73.0, -47.0, -33.0, -7.0, 7.0, 33.0, 47.0, 73.0]:
        _box_mesh(self, Vector3(2.2, 0.18, CITY_EXTENT), Vector3(x, 0.02, 0.0), mats["sidewalk"], "Sidewalk")

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

    _build_street_sign(Vector3(0.0, 0.0, -3.0), "NAVAPURA")

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

    # A restrained set of repeated windows keeps draw calls and geometry modest.
    var window_rows := int(size.y / 3.1)
    for row in range(mini(window_rows, 4)):
        for column in range(3):
            var wx := (float(column) - 1.0) * size.x * 0.27
            var wy := -size.y * 0.5 + 2.0 + float(row) * 2.8
            _box_mesh(body, Vector3(1.5, 1.0, 0.08), Vector3(wx, wy, -size.z * 0.5 - 0.045), mats["glass"], "Window")
    if index % 4 == 0:
        _box_mesh(body, Vector3(4.0, 1.0, 0.16), Vector3(0.0, -size.y * 0.5 + 1.1, -size.z * 0.5 - 0.09), mats["red"], "ShopSign")

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
    player.position = Vector3(0.0, 1.0, 12.0)
    player.floor_snap_length = 0.25

    var collider := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.38
    capsule.height = 1.8
    collider.shape = capsule
    player.add_child(collider)

    var body := MeshInstance3D.new()
    var capsule_mesh := CapsuleMesh.new()
    capsule_mesh.radius = 0.38
    capsule_mesh.height = 1.8
    body.mesh = capsule_mesh
    body.material_override = mats["player"]
    player.add_child(body)

    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.23
    head_mesh.height = 0.46
    head.mesh = head_mesh
    head.position = Vector3(0.0, 0.93, 0.0)
    head.material_override = mats["skin"]
    player.add_child(head)
    add_child(player)

    camera = Camera3D.new()
    camera.name = "FollowCamera"
    camera.position = player.global_position + Vector3(0.0, 5.0, 8.5)
    camera.current = true
    add_child(camera)
    camera.look_at(player.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)

func _build_car() -> void:
    car = CharacterBody3D.new()
    car.name = "StarterCar"
    car.position = Vector3(4.0, 0.72, 12.0)
    car.floor_snap_length = 0.25

    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(2.1, 1.0, 4.0)
    collider.shape = shape
    car.add_child(collider)

    _box_mesh(car, Vector3(2.0, 0.72, 3.8), Vector3(0.0, 0.0, 0.0), mats["car"], "CarBody")
    _box_mesh(car, Vector3(1.55, 0.7, 1.85), Vector3(0.0, 0.65, -0.15), mats["glass"], "Cabin")
    for x in [-0.94, 0.94]:
        for z in [-1.25, 1.25]:
            var wheel := MeshInstance3D.new()
            var wheel_mesh := CylinderMesh.new()
            wheel_mesh.top_radius = 0.36
            wheel_mesh.bottom_radius = 0.36
            wheel_mesh.height = 0.24
            wheel.mesh = wheel_mesh
            wheel.rotation_degrees.z = 90.0
            wheel.position = Vector3(x, -0.28, z)
            wheel.material_override = mats["dark"]
            car.add_child(wheel)
    add_child(car)

func _build_job_markers() -> void:
    pickup_marker = _make_marker(mats["yellow"])
    pickup_marker.position = Vector3(0.0, 0.85, -28.0)
    drop_marker = _make_marker(mats["green"])
    drop_marker.position = Vector3(0.0, 0.85, 12.0)
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

    var status := PanelContainer.new()
    status.position = Vector2(18.0, 16.0)
    status.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.07, 0.10, 0.88)))
    hud_layer.add_child(status)
    var status_box := VBoxContainer.new()
    status.add_child(status_box)
    wallet_label = Label.new()
    wallet_label.add_theme_font_size_override("font_size", 21)
    status_box.add_child(wallet_label)
    location_label = Label.new()
    location_label.text = "NAVAPURA • ON FOOT"
    status_box.add_child(location_label)

    var top_buttons := HBoxContainer.new()
    top_buttons.position = Vector2(410.0, 18.0)
    top_buttons.add_theme_constant_override("separation", 8)
    hud_layer.add_child(top_buttons)
    _add_button(top_buttons, "PHONE", _toggle_phone)
    _add_button(top_buttons, "BANK", _toggle_bank)
    _add_button(top_buttons, "JOB", _job_action)
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
    var left_pad := PanelContainer.new()
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

    var right_pad := PanelContainer.new()
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
    _add_button(phone_box, "DELIVERY JOB", _job_action, 180.0)
    _add_button(phone_box, "MY EMPIRE", _toggle_empire, 180.0)
    _add_button(phone_box, "CLOSE PHONE", _hide_panels, 180.0)
    phone_panel.hide()

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
    var keyboard_throttle := float(Input.is_action_pressed("move_forward")) - float(Input.is_action_pressed("move_back"))
    var throttle := throttle_touch if absf(throttle_touch) > 0.01 else keyboard_throttle
    if throttle > 0.0:
        car_speed = move_toward(car_speed, CAR_FORWARD_SPEED, 12.0 * delta)
    elif throttle < 0.0:
        if car_speed > 1.0:
            car_speed = move_toward(car_speed, 0.0, 22.0 * delta)
        else:
            car_speed = move_toward(car_speed, -CAR_REVERSE_SPEED, 8.0 * delta)
    else:
        car_speed = move_toward(car_speed, 0.0, 4.0 * delta)

    var keyboard_steer := float(Input.is_action_pressed("move_right")) - float(Input.is_action_pressed("move_left"))
    var steer := steer_touch if absf(steer_touch) > 0.01 else keyboard_steer
    if absf(car_speed) > 0.25:
        car.rotate_y(-steer * delta * 1.15 * clampf(absf(car_speed) / 5.0, 0.2, 1.0) * signf(car_speed))
    var forward := -car.global_basis.z
    car.velocity.x = forward.x * car_speed
    car.velocity.z = forward.z * car_speed
    if not car.is_on_floor():
        car.velocity.y -= 9.8 * delta
    else:
        car.velocity.y = -0.5
    car.move_and_slide()
    player.global_position = car.global_position + Vector3(0.0, 0.1, 0.0)
    GameState.set_player_position(player.global_position)

func _update_camera(delta: float) -> void:
    var focus := car.global_position if driving else player.global_position
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
            _show_toast("Package collected! Deliver it to the job office.")
        else:
            job_stage = 0
            drop_marker.hide()
            GameState.earn(JOB_REWARD, "Delivery completed")
            _show_toast("Delivery completed. Reward: ₹%d" % JOB_REWARD)

func _job_action() -> void:
    if job_stage == 0:
        job_stage = 1
        pickup_marker.show()
        drop_marker.hide()
        _show_toast("Delivery accepted. Go to the yellow pickup marker.")
    else:
        _show_toast("Finish your current delivery first.")

func _interact() -> void:
    if driving:
        _exit_car()
        return
    if player.global_position.distance_to(car.global_position) <= 5.0:
        driving = true
        player.hide()
        car_speed = 0.0
        _show_toast("You entered your car. Use ACCEL and BRAKE.")
    else:
        _show_toast("Walk closer to your blue car to enter.")

func _exit_car() -> void:
    if not driving:
        return
    driving = false
    player.show()
    player.global_position = car.global_position + car.global_basis.x * 2.4 + Vector3(0.0, 0.35, 0.0)
    player.velocity = Vector3.ZERO
    car_speed = 0.0
    _show_toast("You left the car.")

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
    empire_panel.hide()

func _buy_home() -> void:
    GameState.buy_home()

func _buy_shop() -> void:
    GameState.buy_shop()

func _collect_shop() -> void:
    GameState.collect_shop_income()

func _next_day() -> void:
    GameState.advance_day()

func _save_now() -> void:
    GameState.set_player_position(player.global_position)
    GameState.save_game()
    _show_toast("Game saved on this device.")

func _refresh_ui() -> void:
    if not is_instance_valid(wallet_label):
        return
    wallet_label.text = "WALLET  ₹%d     BANK  ₹%d" % [GameState.wallet, GameState.bank_balance]
    location_label.text = "NAVAPURA  •  %s  •  NET WORTH ₹%d" % ["DRIVING" if driving else "ON FOOT", GameState.net_worth()]
    if is_instance_valid(bank_info):
        var recent := ""
        for i in range(mini(GameState.transactions.size(), 5)):
            recent += "• %s\n" % GameState.transactions[i]
        bank_info.text = "Wallet: ₹%d\nBank: ₹%d\nNet worth: ₹%d\n\nRECENT TRANSACTIONS\n%s" % [GameState.wallet, GameState.bank_balance, GameState.net_worth(), recent]
    if is_instance_valid(phone_info):
        phone_info.text = "Day %d\nWallet ₹%d  •  Bank ₹%d\nYour phone connects your jobs, bank and empire." % [GameState.day_number, GameState.wallet, GameState.bank_balance]
    if is_instance_valid(empire_info):
        empire_info.text = "Day %d\nWallet: ₹%d  |  Bank: ₹%d\nHome: %s\nCorner shop: %s\nUncollected income: ₹%d\nLifetime earnings: ₹%d\nNet worth: ₹%d" % [
            GameState.day_number,
            GameState.wallet,
            GameState.bank_balance,
            "Owned" if GameState.home_owned else "Not owned",
            "Owned" if GameState.shop_owned else "Not owned",
            GameState.uncollected_shop_income,
            GameState.lifetime_earnings,
            GameState.net_worth()
        ]

func _show_toast(message: String) -> void:
    if is_instance_valid(toast_label):
        toast_label.text = message
        toast_time = 3.5

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(player):
        GameState.set_player_position(player.global_position)
        GameState.save_game()
