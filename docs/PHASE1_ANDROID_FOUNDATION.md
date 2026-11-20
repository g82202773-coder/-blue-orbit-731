# Phase 1 — Android Foundation Audit

**Baseline audited:** 2026-11-20  
**Repository:** `g82202773-coder/-blue-orbit-731`  
**Baseline commit:** `e509769a94caf133e50f6e821da80810424db162`

## Existing foundation

The existing LIFE EMPIRE project is a Godot 4.7 GDScript game using the GL Compatibility renderer and a 1280×720 landscape logical viewport. The project is Android-first and offline-first.

The existing implementation already contains:
- Procedural Navapura city construction in `scripts/main.gd`.
- Persistent player/economy state in the `GameState` autoload.
- On-foot movement, touch controls, vehicle entry and driving.
- Traffic and pedestrian simulation.
- Jobs, wallet, bank, loans, property, shop, shares and save/load.
- Existing economy, scene and world-interaction smoke tests.
- Godot validation and Android debug APK GitHub Actions workflows.

## Current architectural risks

1. **Monolithic gameplay controller:** `scripts/main.gd` is approximately 135 KB and owns world construction, player/vehicle setup, UI and multiple interactions. This raises change-coupling and regression risk.
2. **Single state authority:** `GameState` is a large autoload. It should remain the source of truth for persistent simulation state, but new features should use narrow methods and typed data rather than adding unrelated responsibilities.
3. **Verification boundary:** CI can prove import/parse, headless smoke tests and APK packaging. It cannot prove real-device GPU performance, thermal stability, touch feel or visual quality.
4. **Performance evidence:** the project has an FPS/scale overlay and mobile optimizations, but a reproducible physical-device benchmark report is still required before claiming the 30 FPS target.
5. **Asset pipeline:** procedural geometry is useful for iteration, but production realism will require validated modular meshes, texture/material budgets, LODs and collision proxies.

## Phase 1 architecture rules

- Preserve the existing playable game and save-file compatibility.
- Keep Godot 4.7 and GL Compatibility as the Android baseline.
- Keep landscape orientation and the existing main scene entry point.
- Do not rewrite the monolithic controller in one operation.
- Extract one bounded subsystem at a time behind stable interfaces.
- Keep persistent state changes inside `GameState`; expose operations through methods/signals.
- Prefer data-driven resources for vehicles, jobs, properties and building definitions.
- Keep world generation deterministic from a stored seed where practical.
- Reuse meshes/materials and use MultiMesh for repeated static detail.
- Use distance/visibility gating for NPC logic and expensive scene updates.
- Require a smoke test for each extracted subsystem and a regression run before integration.
- Never report FPS, memory or physical-device success without captured measurements.

## Phase 1 automated acceptance

The new `tests/project_foundation_smoke.gd` checks:
- Project name and main-scene entry point.
- Godot 4.7 and GL Compatibility declarations.
- Mobile GL Compatibility renderer.
- Landscape Android orientation.
- Canonical GameState autoload.
- Presence of the existing core scenes, scripts and regression tests.

The Godot validation workflow runs this test alongside the existing economy, world and startup checks. The Android APK workflow runs it before exporting.

## Phase 1 manual Android acceptance

These checks require the user's Android device and cannot be truthfully completed from GitHub source inspection alone:

- Install the newly built debug APK.
- Launch and confirm the game renders in landscape.
- Verify touch movement, running, interaction, vehicle entry/exit and driving.
- Verify save → force-close → relaunch → restore.
- Record FPS during a repeatable walking and driving route.
- Record Android memory use, device temperature and any thermal throttling.
- Capture screenshots at the same fixed locations for visual regression.

## Next engineering sequence

1. Establish the Phase 1 foundation checks.
2. Add a repeatable Android performance benchmark and report format.
3. Extract player controls and interaction routing from `main.gd`.
4. Extract vehicle definitions/handling behind a vehicle subsystem.
5. Extract city district/building definitions into data-driven resources.
6. Add subsystem-level tests before expanding assets or NPC counts.

**Status:** source audit completed; Phase 1 code changes await CI validation and physical Android verification.
