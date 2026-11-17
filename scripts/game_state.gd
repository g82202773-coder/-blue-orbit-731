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
var shop_upgrade_level: int = 0
var shop_upgrade_investment: int = 0
var shop_stock_units: int = 0
var uncollected_shop_income: int = 0
var missions_completed: int = 0
var missions_failed: int = 0
var active_job_time_remaining: float = 0.0
var active_job_time_limit: float = 0.0
var player_level: int = 1
var player_xp: int = 0
var shares_mtr: int = 0
var shares_nre: int = 0
var shares_ncr: int = 0
var hunger_percent: float = 100.0
var energy_percent: float = 100.0
var active_job_stage: int = 0
var active_job_title: String = ""
var active_job_reward: int = 0
var active_job_pickup_position: Vector3 = Vector3.ZERO
var active_job_destination_position: Vector3 = Vector3.ZERO
var car_fuel_percent: float = 100.0
var bike_fuel_percent: float = 100.0
var car_condition_percent: float = 100.0
var bike_condition_percent: float = 100.0
var player_position: Vector3 = Vector3(0.0, 0.0, 4.5)
var car_position: Vector3 = Vector3(0.0, 0.72, 0.0)
var car_rotation_y: float = 0.0
var bike_position: Vector3 = Vector3(6.0, 0.58, 0.0)
var bike_rotation_y: float = 0.0
var was_driving: bool = false
var active_vehicle_kind: String = "car"
# Compatibility alias: older scripts/save files used one active-vehicle fuel value.
var fuel_percent: float:
    get:
        return vehicle_fuel(active_vehicle_kind)
    set(value):
        set_vehicle_fuel(active_vehicle_kind, value)
var transactions: Array[String] = []

func _ready() -> void:
    load_game()

func net_worth() -> int:
    var assets := wallet + bank_balance + investment_portfolio_value()
    if home_owned:
        assets += 3000
    if apartment_owned:
        assets += 8000 + uncollected_apartment_rent
    if shop_owned:
        assets += 4000 + shop_upgrade_investment + uncollected_shop_income + shop_stock_units * 15
    if bike_owned:
        assets += 2500
    return assets - loan_balance

func share_price(ticker: String) -> int:
    var day_phase: float = float(day_number) * 0.47
    match ticker:
        "MTR":
            return maxi(25, int(round(120.0 + 22.0 * sin(day_phase))))
        "NRE":
            return maxi(20, int(round(85.0 + 17.0 * sin(day_phase + 1.55))))
        "NCR":
            return maxi(15, int(round(60.0 + 12.0 * sin(day_phase + 2.8))))
        _:
            return 0

func share_holding(ticker: String) -> int:
    match ticker:
        "MTR":
            return shares_mtr
        "NRE":
            return shares_nre
        "NCR":
            return shares_ncr
        _:
            return 0

func investment_portfolio_value() -> int:
    return shares_mtr * share_price("MTR") + shares_nre * share_price("NRE") + shares_ncr * share_price("NCR")

func buy_shares(ticker: String, quantity: int = 1) -> bool:
    if not ["MTR", "NRE", "NCR"].has(ticker):
        toast_requested.emit("Unknown company ticker.")
        return false
    if quantity < 1 or quantity > 100:
        toast_requested.emit("Choose between 1 and 100 shares.")
        return false
    var total_cost: int = share_price(ticker) * quantity
    if wallet < total_cost:
        toast_requested.emit("You need ₹%d to buy %d shares." % [total_cost, quantity])
        return false
    wallet -= total_cost
    match ticker:
        "MTR":
            shares_mtr += quantity
        "NRE":
            shares_nre += quantity
        "NCR":
            shares_ncr += quantity
    add_transaction("Bought %d %s shares • -₹%d" % [quantity, ticker, total_cost])
    save_game()
    toast_requested.emit("Bought %d %s shares for ₹%d." % [quantity, ticker, total_cost])
    return true

