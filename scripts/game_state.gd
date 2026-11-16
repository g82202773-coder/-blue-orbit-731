extends Node

signal state_changed
signal toast_requested(message: String)

const SAVE_PATH := "user://life_empire_save.json"
const STARTING_WALLET := 5000
const MAX_TRANSACTIONS := 40

var wallet: int = STARTING_WALLET
var bank_balance: int = 0
var lifetime_earnings: int = 0
var day_number: int = 1
var home_owned: bool = false
var shop_owned: bool = false
var bike_owned: bool = false
var uncollected_shop_income: int = 0
var missions_completed: int = 0
var player_position: Vector3 = Vector3(0.0, 0.0, 4.5)
var car_position: Vector3 = Vector3(0.0, 0.72, 0.0)
var car_rotation_y: float = 0.0
var bike_position: Vector3 = Vector3(6.0, 0.58, 0.0)
var bike_rotation_y: float = 0.0
var was_driving: bool = false
var active_vehicle_kind: String = "car"
var transactions: Array[String] = []

func _ready() -> void:
    load_game()

func net_worth() -> int:
    var assets := wallet + bank_balance
    if home_owned:
        assets += 3000
    if shop_owned:
        assets += 4000 + uncollected_shop_income
    if bike_owned:
        assets += 2500
    return assets

func add_transaction(description: String) -> void:
    var stamp := "Day %d" % day_number
    transactions.push_front("%s • %s" % [stamp, description])
    while transactions.size() > MAX_TRANSACTIONS:
        transactions.pop_back()
    state_changed.emit()

func deposit(amount: int) -> bool:
    if amount <= 0 or wallet < amount:
        toast_requested.emit("Not enough money in your wallet.")
        return false
    wallet -= amount
    bank_balance += amount
    add_transaction("Deposited ₹%d" % amount)
    save_game()
    toast_requested.emit("₹%d deposited." % amount)
    return true

func withdraw(amount: int) -> bool:
    if amount <= 0 or bank_balance < amount:
        toast_requested.emit("Not enough money in your bank.")
        return false
    bank_balance -= amount
    wallet += amount
    add_transaction("Withdrew ₹%d" % amount)
    save_game()
    toast_requested.emit("₹%d withdrawn." % amount)
    return true

func earn(amount: int, reason: String) -> void:
    if amount <= 0:
        return
    wallet += amount
    lifetime_earnings += amount
    add_transaction("%s +₹%d" % [reason, amount])
    save_game()
    toast_requested.emit("You earned ₹%d." % amount)

func complete_mission(amount: int, mission_name: String) -> void:
    if amount <= 0:
        return
    missions_completed += 1
    earn(amount, "%s completed" % mission_name)
    save_game()

func buy_home() -> bool:
    if home_owned:
        toast_requested.emit("You already own a home.")
        return false
    if wallet < 3000:
        toast_requested.emit("You need ₹3,000 in your wallet.")
        return false
    wallet -= 3000
    home_owned = true
    add_transaction("Purchased starter home • -₹3,000")
    save_game()
    toast_requested.emit("Your first home is now yours!")
    return true

func buy_bike() -> bool:
    if bike_owned:
        toast_requested.emit("You already own a motorbike.")
        return false
    if wallet < 2500:
        toast_requested.emit("You need ₹2,500 in your wallet.")
        return false
    wallet -= 2500
    bike_owned = true
    add_transaction("Purchased motorbike • -₹2,500")
    save_game()
    toast_requested.emit("Your motorbike is ready in the city!")
    return true

func buy_shop() -> bool:
    if shop_owned:
        toast_requested.emit("You already own the corner shop.")
        return false
    if wallet < 4000:
        toast_requested.emit("You need ₹4,000 in your wallet.")
        return false
    wallet -= 4000
    shop_owned = true
    add_transaction("Purchased corner shop • -₹4,000")
    save_game()
    toast_requested.emit("Your corner shop is open!")
    return true

