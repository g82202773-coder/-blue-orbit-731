extends SceneTree

func _initialize() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    assert(packed != null, "Main scene must load.")
    var instance := packed.instantiate()
    assert(instance != null, "Main scene must instantiate.")
    root.add_child(instance)

    # Node.add_child() runs the scene's _ready() synchronously. These checks
    # validate that the actual game setup creates its required runtime objects.
    assert(instance.get_node_or_null("Player") != null, "Player node must be created.")
    assert(instance.get_node_or_null("StarterCar") != null, "Starter car must be created.")
    assert(instance.get_node_or_null("FollowCamera") != null, "Active follow camera must be created.")
    assert(instance.get_node_or_null("CanvasLayer") != null, "Touch HUD must be created.")
    assert(instance.get_node_or_null("InstancedCityWindows") != null, "Instanced city facade details must be created.")
    assert(instance.get_node_or_null("InstancedLaneDashes") != null, "Instanced lane markings must be created.")

    print("LIFE EMPIRE scene smoke tests passed: player, vehicle, camera, HUD and city visuals are present.")
    quit(0)
