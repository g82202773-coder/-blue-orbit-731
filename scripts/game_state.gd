extends Node

signal state_changed
signal toast_requested(message: String)

const SAVE_PATH := "user://life_empire_save.json"
const STARTING_WALLET := 5000
const MAX_TRANSACTIONS := 40

var wallet: int = STARTING_WALLET
var bank_balance: int = 0
var loan_balance: int = 0
var lifetime_earnings: int = 0
var day_number: int = 1
var game_minutes: float = 480.0
var home_owned: bool = false
var inside_home: bool = false
var home_return_position: Vector3 = Vector3(0.0, 0.0, 4.5)
var apartment_owned: bool = false
var inside_apartment: bool = false
var apartment_return_position: Vector3 = Vector3(0.0, 0.0, 4.5)
var uncollected_apartment_rent: int = 0
var inside_shop: bool = false
var shop_return_position: Vector3 = Vector3(0.0, 0.0, 4.5)
var shop_owned: bool = false
var bike_owned: bool = false
var shop_employee_count: int = 0
var shop_stock_units: int = 0
var uncollected_shop_income: int = 0
var missions_completed: int = 0
var player_level: int = 1
var player_xp: int = 0
var hunger_percent: float = 100.0
var energy_percent: float = 100.0
var active_job_stage: int = 0
var active_job_title: String = ""
var active_job_reward: int = 0
var active_job_pickup_position: Vector3 = Vector3.ZERO
var active_job_destination_position: Vector3 = Vector3.ZERO
var fuel_percent: float = 100.0
var car_condition_percent: float = 100.0
var bike_condition_percent: float = 100.0
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
    if apartment_owned:
        assets += 9000 + uncollected_apartment_rent
    if shop_owned:
        assets += 4000 + uncollected_shop_income + shop_stock_units * 15
    if bike_owned:
        assets += 2500
    return assets - loan_balance

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

func take_loan(amount: int) -> bool:
    if loan_balance > 0:
        toast_requested.emit("Repay your current loan before borrowing again.")
        return false
    if amount < 500 or amount > 5000 or amount % 500 != 0:
        toast_requested.emit("Choose a loan between ₹500 and ₹5,000 in ₹500 steps.")
        return false
    loan_balance = amount
    wallet += amount
    add_transaction("Bank loan received +₹%d" % amount)
    save_game()
    toast_requested.emit("₹%d loan received. Daily interest is 2%%." % amount)
    return true

func repay_loan(amount: int) -> bool:
    if loan_balance <= 0:
        toast_requested.emit("You do not have an active loan.")
        return false
    if amount <= 0:
        toast_requested.emit("Enter a valid repayment amount.")
        return false
    var payment: int = mini(amount, loan_balance)
    if wallet < payment:
        toast_requested.emit("Not enough wallet money for this repayment.")
        return false
    wallet -= payment
    loan_balance -= payment
    add_transaction("Loan repayment • -₹%d" % payment)
    save_game()
    toast_requested.emit("₹%d loan repayment completed." % payment)
    return true

func _apply_daily_finances() -> void:
    if apartment_owned:
        uncollected_apartment_rent += 200
        add_transaction("Apartment rent accrued +₹200")
    if shop_owned and shop_stock_units > 0:
        var daily_sales_capacity: int = 5 + shop_employee_count * 2
        var units_sold: int = mini(shop_stock_units, daily_sales_capacity)
        shop_stock_units -= units_sold
        uncollected_shop_income += units_sold * 50
        add_transaction("Shop sold %d units • +₹%d" % [units_sold, units_sold * 50])
    if loan_balance > 0:
        var interest: int = maxi(1, int(ceil(float(loan_balance) * 0.02)))
        loan_balance += interest
        add_transaction("Loan interest +₹%d" % interest)

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
    var xp_reward: int = maxi(25, int(round(float(amount) / 20.0)))
    add_job_experience(xp_reward)

func xp_to_next_level() -> int:
    return player_level * 100

func required_level_for_job(job_title: String) -> int:
    match job_title:
        "Courier parcel":
            return 2
        "Heavy cargo":
            return 3
        _:
            return 1

func can_accept_job(job_title: String) -> bool:
    return player_level >= required_level_for_job(job_title)

