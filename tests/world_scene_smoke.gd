extends Node

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _ready() -> void:
    call_deferred("_run_world_smoke")

func _run_world_smoke() -> void:
    GameState.shop_owned = true
    GameState.shop_upgrade_level = 2
    var scene := MAIN_SCENE.instantiate()
    add_child(scene)
    await get_tree().process_frame
    await get_tree().process_frame

    var required_walls := [
        "InteriorWestWall",
        "ShopWestWall",
        "ApartmentEastInnerWall"
    ]
    for wall_name in required_walls:
        var wall := _find_named_node(scene, wall_name)
        if wall == null:
            _fail("Missing interior wall: %s" % wall_name)
            return
        if not (wall is StaticBody3D):
            _fail("%s must be a StaticBody3D." % wall_name)
            return
        if not _has_collision_shape(wall):
            _fail("%s is missing its collision shape." % wall_name)
            return

    var mini_mart_visuals := _find_named_node(scene, "MiniMartDisplays")
    var supermarket_visuals := _find_named_node(scene, "SupermarketDisplays")
    if mini_mart_visuals == null or supermarket_visuals == null:
        _fail("Shop tier visual nodes were not created.")
        return
    if not mini_mart_visuals.visible or not supermarket_visuals.visible:
        _fail("Tier 2 should display both Mini Mart and Supermarket fixtures.")
        return

    var apartment_floor := _find_named_node(scene, "ApartmentFloorCollision")
    if apartment_floor == null or not (apartment_floor is StaticBody3D):
        _fail("Apartment interior floor collision is missing.")
        return

    scene.queue_free()
    await get_tree().process_frame
    print("LIFE EMPIRE world smoke passed: interior wall collisions, apartment floor and shop upgrade visuals.")
    get_tree().quit(0)

func _find_named_node(parent: Node, target_name: String) -> Node:
    if parent.name == target_name:
        return parent
    for child in parent.get_children():
        var found := _find_named_node(child, target_name)
        if found != null:
            return found
    return null

func _has_collision_shape(node: Node) -> bool:
    for child in node.get_children():
        if child is CollisionShape3D:
            return true
    return false

func _fail(message: String) -> void:
    push_error(message)
    get_tree().quit(1)
