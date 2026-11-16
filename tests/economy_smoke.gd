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

    assert(state.buy_home(), "Starter home purchase should succeed.")
    assert(state.home_owned and state.wallet == 1700, "Home purchase should deduct ₹3,000.")
    state.wallet = 5000
    assert(state.buy_bike(), "Motorbike purchase should succeed.")
    assert(state.bike_owned and state.wallet == 2500, "Motorbike purchase should deduct ₹2,500.")
    state.wallet = 5000
    assert(state.buy_shop(), "Corner shop purchase should succeed.")
    assert(state.shop_owned and state.wallet == 1000, "Shop purchase should deduct ₹4,000.")
    assert(state.hire_shop_employee(), "A shop owner should be able to hire staff.")
    assert(state.shop_employee_count == 1 and state.wallet == 500, "Hiring an employee should deduct ₹500.")

    state.advance_day()
    assert(state.uncollected_shop_income == 350, "A staffed shop should accrue ₹350 per day.")
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

    state.set_player_position(Vector3(3.0, 1.0, 9.0))
    state.set_vehicle_state("motorbike", Vector3(12.0, 0.58, 24.0), 1.2, true)
    state.save_game()
    var restored = GameStateScript.new()
    restored.load_game()
    assert(restored.wallet == state.wallet, "Wallet should persist.")
    assert(restored.bank_balance == state.bank_balance, "Bank balance should persist.")
    assert(restored.home_owned and restored.shop_owned, "Owned assets should persist.")
    assert(restored.shop_employee_count == 1, "Shop staffing should persist.")
    assert(restored.bike_owned, "Motorbike ownership should persist.")
    assert(restored.day_number == state.day_number, "Day count should persist.")
    assert(restored.missions_completed == 1, "Mission completion count should persist.")
    assert(restored.was_driving, "Active driving state should persist.")
    assert(restored.active_vehicle_kind == "motorbike", "Active vehicle type should persist.")
    assert(restored.bike_position.is_equal_approx(Vector3(12.0, 0.58, 24.0)), "Motorbike position should persist.")
    assert(is_equal_approx(restored.bike_rotation_y, 1.2), "Motorbike rotation should persist.")
    assert(restored.player_position.is_equal_approx(Vector3(3.0, 1.0, 9.0)), "Player position should persist.")
    assert(is_equal_approx(restored.fuel_percent, 87.5), "Fuel level should persist.")
    print("LIFE EMPIRE economy, mission, vehicle and fuel tests passed.")
    quit(0)