func sell_shares(ticker: String, quantity: int = 1) -> bool:
    if not ["MTR", "NRE", "NCR"].has(ticker):
        toast_requested.emit("Unknown company ticker.")
        return false
    if quantity < 1 or quantity > share_holding(ticker):
        toast_requested.emit("You do not own enough %s shares." % ticker)
        return false
    var proceeds: int = share_price(ticker) * quantity
    match ticker:
        "MTR":
            shares_mtr -= quantity
        "NRE":
            shares_nre -= quantity
        "NCR":
            shares_ncr -= quantity
    wallet += proceeds
    add_transaction("Sold %d %s shares • +₹%d" % [quantity, ticker, proceeds])
    save_game()
    toast_requested.emit("Sold %d %s shares for ₹%d." % [quantity, ticker, proceeds])
    return true

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
        var daily_sales_capacity: int = shop_daily_sales_capacity()
        var units_sold: int = mini(shop_stock_units, daily_sales_capacity)
        var daily_revenue: int = units_sold * shop_sale_price_per_unit()
        shop_stock_units -= units_sold
        uncollected_shop_income += daily_revenue
        add_transaction("Shop sold %d units • +₹%d" % [units_sold, daily_revenue])
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

func job_time_limit_for(job_title: String) -> float:
    match job_title:
        "Taxi passenger":
            return 180.0
        "Courier parcel":
            return 240.0
        "Heavy cargo":
            return 300.0
        _:
            return 210.0

func start_job_timer(duration_seconds: float) -> void:
    active_job_time_limit = maxf(1.0, duration_seconds)
    active_job_time_remaining = active_job_time_limit
    save_game()

func clear_job_timer() -> void:
    active_job_time_remaining = 0.0
    active_job_time_limit = 0.0
    save_game()

func job_timer_text() -> String:
    var total_seconds: int = maxi(0, int(ceil(active_job_time_remaining)))
    var minutes: int = int(total_seconds / 60)
    var seconds: int = total_seconds % 60
    return "%02d:%02d" % [minutes, seconds]

func fail_active_mission() -> void:
    if active_job_stage == 0:
        return
    missions_failed += 1
    add_transaction("%s failed • time expired" % active_job_title)
    active_job_stage = 0
    active_job_title = ""
    active_job_reward = 0
    clear_job_timer()
    save_game()
    toast_requested.emit("Mission failed. Time expired; no reward was paid.")

func complete_mission(amount: int, mission_name: String) -> int:
    if amount <= 0:
        return 0
    missions_completed += 1
    var time_bonus: int = 0
    if active_job_time_limit > 0.0 and active_job_time_remaining > 0.0:
        var remaining_ratio: float = clampf(active_job_time_remaining / active_job_time_limit, 0.0, 1.0)
        time_bonus = int(round(float(amount) * 0.15 * remaining_ratio))
    var total_payout: int = amount + time_bonus
    earn(total_payout, "%s completed" % mission_name)
    if time_bonus > 0:
        add_transaction("On-time delivery bonus +₹%d" % time_bonus)
    var xp_reward: int = maxi(25, int(round(float(total_payout) / 20.0)))
    active_job_time_remaining = 0.0
    active_job_time_limit = 0.0
    add_job_experience(xp_reward)
    save_game()
    return total_payout

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

func vehicle_fuel(kind: String) -> float:
    return bike_fuel_percent if kind == "motorbike" else car_fuel_percent

func set_vehicle_fuel(kind: String, value: float) -> void:
    if kind == "motorbike":
        bike_fuel_percent = clampf(value, 0.0, 100.0)
    else:
        car_fuel_percent = clampf(value, 0.0, 100.0)

func consume_fuel(amount: float, kind: String = "") -> void:
    if amount <= 0.0:
        return
    var target_kind: String = active_vehicle_kind if kind.is_empty() else kind
    set_vehicle_fuel(target_kind, vehicle_fuel(target_kind) - amount)

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

func refuel_vehicle(kind: String = "") -> bool:
    var target_kind: String = active_vehicle_kind if kind.is_empty() else kind
    if vehicle_fuel(target_kind) >= 99.9:
        toast_requested.emit("Your %s tank is already full." % target_kind)
        return false
    if wallet < 300:
        toast_requested.emit("You need ₹300 to refuel.")
        return false
    wallet -= 300
    set_vehicle_fuel(target_kind, 100.0)
    add_transaction("%s refuel • -₹300" % target_kind.capitalize())
    save_game()
    toast_requested.emit("%s refuelled to 100%." % target_kind.capitalize())
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

func shop_upgrade_cost() -> int:
    match shop_upgrade_level:
        0:
            return 2500
        1:
            return 5000
        _:
            return 0

