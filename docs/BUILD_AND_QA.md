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
The source files have been committed to GitHub, but this environment does not currently have the Godot runtime or Android toolchain available. Therefore, parser validation, runtime gameplay testing, APK generation and physical-device performance testing are **not yet verified**. Do not treat this repository state as a tested APK.