func collect_shop_income() -> bool:
    if not shop_owned:
        toast_requested.emit("Purchase the corner shop first.")
        return false
    if uncollected_shop_income <= 0:
        toast_requested.emit("No shop income to collect yet. Advance a day.")
        return false
    var amount := uncollected_shop_income
    uncollected_shop_income = 0
    wallet += amount
    lifetime_earnings += amount
    add_transaction("Collected shop income +₹%d" % amount)
    save_game()
    toast_requested.emit("Collected ₹%d from your shop." % amount)
    return true

func advance_day() -> void:
    day_number += 1
    if shop_owned:
        uncollected_shop_income += 250
    add_transaction("Started Day %d" % day_number)
    save_game()
    toast_requested.emit("Day %d started." % day_number)

func set_player_position(position: Vector3) -> void:
    player_position = position

func set_vehicle_state(kind: String, position: Vector3, rotation_y: float, is_driving: bool) -> void:
    active_vehicle_kind = kind
    was_driving = is_driving
    if kind == "motorbike":
        bike_position = position
        bike_rotation_y = rotation_y
    else:
        car_position = position
        car_rotation_y = rotation_y

func save_game() -> void:
    var data := {
        "version": 2,
        "wallet": wallet,
        "bank_balance": bank_balance,
        "lifetime_earnings": lifetime_earnings,
        "day_number": day_number,
        "home_owned": home_owned,
        "shop_owned": shop_owned,
        "bike_owned": bike_owned,
        "uncollected_shop_income": uncollected_shop_income,
        "missions_completed": missions_completed,
        "player_x": player_position.x,
        "player_y": player_position.y,
        "player_z": player_position.z,
        "car_x": car_position.x,
        "car_y": car_position.y,
        "car_z": car_position.z,
        "car_rotation_y": car_rotation_y,
        "bike_x": bike_position.x,
        "bike_y": bike_position.y,
        "bike_z": bike_position.z,
        "bike_rotation_y": bike_rotation_y,
        "was_driving": was_driving,
        "active_vehicle_kind": active_vehicle_kind,
        "transactions": transactions
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_warning("Could not open save file: %s" % FileAccess.get_open_error())
        toast_requested.emit("Save failed. Check device storage.")
        return
    file.store_string(JSON.stringify(data))
    file.close()
    state_changed.emit()

func load_game() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        push_warning("Could not read save file.")
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("Save file was invalid; using a fresh game.")
        return
    wallet = maxi(0, int(parsed.get("wallet", STARTING_WALLET)))
    bank_balance = maxi(0, int(parsed.get("bank_balance", parsed.get("bank", 0))))
    lifetime_earnings = maxi(0, int(parsed.get("lifetime_earnings", parsed.get("total_earned", 0))))
    day_number = maxi(1, int(parsed.get("day_number", 1)))
    home_owned = bool(parsed.get("home_owned", parsed.get("property_owned", false)))
    shop_owned = bool(parsed.get("shop_owned", parsed.get("business_owned", false)))
    bike_owned = bool(parsed.get("bike_owned", false))
    uncollected_shop_income = maxi(0, int(parsed.get("uncollected_shop_income", parsed.get("business_cashflow", 0))))
    missions_completed = maxi(0, int(parsed.get("missions_completed", 0)))
    player_position = Vector3(
        float(parsed.get("player_x", 0.0)),
        float(parsed.get("player_y", 0.0)),
        float(parsed.get("player_z", 4.5))
    )
    car_position = Vector3(
        float(parsed.get("car_x", 0.0)),
        float(parsed.get("car_y", 0.72)),
        float(parsed.get("car_z", 0.0))
    )
    car_rotation_y = float(parsed.get("car_rotation_y", 0.0))
    bike_position = Vector3(
        float(parsed.get("bike_x", 6.0)),
        float(parsed.get("bike_y", 0.58)),
        float(parsed.get("bike_z", 0.0))
    )
    bike_rotation_y = float(parsed.get("bike_rotation_y", 0.0))
    was_driving = bool(parsed.get("was_driving", false))
    active_vehicle_kind = str(parsed.get("active_vehicle_kind", "car"))
    transactions.clear()
    for item in parsed.get("transactions", []):
        transactions.append(str(item))
    state_changed.emit()
