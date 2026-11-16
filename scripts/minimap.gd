extends Control

var player_position: Vector3 = Vector3.ZERO
var vehicle_position: Vector3 = Vector3.ZERO
var has_vehicle: bool = false
var pickup_position: Vector3 = Vector3.ZERO
var destination_position: Vector3 = Vector3.ZERO
var job_stage: int = 0

const CITY_LIMIT := 110.0
const ROAD_WIDTH := 12.0
const ROAD_CENTERS := [-80.0, -40.0, 0.0, 40.0, 80.0]

func _process(_delta: float) -> void:
    queue_redraw()

func _world_to_map(point: Vector3) -> Vector2:
    var usable := size - Vector2(24.0, 38.0)
    var center := Vector2(size.x * 0.5, size.y * 0.5 + 8.0)
    return center + Vector2(point.x / (CITY_LIMIT * 2.0), point.z / (CITY_LIMIT * 2.0)) * usable

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("#14212a"), true)
    draw_rect(Rect2(Vector2(5.0, 5.0), size - Vector2(10.0, 10.0)), Color("#25343c"), false, 2.0)

    # Compact top-down representation of Navapura's connected road grid.
    for lane in ROAD_CENTERS:
        var x := _world_to_map(Vector3(lane, 0.0, 0.0)).x
        var y := _world_to_map(Vector3(0.0, 0.0, lane)).y
        var road_w := maxf(7.0, ROAD_WIDTH / (CITY_LIMIT * 2.0) * (size.x - 24.0))
        draw_rect(Rect2(Vector2(x - road_w * 0.5, 24.0), Vector2(road_w, size.y - 48.0)), Color("#68737b"), true)
        draw_rect(Rect2(Vector2(12.0, y - road_w * 0.5), Vector2(size.x - 24.0, road_w)), Color("#68737b"), true)

    for lane in ROAD_CENTERS:
        var p1 := _world_to_map(Vector3(lane, 0.0, -CITY_LIMIT))
        var p2 := _world_to_map(Vector3(lane, 0.0, CITY_LIMIT))
        var p3 := _world_to_map(Vector3(-CITY_LIMIT, 0.0, lane))
        var p4 := _world_to_map(Vector3(CITY_LIMIT, 0.0, lane))
        draw_line(p1, p2, Color("#d8d4bd"), 1.0)
        draw_line(p3, p4, Color("#d8d4bd"), 1.0)

    # Mark central square and the player/vehicle/job destinations.
    var center := _world_to_map(Vector3.ZERO)
    draw_circle(center, 5.0, Color("#e2b85b"))
    if has_vehicle:
        draw_circle(_world_to_map(vehicle_position), 5.0, Color("#65b5ed"))
    if job_stage == 1:
        draw_circle(_world_to_map(pickup_position), 6.0, Color("#f0c34e"))
    elif job_stage == 2:
        draw_circle(_world_to_map(destination_position), 6.0, Color("#70d39a"))

    draw_circle(_world_to_map(player_position), 6.0, Color("#ffffff"))
    draw_arc(_world_to_map(player_position), 9.0, 0.0, TAU, 24, Color("#6fc8ff"), 2.0)
    draw_string(ThemeDB.fallback_font, Vector2(12.0, 20.0), "NAVAPURA MAP", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color("#f2f5f7"))
    draw_string(ThemeDB.fallback_font, Vector2(12.0, size.y - 10.0), "White: you   Blue: vehicle   Yellow/Green: job", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#c5d0d5"))
