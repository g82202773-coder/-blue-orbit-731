extends Node

const MAIN_SCENE = preload("res://scenes/main.tscn")
const TRAFFIC_SCRIPT = preload("res://scripts/traffic_vehicle.gd")
const PEDESTRIAN_SCRIPT = preload("res://scripts/pedestrian.gd")

func _ready() -> void:
    call_deferred("_run_world_smoke")

func _run_world_smoke() -> void:
    var scene := MAIN_SCENE.instantiate()
    add_child(scene)
    await get_tree().process_frame
    await get_tree().process_frame

    var traffic_count := 0
    var pedestrian_count := 0
    for child in scene.get_children():
        if child.get_script() == TRAFFIC_SCRIPT:
            traffic_count += 1
        elif child.get_script() == PEDESTRIAN_SCRIPT:
            pedestrian_count += 1
    if traffic_count < 3:
        _fail("The city should spawn at least three traffic vehicles.")
        return
    if pedestrian_count < 4:
        _fail("The city should spawn pedestrians on all four sidewalk routes.")
        return

    var required_city_nodes := [
        "Player",
        "FollowCamera",
        "NavapuraCentralMall",
        "NavapuraNationalBank",
        "NAVAPURAMOTORS",
        "CITYAUTOGALLERY",
        "NavapuraBusinessTower",
        "CentralMallInterior",
        "NavapuraMotorsInterior",
        "BusinessTowerLobby",
        "NavapuraMarketInterior"
    ]
    for node_name in required_city_nodes:
        if _find_named_node(scene, node_name) == null:
            _fail("Missing playable city node: %s" % node_name)
            return

    var player: CharacterBody3D = scene.get("player")
    if player == null:
        _fail("Playable city did not create its player.")
        return

    # Exercise the actual mall enter/exit interaction path.
    player.global_position = Vector3(-20.0, 1.0, -31.0)
    scene.call("_interact")
    await get_tree().process_frame
    if not scene.get("inside_mall") or not scene.get("mall_interior").visible:
        _fail("Mall entrance interaction did not open the interior.")
        return

    # Autosave must store the mall doorway as the reload position without
    # teleporting the live player out of the interior.
    var mall_inside_position: Vector3 = player.global_position
    scene.call("_sync_save_state")
    if not player.global_position.is_equal_approx(mall_inside_position):
        _fail("Autosave moved the live player out of the mall interior.")
        return
    if not GameState.player_position.is_equal_approx(Vector3(-20.0, 1.0, -31.0)):
        _fail("Autosave did not store the mall exterior return position.")
        return

    scene.call("_interact")
    await get_tree().process_frame
    if scene.get("inside_mall") or scene.get("mall_interior").visible:
        _fail("Mall exit interaction did not return to the city.")
        return

    # The showroom must open a separate walkable vehicle gallery and return.
    player.global_position = Vector3(-20.0, 1.0, 10.0)
    scene.call("_interact")
    await get_tree().process_frame
    if not scene.get("inside_showroom") or not scene.get("showroom_interior").visible:
        _fail("Showroom interaction did not open the vehicle gallery.")
        return
    var showroom_inside_position: Vector3 = player.global_position
    var showroom_door_position: Vector3 = scene.get("showroom_return_position")
    scene.call("_sync_save_state")
    if not player.global_position.is_equal_approx(showroom_inside_position):
        _fail("Autosave moved the live player out of the showroom interior.")
        return
    if not GameState.player_position.is_equal_approx(showroom_door_position):
        _fail("Autosave did not store the showroom exterior return position.")
        return
    scene.call("_interact")
    await get_tree().process_frame
    if scene.get("inside_showroom") or scene.get("showroom_interior").visible:
        _fail("Showroom exit interaction did not return to the city.")
        return

    # The public daily market must open and close its walkable shop interior.
    player.global_position = Vector3(-60.0, 1.0, -67.0)
    scene.call("_interact")
    await get_tree().process_frame
    if not scene.get("inside_public_store") or not scene.get("public_store_interior").visible:
        _fail("Daily market interaction did not open the store interior.")
        return
    var market_inside_position: Vector3 = player.global_position
    var market_door_position: Vector3 = scene.get("public_store_return_position")
    scene.call("_sync_save_state")
    if not player.global_position.is_equal_approx(market_inside_position):
        _fail("Autosave moved the live player out of the market interior.")
        return
    if not GameState.player_position.is_equal_approx(market_door_position):
        _fail("Autosave did not store the market exterior return position.")
        return
    scene.call("_interact")
    await get_tree().process_frame
    if scene.get("inside_public_store") or scene.get("public_store_interior").visible:
        _fail("Daily market exit interaction did not return to the city.")
        return

    # The office tower must open its lobby and return to the street.
    player.global_position = Vector3(60.0, 1.0, -29.0)
    scene.call("_interact")
    await get_tree().process_frame
    if not scene.get("inside_office") or not scene.get("office_interior").visible:
        _fail("Business tower interaction did not open its lobby.")
        return
    var office_inside_position: Vector3 = player.global_position
    var office_door_position: Vector3 = scene.get("office_return_position")
    scene.call("_sync_save_state")
    if not player.global_position.is_equal_approx(office_inside_position):
        _fail("Autosave moved the live player out of the office lobby.")
        return
    if not GameState.player_position.is_equal_approx(office_door_position):
        _fail("Autosave did not store the office exterior return position.")
        return
    scene.call("_interact")
    await get_tree().process_frame
    if scene.get("inside_office") or scene.get("office_interior").visible:
        _fail("Business tower exit interaction did not return to the city.")
        return

    # The bank building must route the player to the existing bank interface.
    player.global_position = Vector3(20.0, 1.0, -29.0)
    scene.call("_interact")
    await get_tree().process_frame
    if not scene.get("bank_panel").visible:
        _fail("Bank entrance did not open the banking interface.")
        return

    scene.queue_free()
    await get_tree().process_frame
    print("LIFE EMPIRE playable city smoke passed: player, landmarks, mall, showroom, market and office enter/exit plus bank interaction verified.")
    get_tree().quit(0)

func _find_named_node(parent: Node, target_name: String) -> Node:
    if parent.name == target_name:
        return parent
    for child in parent.get_children():
        var found := _find_named_node(child, target_name)
        if found != null:
            return found
    return null

func _fail(message: String) -> void:
    push_error(message)
    get_tree().quit(1)
