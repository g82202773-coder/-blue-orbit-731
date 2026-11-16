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
    assert(state.buy_shop(), "Corner shop purchase should succeed.")
    assert(state.shop_owned and state.wallet == 1000, "Shop purchase should deduct ₹4,000.")

    state.advance_day()
    assert(state.uncollected_shop_income == 250, "Owned shop should accrue ₹250 per day.")
    assert(state.collect_shop_income(), "Shop income should be collectible.")
    assert(state.wallet == 1250 and state.uncollected_shop_income == 0, "Collected income should reach wallet exactly once.")

    state.complete_mission(650, "Food delivery")
    assert(state.wallet == 1900, "Mission reward should increase wallet.")
    assert(state.missions_completed == 1, "Mission completion should increment the progression counter.")

    state.save_game()
    var restored = GameStateScript.new()
    restored.load_game()
    assert(restored.wallet == state.wallet, "Wallet should persist.")
    assert(restored.bank_balance == state.bank_balance, "Bank balance should persist.")
    assert(restored.home_owned and restored.shop_owned, "Owned assets should persist.")
    assert(restored.day_number == state.day_number, "Day count should persist.")
    assert(restored.missions_completed == 1, "Mission completion count should persist.")
    print("LIFE EMPIRE economy and mission tests passed.")
    quit(0)