func add_job_experience(amount: int) -> void:
    if amount <= 0 or player_level >= 20:
        return
    player_xp += amount
    var levels_gained := 0
    while player_level < 20 and player_xp >= xp_to_next_level():
        player_xp -= xp_to_next_level()
        player_level += 1
        levels_gained += 1
        add_transaction("Reached Player Level %d" % player_level)
    if player_level >= 20:
        player_xp = 0
    save_game()
    if levels_gained > 0:
        toast_requested.emit("LEVEL UP! You reached Player Level %d." % player_level)
    else:
        toast_requested.emit("+%d job XP. %d / %d to next level." % [amount, player_xp, xp_to_next_level()])

func consume_fuel(amount: float) -> void:
    if amount <= 0.0:
        return
    fuel_percent = clampf(fuel_percent - amount, 0.0, 100.0)

func vehicle_condition(kind: String) -> float:
    return bike_condition_percent if kind == "motorbike" else car_condition_percent

func consume_vehicle_condition(kind: String, amount: float) -> void:
    if amount <= 0.0:
        return
    if kind == "motorbike":
        bike_condition_percent = clampf(bike_condition_percent - amount, 0.0, 100.0)
    else:
        car_condition_percent = clampf(car_condition_percent - amount, 0.0, 100.0)

func repair_vehicle(kind: String) -> bool:
    var condition: float = vehicle_condition(kind)
    if condition >= 99.9:
        toast_requested.emit("Your vehicle is already in good condition.")
        return false
    var repair_cost: int = maxi(100, int(round((100.0 - condition) * 20.0)))
    if wallet < repair_cost:
        toast_requested.emit("You need ₹%d for this vehicle service." % repair_cost)
        return false
    wallet -= repair_cost
    if kind == "motorbike":
        bike_condition_percent = 100.0
    else:
        car_condition_percent = 100.0
    add_transaction("%s service • -₹%d" % [kind.capitalize(), repair_cost])
    save_game()
    toast_requested.emit("%s serviced for ₹%d. Condition restored." % [kind.capitalize(), repair_cost])
    return true

func refuel_vehicle() -> bool:
    if fuel_percent >= 99.9:
        toast_requested.emit("Your vehicle tank is already full.")
        return false
    if wallet < 300:
        toast_requested.emit("You need ₹300 to refuel.")
        return false
    wallet -= 300
    fuel_percent = 100.0
    add_transaction("Vehicle refuel • -₹300")
    save_game()
    toast_requested.emit("Vehicle refuelled to 100%.")
    return true

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

func buy_apartment() -> bool:
    if apartment_owned:
        toast_requested.emit("You already own this rental apartment.")
        return false
    if wallet < 8000:
        toast_requested.emit("You need ₹8,000 in your wallet to buy the apartment.")
        return false
    wallet -= 8000
    apartment_owned = true
    add_transaction("Purchased rental apartment • -₹8,000")
    save_game()
    toast_requested.emit("Rental apartment purchased. It can earn ₹200 per day.")
    return true

func collect_apartment_rent() -> bool:
    if not apartment_owned:
        toast_requested.emit("Purchase the rental apartment first.")
        return false
    if not inside_apartment:
        toast_requested.emit("Enter your apartment to collect rent.")
        return false
    if uncollected_apartment_rent <= 0:
        toast_requested.emit("No rent is ready to collect yet. Advance a day.")
        return false
    var amount: int = uncollected_apartment_rent
    uncollected_apartment_rent = 0
    wallet += amount
    lifetime_earnings += amount
    add_transaction("Collected apartment rent +₹%d" % amount)
    save_game()
    toast_requested.emit("Collected ₹%d in apartment rent." % amount)
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
    shop_stock_units = 25
    add_transaction("Purchased corner shop • -₹4,000")
    save_game()
    toast_requested.emit("Your corner shop is open!")
    return true

func restock_shop() -> bool:
    if not shop_owned:
        toast_requested.emit("Purchase the corner shop before restocking.")
        return false
    if not inside_shop:
        toast_requested.emit("Enter your shop before restocking inventory.")
        return false
    if wallet < 300:
        toast_requested.emit("You need ₹300 to restock the shop.")
        return false
    if shop_stock_units >= 50:
        toast_requested.emit("Your shop inventory is already full.")
        return false
    var added_units: int = mini(20, 50 - shop_stock_units)
    wallet -= 300
    shop_stock_units += added_units
    add_transaction("Restocked shop • +%d units • -₹300" % added_units)
    save_game()
    toast_requested.emit("Shop restocked with %d units." % added_units)
    return true

