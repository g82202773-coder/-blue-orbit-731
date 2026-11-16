extends SceneTree

func _initialize() -> void:
    call_deferred("_run_scene_test")

func _run_scene_test() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    assert(packed != null, "Main scene must load.")
    var instance := packed.instantiate()
    assert(instance != null, "Main scene must instantiate.")
    root.add_child(instance)
    await process_frame
    await process_frame

    assert(instance.get_node_or_null("Player") != null, "Player node must be created.")
    assert(instance.get_node_or_null("StarterCar") != null, "Starter car must be created.")
    assert(instance.get_node_or_null("FollowCamera") != null, "Active follow camera must be created.")
    assert(instance.get_node_or_null("CanvasLayer") != null, "Touch HUD must be created.")
    assert(instance.get_node_or_null("InstancedCityWindows") != null, "Instanced city facade details must be created.")
    assert(instance.get_node_or_null("InstancedLaneDashes") != null, "Instanced lane markings must be created.")

    print("LIFE EMPIRE scene smoke tests passed: player, vehicle, camera, HUD and city visuals are present.")
    instance.queue_free()
    await process_frame
    quit(0)
