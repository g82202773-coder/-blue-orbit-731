extends Node

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _ready() -> void:
    call_deferred("_run_world_smoke")

func _run_world_smoke() -> void:
    var scene := MAIN_SCENE.instantiate()
    add_child(scene)
    await get_tree().process_frame
    await get_tree().process_frame

    var required_city_nodes := [
        "Player",
        "FollowCamera",
        "NavapuraCentralMall",
        "NavapuraNationalBank",
        "NAVAPURAMOTORS",
        "CITYAUTOGALLERY",
        "NavapuraBusinessTower",
        "CentralMallInterior"
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
    scene.call("_interact")
    await get_tree().process_frame
    if scene.get("inside_mall") or scene.get("mall_interior").visible:
        _fail("Mall exit interaction did not return to the city.")
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
    print("LIFE EMPIRE playable city smoke passed: player, landmarks, mall enter/exit and bank interaction verified.")
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
