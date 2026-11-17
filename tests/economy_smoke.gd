extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")

func _initialize() -> void:
    var state = GameStateScript.new()
    state.wallet = 5000
    state.bank_balance = 0
    state.lifetime_earnings = 0
    state.missions_completed = 0
    state.day_number = 1
    state.home_owned = false
    state.shop_owned = false
    state.uncollected_shop_income = 0
    state.transactions.clear()

    assert(state.deposit(500), "Deposit should succeed with sufficient wallet balance.")
    assert(state.wallet == 4500 and state.bank_balance == 500, "Deposit should transfer, not create, money.")
    assert(state.withdraw(200), "Withdrawal should succeed with sufficient bank balance.")
    assert(state.wallet == 4700 and state.bank_balance == 300, "Withdrawal should move money back to wallet.")
    assert(state.take_loan(2000), "The bank should issue a loan within its limit.")
    assert(state.wallet == 6700 and state.loan_balance == 2000, "Loan proceeds should reach the wallet and create an equal liability.")
    assert(state.net_worth() == 5000, "Borrowing money should not increase net worth.")
    assert(not state.take_loan(1000), "The bank should not issue a second loan while one is outstanding.")
    assert(state.repay_loan(500), "A partial loan repayment should succeed.")
    assert(state.wallet == 6200 and state.loan_balance == 1500, "Loan repayment should reduce wallet and debt equally.")
    assert(state.net_worth() == 5000, "Repaying principal should not change net worth.")

    assert(state.buy_home(), "Starter home purchase should succeed.")
    assert(state.home_owned and state.wallet == 3200, "Home purchase should deduct ₹3,000.")
    state.wallet = 5000
    assert(state.buy_bike(), "Motorbike purchase should succeed.")
    assert(state.bike_owned and state.wallet == 2500, "Motorbike purchase should deduct ₹2,500.")
    state.wallet = 5000
    assert(state.buy_shop(), "Corner shop purchase should succeed.")
    assert(state.shop_owned and state.wallet == 1000, "Shop purchase should deduct ₹4,000.")
    assert(state.shop_stock_units == 25, "A new shop should open with starter inventory.")
    assert(state.hire_shop_employee(), "A shop owner should be able to hire staff.")
    assert(state.shop_employee_count == 1 and state.wallet == 500, "Hiring an employee should deduct ₹500.")

    state.advance_day()
    assert(state.uncollected_shop_income == 350, "A staffed shop should accrue ₹350 per day.")
    assert(state.shop_stock_units == 18, "The shop should sell seven units with one employee.")
    assert(state.loan_balance == 1530, "A new day should add 2% daily loan interest, rounded up.")
    assert(state.collect_shop_income(), "Shop income should be collectible.")
    assert(state.wallet == 850 and state.uncollected_shop_income == 0, "Collected income should reach wallet exactly once.")

    state.complete_mission(650, "Food delivery")
    assert(state.wallet == 1500, "Mission reward should increase wallet.")
    assert(state.missions_completed == 1, "Mission completion should increment the progression counter.")

    state.fuel_percent = 35.0
    assert(state.refuel_vehicle(), "Refuelling should succeed when the player has ₹300.")
    assert(state.wallet == 1200 and is_equal_approx(state.fuel_percent, 100.0), "Refuelling should deduct ₹300 and restore full fuel.")
    state.consume_fuel(12.5)
    assert(is_equal_approx(state.fuel_percent, 87.5), "Driving should consume fuel without going negative.")

    state.game_minutes = 1439.0
    var previous_day: int = state.day_number
    state.advance_clock(2.0)
    assert(state.day_number == previous_day + 1, "The simulation clock should roll into the next day.")
    assert(is_equal_approx(state.game_minutes, 1.0), "The simulation clock should wrap to the start of the new day.")
    assert(state.uncollected_shop_income == 350, "The shop should accrue its daily income automatically at day rollover.")
    assert(state.shop_stock_units == 11, "Automatic day rollover should consume shop stock.")
    assert(state.loan_balance == 1561, "Daily loan interest should compound at automatic day rollover.")
    assert(state.clock_text() == "12:01 AM", "The in-game clock should display the correct 12-hour time.")
    assert(state.hunger_percent < 100.0 and state.energy_percent < 100.0, "Needs should gradually decrease as simulation time passes.")
    state.hunger_percent = 40.0
    assert(state.buy_meal(), "A meal should be purchasable when the player can afford it.")
    assert(state.wallet == 1100 and is_equal_approx(state.hunger_percent, 85.0), "A meal should deduct ₹100 and restore 45 hunger points.")
    state.energy_percent = 30.0
    assert(not state.sleep_at_home(), "Sleeping should be unavailable outside the home.")
    state.inside_home = true
    assert(state.sleep_at_home(), "An owner inside the home should be able to sleep.")
    assert(state.day_number == previous_day + 2, "Sleeping should advance one day.")
    assert(is_equal_approx(state.game_minutes, 480.0), "Sleeping should set the clock to 8:00 AM.")
    assert(is_equal_approx(state.energy_percent, 100.0), "Sleeping should fully restore energy.")
    assert(is_equal_approx(state.hunger_percent, 70.0), "Sleeping should consume 15 hunger points.")
    assert(state.restock_shop(), "A shop owner should be able to purchase more stock.")
    assert(state.wallet == 800 and state.shop_stock_units == 24, "Restocking should cost ₹300 and add 20 units.")
    assert(state.uncollected_shop_income == 700, "Daily business income should accrue on each full day.")
    assert(state.shop_stock_units == 4, "The shop should have four units left after three trading days.")
    assert(state.loan_balance == 1593, "Loan interest should accrue when sleeping advances a day.")

    state.set_player_position(Vector3(150.0, 1.0, 150.0))
    state.inside_home = true
    state.home_return_position = Vector3(100.0, 1.0, 98.0)
    state.set_vehicle_state("motorbike", Vector3(12.0, 0.58, 24.0), 1.2, true)
    state.active_job_stage = 2
    state.active_job_title = "Food delivery"
    state.active_job_reward = 650
    state.active_job_pickup_position = Vector3(-16.0, 0.85, 0.0)
    state.active_job_destination_position = Vector3(0.0, 0.85, 40.0)
    state.save_game()
    var restored = GameStateScript.new()
    restored.load_game()
    assert(restored.wallet == state.wallet, "Wallet should persist.")
    assert(restored.bank_balance == state.bank_balance, "Bank balance should persist.")
    assert(restored.loan_balance == 1593, "Outstanding loan should persist.")
    assert(restored.home_owned and restored.shop_owned, "Owned assets should persist.")
    assert(restored.inside_home, "The saved home interior state should persist.")
    assert(restored.home_return_position.is_equal_approx(Vector3(100.0, 1.0, 98.0)), "The front-door return position should persist.")
    assert(restored.shop_employee_count == 1, "Shop staffing should persist.")
    assert(restored.shop_stock_units == 24, "Shop inventory should persist.")
    assert(restored.bike_owned, "Motorbike ownership should persist.")
    assert(restored.day_number == state.day_number, "Day count should persist.")
    assert(is_equal_approx(restored.game_minutes, 480.0), "In-game time should persist.")
    assert(restored.clock_text() == "08:00 AM", "The saved clock should restore its formatted time.")
    assert(is_equal_approx(restored.hunger_percent, 70.0), "Hunger should persist after reload.")
    assert(is_equal_approx(restored.energy_percent, 100.0), "Energy should persist after reload.")
    assert(restored.missions_completed == 1, "Mission completion count should persist.")
    assert(restored.active_job_stage == 2, "Active mission delivery stage should persist.")
    assert(restored.active_job_title == "Food delivery", "Active mission title should persist.")
    assert(restored.active_job_reward == 650, "Active mission reward should persist.")
    assert(restored.active_job_pickup_position.is_equal_approx(Vector3(-16.0, 0.85, 0.0)), "Mission pickup location should persist.")
    assert(restored.active_job_destination_position.is_equal_approx(Vector3(0.0, 0.85, 40.0)), "Mission destination should persist.")
    assert(restored.was_driving, "Active driving state should persist.")
    assert(restored.active_vehicle_kind == "motorbike", "Active vehicle type should persist.")
    assert(restored.bike_position.is_equal_approx(Vector3(12.0, 0.58, 24.0)), "Motorbike position should persist.")
    assert(is_equal_approx(restored.bike_rotation_y, 1.2), "Motorbike rotation should persist.")
    assert(restored.player_position.is_equal_approx(Vector3(150.0, 1.0, 150.0)), "Interior player position should persist.")
    assert(is_equal_approx(restored.fuel_percent, 87.5), "Fuel level should persist.")
    print("LIFE EMPIRE economy, mission, vehicle and fuel tests passed.")
    quit(0)
