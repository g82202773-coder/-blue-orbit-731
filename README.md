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
- Enterable arcade-style starter car with acceleration, braking, reverse and steering.
- Three lightweight moving traffic cars and four looping pedestrians.
- Delivery mission with pickup/drop-off markers and ₹750 reward.
- Fictional wallet and bank with ₹500 deposit/withdraw actions and recent transaction records.
- Starter home and corner-shop purchases, daily shop income, and collect-income action.
- Offline JSON save/load, 20-second autosave, and Android application-pause saving.

## Development status
This repository is the clean source-of-truth for the new LIFE EMPIRE project. Features are added incrementally and must be distinguished as implemented, CI-tested, or device-tested. The Godot 4.7 GitHub Actions import/parse and 120-frame headless scene smoke test has passed. No Android APK or release is considered verified until it has been exported and tested on a physical device.

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
7. Optimization, Android export configuration, and device QA.

## Controls (desktop testing)
- WASD: Move / steer
- Shift: Run
- E: Interact / enter or exit vehicle
- Esc: Close panels

All currency is fictional in-game currency. No real banking or payments are integrated.