func hire_shop_employee() -> bool:
    if not shop_owned:
        toast_requested.emit("Buy the corner shop before hiring staff.")
        return false
    if not inside_shop:
        toast_requested.emit("Enter your shop before hiring employees.")
        return false
    if shop_employee_count >= 3:
        toast_requested.emit("Your shop is at its staff limit.")
        return false
    if wallet < 500:
        toast_requested.emit("You need ₹500 to hire an employee.")
        return false
    wallet -= 500
    shop_employee_count += 1
    add_transaction("Hired shop employee • -₹500")
    save_game()
    toast_requested.emit("Employee hired. Daily shop income increased.")
    return true

func collect_shop_income() -> bool:
    if not shop_owned:
        toast_requested.emit("Purchase the corner shop first.")
        return false
    if not inside_shop:
        toast_requested.emit("Enter your shop to collect today's earnings.")
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

func advance_clock(real_seconds: float) -> void:
    if real_seconds <= 0.0:
        return
    game_minutes += real_seconds
    hunger_percent = clampf(hunger_percent - real_seconds * 0.025, 0.0, 100.0)
    energy_percent = clampf(energy_percent - real_seconds * 0.008, 0.0, 100.0)
    var crossed_day := false
    while game_minutes >= 1440.0:
        game_minutes -= 1440.0
        day_number += 1
        crossed_day = true
        add_transaction("Started Day %d" % day_number)
        _apply_daily_finances()
    if crossed_day:
        save_game()
        toast_requested.emit("A new day has started. Day %d." % day_number)

func clock_text() -> String:
    var total_minutes: int = int(floor(game_minutes)) % 1440
    var hour: int = int(total_minutes / 60)
    var minute: int = total_minutes % 60
    var suffix: String = "AM" if hour < 12 else "PM"
    var display_hour: int = hour % 12
    if display_hour == 0:
        display_hour = 12
    return "%02d:%02d %s" % [display_hour, minute, suffix]

func advance_day() -> void:
    day_number += 1
    game_minutes = 8.0 * 60.0
    add_transaction("Started Day %d" % day_number)
    _apply_daily_finances()
    save_game()
    toast_requested.emit("Day %d started." % day_number)

func buy_meal() -> bool:
    const MEAL_PRICE := 100
    if hunger_percent >= 98.0:
        toast_requested.emit("You are not hungry right now.")
        return false
    if wallet < MEAL_PRICE:
        toast_requested.emit("You need ₹100 to buy a meal.")
        return false
    wallet -= MEAL_PRICE
    hunger_percent = minf(100.0, hunger_percent + 45.0)
    add_transaction("Bought a meal • -₹100")
    save_game()
    toast_requested.emit("Meal purchased. Hunger restored.")
    return true

func sleep_at_home() -> bool:
    var inside_owned_residence: bool = (home_owned and inside_home) or (apartment_owned and inside_apartment)
    if not home_owned and not apartment_owned:
        toast_requested.emit("Buy a home or apartment before using the sleep action.")
        return false
    if not inside_owned_residence:
        toast_requested.emit("Enter your home or apartment before sleeping.")
        return false
    day_number += 1
    game_minutes = 8.0 * 60.0
    energy_percent = 100.0
    hunger_percent = maxf(0.0, hunger_percent - 15.0)
    add_transaction("Slept at home • started Day %d" % day_number)
    _apply_daily_finances()
    save_game()
    toast_requested.emit("Good morning! Energy restored. Day %d." % day_number)
    return true

