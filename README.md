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

## Development status
This repository is the clean source-of-truth for the new LIFE EMPIRE project. Features are added incrementally and must be distinguished as implemented, locally tested, or device-tested. No APK or release is considered verified until it has been built and tested.

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
