extends SceneTree

# Phase 1 guardrail: fail early if the Android-first project foundation drifts.
# This test intentionally checks configuration and required source files only;
# runtime behaviour is covered by the scene, world and economy smoke tests.

func _initialize() -> void:
    _check_setting("config/name", "LIFE EMPIRE")
    _check_setting("run/main_scene", "res://scenes/main.tscn")
    _check_setting("rendering/renderer/rendering_method", "gl_compatibility")
    _check_setting("rendering/renderer/rendering_method.mobile", "gl_compatibility")

    var features: PackedStringArray = ProjectSettings.get_setting("config/features", PackedStringArray())
    assert(features.has("4.7"), "Project must remain pinned to Godot 4.7.")
    assert(features.has("GL Compatibility"), "Project must declare the GL Compatibility renderer.")

    var orientation: int = int(ProjectSettings.get_setting("display/window/handheld/orientation", -1))
    assert(orientation == 0, "Android project must remain landscape-oriented.")

    var game_state_autoload: String = str(ProjectSettings.get_setting("autoload/GameState", ""))
    assert(game_state_autoload.ends_with("res://scripts/game_state.gd"), "GameState autoload must point to the canonical game-state script.")

    var required_files := [
        "res://scenes/main.tscn",
        "res://scripts/main.gd",
        "res://scripts/game_state.gd",
        "res://scripts/pedestrian.gd",
        "res://scripts/traffic_vehicle.gd",
        "res://tests/economy_smoke.gd",
        "res://tests/world_scene_smoke.tscn"
    ]
    for path in required_files:
        assert(FileAccess.file_exists(path), "Required Phase 1 project file is missing: %s" % path)

    print("LIFE EMPIRE Phase 1 foundation checks passed: Godot 4.7, landscape Android, GL Compatibility, main scene, GameState and core tests.")
    quit(0)

func _check_setting(setting: String, expected: String) -> void:
    var actual := str(ProjectSettings.get_setting(setting, ""))
    assert(actual == expected, "Project setting %s expected '%s', got '%s'." % [setting, expected, actual])