func shop_stock_capacity() -> int:
    return 50 + shop_upgrade_level * 25

func shop_daily_sales_capacity() -> int:
    return 5 + shop_employee_count * 2 + shop_upgrade_level * 5

func shop_sale_price_per_unit() -> int:
    return 50 + shop_upgrade_level * 10

func upgrade_shop() -> bool:
    if not shop_owned:
        toast_requested.emit("Purchase the corner shop before upgrading it.")
        return false
    if not inside_shop:
        toast_requested.emit("Enter your shop before purchasing an upgrade.")
        return false
    var cost: int = shop_upgrade_cost()
    if cost <= 0:
        toast_requested.emit("Your shop is already fully upgraded.")
        return false
    if wallet < cost:
        toast_requested.emit("You need ₹%d for the next shop upgrade." % cost)
        return false
    wallet -= cost
    shop_upgrade_level += 1
    shop_upgrade_investment += cost
    add_transaction("Upgraded shop to Tier %d • -₹%d" % [shop_upgrade_level, cost])
    save_game()
    toast_requested.emit("Shop upgraded to Tier %d. Sales capacity and unit prices increased." % shop_upgrade_level)
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
    var capacity: int = shop_stock_capacity()
    if shop_stock_units >= capacity:
        toast_requested.emit("Your shop inventory is already full.")
        return false
    var added_units: int = mini(20, capacity - shop_stock_units)
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
    if active_job_stage > 0 and active_job_time_remaining > 0.0:
        active_job_time_remaining = maxf(0.0, active_job_time_remaining - real_seconds)
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
        "version": 18,
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
        "shop_upgrade_level": shop_upgrade_level,
        "shop_upgrade_investment": shop_upgrade_investment,
        "shop_stock_units": shop_stock_units,
        "uncollected_shop_income": uncollected_shop_income,
        "missions_completed": missions_completed,
        "missions_failed": missions_failed,
        "active_job_time_remaining": active_job_time_remaining,
        "active_job_time_limit": active_job_time_limit,
        "player_level": player_level,
        "player_xp": player_xp,
        "shares_mtr": shares_mtr,
        "shares_nre": shares_nre,
        "shares_ncr": shares_ncr,
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
        "fuel_percent": car_fuel_percent,
        "car_fuel_percent": car_fuel_percent,
        "bike_fuel_percent": bike_fuel_percent,
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
    shop_upgrade_level = clampi(int(parsed.get("shop_upgrade_level", 0)), 0, 2)
    shop_upgrade_investment = maxi(0, int(parsed.get("shop_upgrade_investment", 0)))
    shop_stock_units = clampi(int(parsed.get("shop_stock_units", 25 if shop_owned else 0)), 0, 100)
    uncollected_shop_income = maxi(0, int(parsed.get("uncollected_shop_income", parsed.get("business_cashflow", 0))))
    missions_completed = maxi(0, int(parsed.get("missions_completed", 0)))
    missions_failed = maxi(0, int(parsed.get("missions_failed", 0)))
    active_job_time_limit = maxf(0.0, float(parsed.get("active_job_time_limit", 0.0)))
    active_job_time_remaining = clampf(float(parsed.get("active_job_time_remaining", 0.0)), 0.0, active_job_time_limit)
    player_level = clampi(int(parsed.get("player_level", 1)), 1, 20)
    player_xp = clampi(int(parsed.get("player_xp", 0)), 0, maxi(0, xp_to_next_level() - 1))
    shares_mtr = maxi(0, int(parsed.get("shares_mtr", 0)))
    shares_nre = maxi(0, int(parsed.get("shares_nre", 0)))
    shares_ncr = maxi(0, int(parsed.get("shares_ncr", 0)))
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
    # Older saves predate mission deadlines. Give an already-active legacy job
    # its normal time allowance instead of expiring it immediately on upgrade.
    if active_job_stage > 0 and active_job_time_limit <= 0.0:
        active_job_time_limit = job_time_limit_for(active_job_title)
        active_job_time_remaining = active_job_time_limit
    car_fuel_percent = clampf(float(parsed.get("car_fuel_percent", parsed.get("fuel_percent", 100.0))), 0.0, 100.0)
    bike_fuel_percent = clampf(float(parsed.get("bike_fuel_percent", 100.0)), 0.0, 100.0)
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
