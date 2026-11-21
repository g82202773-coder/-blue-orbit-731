# LIFE EMPIRE — November 30 Release Plan

**Target date:** 2026-11-30  
**Release branch:** `release/november-2026`  
**Engine baseline:** Godot 4.7, GL Compatibility, Android landscape

## Release definition

The November target is a compact, stable, offline-first Android playable release. It is not a promise of a fully simulated 1–2 km² production-scale city. The release must preserve the existing save format and keep the default `main` branch untouched until acceptance gates pass.

## Existing systems found in the imported source

- Procedural Navapura city and landmarks.
- Third-person walking/running and touch controls.
- Starter car and purchasable motorbike.
- Traffic and pedestrian loops.
- Delivery, taxi, courier and heavy-cargo job flows.
- Wallet, bank, loans, shares, properties and shop progression.
- Fuel, vehicle condition, repair and refuelling.
- Day/night clock, hunger/energy, sleep and meals.
- Enterable home, apartment, shop, mall, showroom, office lobby and market.
- JSON save/load and periodic autosave.

These are source-level findings, not proof that every flow currently works in a built Android app.

## Release gates — must all be checked

1. **Import and parse:** Godot 4.7 imports the project without script parse errors or missing resources.
2. **Headless regression:** foundation, economy, scene and world interaction smoke tests pass.
3. **Android package:** a debug APK exports successfully with the configured Android preset.
4. **Install and launch:** install on a physical Android phone; confirm landscape launch, no startup crash and readable HUD.
5. **Core gameplay:** test walking, running, interaction, car/bike enter/exit, driving, collision, jobs and reward settlement.
6. **Economy and persistence:** test wallet/bank/property/shop operations; save, force-close, relaunch and verify restored state.
7. **Performance:** measure a repeatable walking and driving route; target stable 30 FPS on the agreed baseline device. Record device model, Android version, FPS, memory and temperature. Do not infer performance from editor or CI results.
8. **Release hygiene:** inspect logs, remove blockers, retain known-issues list and only then merge the release branch.

## Time-boxed execution order

- **Nov 21–22:** unblock an executable validation route; establish reproducible Godot import, parse and smoke-test results.
- **Nov 23–24:** fix confirmed startup, scene, input, save/load and economy regressions.
- **Nov 25–26:** produce Android debug APK; run physical-device installation and touch-control QA.
- **Nov 27–28:** profile the city; optimize only measured hotspots; verify 30 FPS target where device evidence supports it.
- **Nov 29:** regression pass, known-issues review and release candidate.
- **Nov 30:** release decision. Ship only if critical gates pass; otherwise publish a tested playable build with clearly documented limitations rather than claiming a complete game.

## Current blockers

- GitLab creates push pipelines but marks them failed before creating any jobs; job list is empty. The account-level identity-verification gate still blocks pipeline execution.
- No successful Godot test run is recorded for this imported branch.
- No APK has been exported from this new GitLab project.
- No current physical-device performance or save/reload report is available.

## Engineering rules

- Do not rewrite the 135 KB gameplay controller in one pass.
- Make bounded changes and add regression coverage.
- Keep persistent simulation state in the GameState autoload.
- Keep the existing Godot version, renderer, orientation and main-scene entry point.
- Do not merge to `main` or claim FPS/build success without evidence.
