# Build and QA guide

## Open the project
1. Download the repository as a ZIP or clone it.
2. Open the folder containing `project.godot` in Godot 4.7.
3. Let the editor import the project.
4. Run the project using the Play button.

The project currently uses GDScript and the GL Compatibility renderer. The main scene is `scenes/main.tscn`.

## Desktop controls
- WASD: walk / drive
- Shift: run
- E: enter or exit the nearby car
- Esc: close the open panel

## Android controls
The interface includes on-screen direction buttons, run, accelerate, brake, interact and exit-car controls. The current UI targets a 1280x720 landscape viewport and uses canvas-item stretching.

## Android export setup
Godot's Android export requires matching Godot export templates and a configured Android toolchain. The official Godot 4.7 export documentation lists OpenJDK 17 and the Android SDK as editor settings that must be configured. Install the export templates matching the exact Godot editor version before exporting.

General workflow:
1. Install the matching Godot 4.7 export templates.
2. Install/configure OpenJDK 17 and Android SDK in Editor Settings.
3. Add an Android export preset.
4. Export a debug APK first.
5. Install it on a physical device and test controls, save/load, memory use and frame rate.
6. Only create a release APK after the debug build passes device tests.

## QA checklist
- [ ] Project imports in Godot 4.7 without parser errors.
- [ ] Main scene launches.
- [ ] Player walks, runs and collides with buildings.
- [ ] Player can enter and exit the starter car.
- [ ] Car accelerates, brakes, reverses, steers and collides.
- [ ] Delivery marker changes from pickup to drop-off.
- [ ] Delivery reward is paid exactly once.
- [ ] Bank deposits and withdrawals preserve total cash.
- [ ] Home and shop purchases deduct the correct amount.
- [ ] Shop income accrues per in-game day and can be collected.
- [ ] Wallet, bank, assets, day and recent transactions persist after force-close/reopen.
- [ ] Android debug APK installs and runs in landscape.
- [ ] Performance is measured on a 4 GB RAM Android device.

## Current verification status
- **Godot 4.7 CI import and GDScript parse:** passed.
- **Economy regression tests:** passed for deposit, withdrawal, property/shop purchase, daily income, income collection, and save/load restoration.
- **Headless main-scene smoke run (120 frames):** passed.
- Latest successful GitHub Actions run: [run #6](https://github.com/g82202773-coder/Life-Empire/actions/runs/43910323729), on commit `48e6e161f6f3d628953d5f72997138e13c35f077`.
- **Visual review, touch input on a phone, gameplay balancing, Android APK export, install test and 4 GB device performance:** not yet verified.

The CI result proves scripts import and parse, the economy smoke checks pass, and the main scene starts in the headless CI environment. It does not prove that every feature behaves correctly in a rendered game, that mobile controls feel good, or that the APK is ready for release.
