# LIFE EMPIRE

A landscape, offline-first 3D open-world life and business simulator set in the fictional Indian-inspired city of Navapura.

## Project goals
- Playable third-person exploration and vehicle driving.
- Delivery jobs and a persistent fictional economy.
- Wallet, bank, transaction history, properties, and businesses.
- In-game smartphone, map, garage, and progression.
- Android-first controls and performance budget for 4 GB RAM devices.

## Engine
- Godot Engine 4.7
- GDScript
- Mobile renderer: GL Compatibility
- Landscape orientation; 1280x720 logical viewport

## Current playable foundation
- Procedurally generated Navapura city sector with connected roads, junction-separated sidewalks, lane dashes, zebra crossings, storefronts, facade windows, streetlights and trees.
- GPU-instanced repeated facade windows and road markings to reduce draw-call overhead.
- More detailed low-poly player and starter-car models.
- Responsive landscape HUD that repositions for ultrawide Android screens.
- 60 FPS ceiling with adaptive 3D resolution scaling and an on-screen FPS/scale monitor.
- Third-person on-foot movement, walking/running, and touch D-pad controls.
- Enterable starter car and purchasable commuter motorbike, with separate arcade handling, acceleration, braking, reverse and steering.
- Vehicle ownership, transforms and active driving state persist across app restarts.
- Fuel consumption while driving and a ₹300 phone-based refuelling action.
- Separate car/motorbike condition wear, reduced performance on worn vehicles, and proximity-gated service with damage-based repair pricing.
- Three lightweight moving traffic cars and four looping pedestrians.
- Rental apartment priced at ₹8,000 with a furnished interior, ₹200 daily rent, inside-apartment rent collection and sleep support; apartment value and uncollected rent appear in net worth.
- Job board with food delivery (₹650), taxi pickup (₹500), courier parcel (₹900) and heavy cargo (₹1,600) missions, each with separate pickup/drop-off routes.
- Job progression with XP rewards, persistent player levels, Level 2 courier unlock and Level 3 heavy-cargo unlock.
- Timed deliveries with mission-specific deadlines, failure on timeout, saved countdowns and up to 15% proportional on-time payout bonuses; the completion screen reports the final payout.
- Persistent completed-job counter and mission reward history.
- Fictional wallet and bank with ₹500 deposit/withdraw actions, loans up to ₹5,000, ₹500 repayments, 2% daily compounding interest, debt-aware net worth, and recent transaction records.
- Purchasable starter home physically placed in Navapura with a furnished bedroom/living/kitchen interior, front-door entry/exit, home signage, and a sleep action that works only while inside.
- Rental apartment property priced at ₹8,000, physically placed and enterable, with a furnished interior, ₹200 daily rent, inside-apartment rent collection, sleep support and saved ownership/rent balance.
- Corner-shop business with 25 starter stock units, daily sales affected by staff count, ₹300 restocking for 20 units, inventory valuation in net worth, and collect-income action.
- Persistent in-game clock (one game minute per real second), day rollover, daily shop income accrual, and a continuous day/night sky and lighting cycle.
- Survival needs: hunger and energy gradually decline; walking/running drains extra energy, meals restore hunger, and sleeping inside an owned home or apartment restores energy and advances the day.
- Active mission progress, pickup/drop-off positions, home and apartment interior/return positions, property ownership/rent, vehicle state, simulation time, needs, loans and economy persist through offline JSON save/load, 20-second autosave, and Android application-pause saving.

## Development status
This repository is the source of truth for LIFE EMPIRE. Features are added incrementally and must be distinguished as implemented, CI-tested, or device-tested. The last verified Android emulator launch/screenshot baseline is commit `47f83950`; later additions (including the apartment portfolio, timed jobs and vehicle maintenance) still require a fresh successful Godot validation and APK/emulator run. GitHub Actions has recently been failing before exposing runner logs, so the current development head must not be treated as a verified APK. No Android release is considered physically device-tested until it has been installed and exercised on a real phone.

## Performance principles
- Target 30 FPS on baseline Android devices.
- Small streamed/sector-based world rather than one enormous scene.
- Reuse meshes and materials; avoid excessive real-time lights and shadows.
- Cap active traffic and NPC counts.
- Use simple collision geometry and distance-based detail reduction.

## Roadmap
1. Core project, generated city block, player movement, touch controls.
2. Vehicle entry/exit and collision-aware driving.
3. Jobs, rewards, wallet, bank, transaction history, and save/load.
4. Smartphone UI and map/garage apps.
5. Traffic, pedestrian simulation, and city sectors.
6. Properties, businesses, employees, and recurring income.
7. Dynamic world simulation, persistent missions, and progression systems.
8. Optimization, Android export configuration, emulator QA, and physical-device QA.

## Controls (desktop testing)
- WASD: Move / steer
- Shift: Run
- E: Interact / enter or exit vehicle
- Esc: Close panels

All currency is fictional in-game currency. No real banking or payments are integrated.
