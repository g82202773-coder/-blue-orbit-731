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
    assert(not state.hire_shop_employee(), "Hiring should require visiting the shop.")
    state.inside_shop = true
    assert(state.hire_shop_employee(), "A shop owner inside the store should be able to hire staff.")
    assert(state.shop_employee_count == 1 and state.wallet == 500, "Hiring an employee should deduct ₹500.")
    state.inside_shop = false

    state.advance_day()
    assert(state.uncollected_shop_income == 350, "A staffed shop should accrue ₹350 per day.")
    assert(state.shop_stock_units == 18, "The shop should sell seven units with one employee.")
    assert(state.loan_balance == 1530, "A new day should add 2% daily loan interest, rounded up.")
    assert(not state.collect_shop_income(), "Collecting revenue should require visiting the shop.")
    state.inside_shop = true
    assert(state.collect_shop_income(), "A player inside the shop should be able to collect revenue.")
    assert(state.wallet == 850 and state.uncollected_shop_income == 0, "Collected income should reach wallet exactly once.")
    state.inside_shop = false

    state.complete_mission(650, "Food delivery")
    assert(state.wallet == 1500, "Mission reward should increase wallet.")
    assert(state.missions_completed == 1, "Mission completion should increment the progression counter.")
    assert(state.player_level == 1 and state.player_xp == 33, "A ₹650 job should award 33 XP without prematurely levelling up.")
    assert(not state.can_accept_job("Courier parcel"), "Courier work should remain locked below Level 2.")
    assert(state.required_level_for_job("Heavy cargo") == 3, "Heavy cargo should be a higher-tier job.")
    state.add_job_experience(67)
    assert(state.player_level == 2 and state.player_xp == 0, "Reaching 100 XP should advance the player to Level 2.")
    assert(state.can_accept_job("Courier parcel"), "Courier work should unlock at Level 2.")
    assert(not state.can_accept_job("Heavy cargo"), "Heavy cargo should stay locked until Level 3.")
    assert(state.xp_to_next_level() == 200, "The XP requirement should increase with the player level.")

    state.fuel_percent = 35.0
    assert(state.refuel_vehicle(), "Refuelling should succeed when the player has ₹300.")
    assert(state.wallet == 1200 and is_equal_approx(state.fuel_percent, 100.0), "Refuelling should deduct ₹300 and restore full fuel.")
    state.consume_fuel(12.5)
    assert(is_equal_approx(state.car_fuel_percent, 87.5), "Driving should consume the car's own fuel tank.")
    state.consume_fuel(10.0, "motorbike")
    assert(is_equal_approx(state.bike_fuel_percent, 90.0), "Driving the motorbike should consume its separate tank.")
    assert(is_equal_approx(state.car_fuel_percent, 87.5), "Motorbike fuel use should not change car fuel.")
    state.consume_vehicle_condition("car", 5.0)
    assert(is_equal_approx(state.vehicle_condition("car"), 95.0), "Driving should gradually reduce car condition.")
    assert(state.repair_vehicle("car"), "A damaged vehicle should be serviceable when the player can afford the cost.")
    assert(state.wallet == 1100 and is_equal_approx(state.vehicle_condition("car"), 100.0), "Servicing a car at 95% condition should cost ₹100 and restore it.")
    state.consume_vehicle_condition("motorbike", 10.0)
    assert(is_equal_approx(state.vehicle_condition("motorbike"), 90.0), "Motorbike condition should be tracked separately.")

    var bike_refuel_state = GameStateScript.new()
    bike_refuel_state.wallet = 500
    bike_refuel_state.car_fuel_percent = 77.0
    bike_refuel_state.bike_fuel_percent = 30.0
    assert(bike_refuel_state.refuel_vehicle("motorbike"), "A motorbike should be refuellable independently.")
    assert(bike_refuel_state.wallet == 200 and is_equal_approx(bike_refuel_state.bike_fuel_percent, 100.0), "Motorbike refuelling should deduct ₹300 and fill only the bike tank.")
    assert(is_equal_approx(bike_refuel_state.car_fuel_percent, 77.0), "Motorbike refuelling should leave the car tank unchanged.")

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
    assert(state.wallet == 1000 and is_equal_approx(state.hunger_percent, 85.0), "A meal should deduct ₹100 and restore 45 hunger points.")
    state.energy_percent = 30.0
    assert(not state.sleep_at_home(), "Sleeping should be unavailable outside the home.")
    state.inside_home = true
    assert(state.sleep_at_home(), "An owner inside the home should be able to sleep.")
    assert(state.day_number == previous_day + 2, "Sleeping should advance one day.")
    assert(is_equal_approx(state.game_minutes, 480.0), "Sleeping should set the clock to 8:00 AM.")
    assert(is_equal_approx(state.energy_percent, 100.0), "Sleeping should fully restore energy.")
    assert(is_equal_approx(state.hunger_percent, 70.0), "Sleeping should consume 15 hunger points.")
    assert(state.shop_stock_units == 4, "The shop should have four units left after three trading days.")
    assert(not state.restock_shop(), "Restocking should be blocked while outside the shop.")
    state.inside_home = false
    state.inside_shop = true
    state.shop_return_position = Vector3(-20.0, 1.0, -68.0)
    var net_worth_before_restock: int = state.net_worth()
    assert(state.restock_shop(), "A shop owner inside the store should be able to purchase more stock.")
    assert(state.wallet == 700 and state.shop_stock_units == 24, "Restocking should cost ₹300 and add 20 units.")
    assert(state.net_worth() == net_worth_before_restock, "Restocking should transfer value from cash to inventory without changing net worth.")
    assert(state.uncollected_shop_income == 700, "Daily business income should accrue on each full day.")
    assert(state.loan_balance == 1593, "Loan interest should accrue when sleeping advances a day.")

    state.set_player_position(Vector3(150.0, 1.0, 150.0))
    state.inside_shop = false
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
    assert(not restored.inside_shop, "Entering the home should clear the shop interior state.")
    assert(restored.shop_return_position.is_equal_approx(Vector3(-20.0, 1.0, -68.0)), "The shop return position should persist.")
    assert(restored.shop_employee_count == 1, "Shop staffing should persist.")
    assert(restored.shop_stock_units == 24, "Shop inventory should persist.")
    assert(restored.bike_owned, "Motorbike ownership should persist.")
    assert(restored.day_number == state.day_number, "Day count should persist.")
    assert(is_equal_approx(restored.game_minutes, 480.0), "In-game time should persist.")
    assert(restored.clock_text() == "08:00 AM", "The saved clock should restore its formatted time.")
    assert(is_equal_approx(restored.hunger_percent, 70.0), "Hunger should persist after reload.")
    assert(is_equal_approx(restored.energy_percent, 100.0), "Energy should persist after reload.")
    assert(restored.missions_completed == 1, "Mission completion count should persist.")
    assert(restored.player_level == 2 and restored.player_xp == 0, "Player level and XP should persist.")
    assert(restored.can_accept_job("Courier parcel"), "Unlocked job tiers should remain unlocked after reload.")
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
    assert(is_equal_approx(restored.car_fuel_percent, 87.5), "Car fuel level should persist.")
    assert(is_equal_approx(restored.bike_fuel_percent, 90.0), "Motorbike fuel level should persist separately.")
    assert(is_equal_approx(restored.car_condition_percent, 100.0), "Repaired car condition should persist.")
    assert(is_equal_approx(restored.bike_condition_percent, 90.0), "Motorbike wear should persist independently.")

    # Rental apartment portfolio, daily rent ledger, in-property collection and sleep.
    var apartment_state = GameStateScript.new()
    apartment_state.wallet = 10000
    apartment_state.bank_balance = 0
    apartment_state.loan_balance = 0
    apartment_state.day_number = 1
    apartment_state.apartment_owned = false
    apartment_state.inside_apartment = false
    apartment_state.uncollected_apartment_rent = 0
    apartment_state.transactions.clear()
    var apartment_starting_net_worth: int = apartment_state.net_worth()
    assert(apartment_state.buy_apartment(), "The rental apartment should be purchasable.")
    assert(apartment_state.wallet == 2000 and apartment_state.apartment_owned, "The apartment should cost ₹8,000.")
    assert(apartment_state.net_worth() == apartment_starting_net_worth, "Buying the apartment should transfer cash into an asset without creating net worth.")
    apartment_state.advance_day()
    assert(apartment_state.day_number == 2 and apartment_state.uncollected_apartment_rent == 200, "The owned apartment should accrue ₹200 rent each new day.")
    assert(not apartment_state.collect_apartment_rent(), "Apartment rent should not be collectible from outside.")
    apartment_state.inside_apartment = true
    apartment_state.apartment_return_position = Vector3(100.0, 1.0, -68.0)
    var apartment_value_with_rent: int = apartment_state.net_worth()
    assert(apartment_state.collect_apartment_rent(), "Apartment rent should be collectible from inside the apartment.")
    assert(apartment_state.wallet == 2200 and apartment_state.uncollected_apartment_rent == 0, "Collected rent should transfer into the wallet exactly once.")
    assert(apartment_state.net_worth() == apartment_value_with_rent, "Collecting rent should not change total net worth.")
    apartment_state.energy_percent = 20.0
    apartment_state.hunger_percent = 80.0
    assert(apartment_state.sleep_at_home(), "An apartment owner should be able to sleep inside the apartment.")
    assert(apartment_state.day_number == 3 and apartment_state.energy_percent == 100.0, "Apartment sleep should advance the day and restore energy.")
    assert(apartment_state.uncollected_apartment_rent == 200, "A new day should accrue the next ₹200 rent payment.")
    apartment_state.save_game()
    var apartment_restored = GameStateScript.new()
    apartment_restored.load_game()
    assert(apartment_restored.apartment_owned and apartment_restored.inside_apartment, "Apartment ownership and interior state should persist.")
    assert(apartment_restored.apartment_return_position.is_equal_approx(Vector3(100.0, 1.0, -68.0)), "Apartment return position should persist.")
    assert(apartment_restored.uncollected_apartment_rent == 200, "Uncollected apartment rent should persist.")

    # Timed delivery countdown, on-time bonus, timeout failure and active-job restore.
    var timed_state = GameStateScript.new()
    timed_state.wallet = 500
    timed_state.active_job_stage = 1
    timed_state.active_job_title = "Food delivery"
    timed_state.active_job_reward = 650
    timed_state.start_job_timer(120.0)
    timed_state.advance_clock(30.0)
    assert(is_equal_approx(timed_state.active_job_time_remaining, 90.0), "Mission countdown should decrease with real gameplay time.")
    assert(timed_state.job_timer_text() == "01:30", "Mission countdown should format as minutes and seconds.")
    timed_state.active_job_stage = 0
    timed_state.active_job_title = ""
    timed_state.active_job_reward = 0
    var timed_payout: int = timed_state.complete_mission(650, "Food delivery")
    assert(timed_payout == 723, "Mission completion should return the base reward plus a proportional 15% time bonus.")
    assert(timed_state.wallet == 1223, "The wallet should receive the returned mission payout.")
    assert(timed_state.active_job_time_remaining == 0.0 and timed_state.missions_completed == 1, "Mission completion should clear its timer and increment the counter.")

    timed_state.active_job_stage = 1
    timed_state.active_job_title = "Taxi passenger"
    timed_state.active_job_reward = 500
    timed_state.start_job_timer(5.0)
    timed_state.advance_clock(5.0)
    assert(timed_state.active_job_time_remaining == 0.0, "An expired mission countdown should reach zero.")
    timed_state.fail_active_mission()
    assert(timed_state.missions_failed == 1 and timed_state.active_job_stage == 0, "An expired job should be marked failed and cleared.")
    assert(timed_state.wallet == 1223, "A failed job should not pay a reward.")

    timed_state.active_job_stage = 1
    timed_state.active_job_title = "Courier parcel"
    timed_state.active_job_reward = 900
    timed_state.start_job_timer(180.0)
    timed_state.advance_clock(30.0)
    timed_state.save_game()
    var timed_restored = GameStateScript.new()
    timed_restored.load_game()
    assert(timed_restored.active_job_stage == 1 and timed_restored.active_job_title == "Courier parcel", "An active timed mission should persist.")
    assert(is_equal_approx(timed_restored.active_job_time_remaining, 150.0), "Remaining mission time should persist.")
    assert(is_equal_approx(timed_restored.active_job_time_limit, 180.0), "Original mission time limit should persist.")
    assert(timed_restored.missions_failed == 1, "Failed mission count should persist.")
    print("LIFE EMPIRE economy, property, timed missions, vehicle and fuel tests passed.")
    quit(0)