func consume_energy(amount: float) -> void:
    if amount <= 0.0:
        return
    energy_percent = clampf(energy_percent - amount, 0.0, 100.0)

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
        "version": 12,
        "wallet": wallet,
        "bank_balance": bank_balance,
        "loan_balance": loan_balance,
        "lifetime_earnings": lifetime_earnings,
        "day_number": day_number,
        "game_minutes": game_minutes,
        "home_owned": home_owned,
        "inside_home": inside_home,
        "home_return_x": home_return_position.x,
        "home_return_y": home_return_position.y,
        "home_return_z": home_return_position.z,
        "apartment_owned": apartment_owned,
        "inside_apartment": inside_apartment,
        "apartment_return_x": apartment_return_position.x,
        "apartment_return_y": apartment_return_position.y,
        "apartment_return_z": apartment_return_position.z,
        "uncollected_apartment_rent": uncollected_apartment_rent,
        "inside_shop": inside_shop,
        "shop_return_x": shop_return_position.x,
        "shop_return_y": shop_return_position.y,
        "shop_return_z": shop_return_position.z,
        "shop_owned": shop_owned,
        "bike_owned": bike_owned,
        "shop_employee_count": shop_employee_count,
        "shop_stock_units": shop_stock_units,
        "uncollected_shop_income": uncollected_shop_income,
        "missions_completed": missions_completed,
        "player_level": player_level,
        "player_xp": player_xp,
        "hunger_percent": hunger_percent,
        "energy_percent": energy_percent,
        "active_job_stage": active_job_stage,
        "active_job_title": active_job_title,
        "active_job_reward": active_job_reward,
        "active_job_pickup_x": active_job_pickup_position.x,
        "active_job_pickup_y": active_job_pickup_position.y,
        "active_job_pickup_z": active_job_pickup_position.z,
        "active_job_destination_x": active_job_destination_position.x,
        "active_job_destination_y": active_job_destination_position.y,
        "active_job_destination_z": active_job_destination_position.z,
        "fuel_percent": fuel_percent,
        "car_condition_percent": car_condition_percent,
        "bike_condition_percent": bike_condition_percent,
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
    loan_balance = maxi(0, int(parsed.get("loan_balance", 0)))
    lifetime_earnings = maxi(0, int(parsed.get("lifetime_earnings", parsed.get("total_earned", 0))))
    day_number = maxi(1, int(parsed.get("day_number", 1)))
    game_minutes = fposmod(float(parsed.get("game_minutes", 480.0)), 1440.0)
    home_owned = bool(parsed.get("home_owned", parsed.get("property_owned", false)))
    inside_home = bool(parsed.get("inside_home", false))
    home_return_position = Vector3(
        float(parsed.get("home_return_x", 0.0)),
        float(parsed.get("home_return_y", 0.0)),
        float(parsed.get("home_return_z", 4.5))
    )
    apartment_owned = bool(parsed.get("apartment_owned", false))
    inside_apartment = bool(parsed.get("inside_apartment", false))
    apartment_return_position = Vector3(
        float(parsed.get("apartment_return_x", 0.0)),
        float(parsed.get("apartment_return_y", 0.0)),
        float(parsed.get("apartment_return_z", 4.5))
    )
    uncollected_apartment_rent = maxi(0, int(parsed.get("uncollected_apartment_rent", 0)))
    inside_shop = bool(parsed.get("inside_shop", false))
    shop_return_position = Vector3(
        float(parsed.get("shop_return_x", 0.0)),
        float(parsed.get("shop_return_y", 0.0)),
        float(parsed.get("shop_return_z", 4.5))
    )
    shop_owned = bool(parsed.get("shop_owned", parsed.get("business_owned", false)))
    bike_owned = bool(parsed.get("bike_owned", false))
    shop_employee_count = clampi(int(parsed.get("shop_employee_count", 0)), 0, 3)
    shop_stock_units = clampi(int(parsed.get("shop_stock_units", 25 if shop_owned else 0)), 0, 50)
    uncollected_shop_income = maxi(0, int(parsed.get("uncollected_shop_income", parsed.get("business_cashflow", 0))))
    missions_completed = maxi(0, int(parsed.get("missions_completed", 0)))
    player_level = clampi(int(parsed.get("player_level", 1)), 1, 20)
    player_xp = clampi(int(parsed.get("player_xp", 0)), 0, maxi(0, xp_to_next_level() - 1))
    hunger_percent = clampf(float(parsed.get("hunger_percent", 100.0)), 0.0, 100.0)
    energy_percent = clampf(float(parsed.get("energy_percent", 100.0)), 0.0, 100.0)
    active_job_stage = clampi(int(parsed.get("active_job_stage", 0)), 0, 2)
    active_job_title = str(parsed.get("active_job_title", ""))
    active_job_reward = maxi(0, int(parsed.get("active_job_reward", 0)))
    active_job_pickup_position = Vector3(
        float(parsed.get("active_job_pickup_x", 0.0)),
        float(parsed.get("active_job_pickup_y", 0.85)),
        float(parsed.get("active_job_pickup_z", 0.0))
    )
    active_job_destination_position = Vector3(
        float(parsed.get("active_job_destination_x", 0.0)),
        float(parsed.get("active_job_destination_y", 0.85)),
        float(parsed.get("active_job_destination_z", 0.0))
    )
    fuel_percent = clampf(float(parsed.get("fuel_percent", 100.0)), 0.0, 100.0)
    car_condition_percent = clampf(float(parsed.get("car_condition_percent", 100.0)), 0.0, 100.0)
    bike_condition_percent = clampf(float(parsed.get("bike_condition_percent", 100.0)), 0.0, 100.0)
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
