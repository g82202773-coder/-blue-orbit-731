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
        "CityShowcaseCamera",
        "NavapuraCentralMall",
        "NavapuraNationalBank",
        "NAVAPURAMOTORS",
        "CITYAUTOGALLERY",
        "NavapuraBusinessTower"
    ]
    for node_name in required_city_nodes:
        if _find_named_node(scene, node_name) == null:
            _fail("Missing city showcase node: %s" % node_name)
            return

    var forbidden_actor_nodes := [
        "Player",
        "Car",
        "Motorbike",
        "Pedestrians",
        "TrafficVehicles",
        "HUD"
    ]
    for node_name in forbidden_actor_nodes:
        if _find_named_node(scene, node_name) != null:
            _fail("City-only showcase unexpectedly instantiated gameplay node: %s" % node_name)
            return

    scene.queue_free()
    await get_tree().process_frame
    print("LIFE EMPIRE city showcase smoke passed: landmarks and showcase camera present; gameplay actors absent.")
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
