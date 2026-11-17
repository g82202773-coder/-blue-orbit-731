#!/usr/bin/env bash
set -euo pipefail

PACKAGE="com.lifeempire.navapura.graphics_preview"
APK="build/LIFE-EMPIRE-debug.apk"
mkdir -p build

adb start-server >/dev/null
adb wait-for-device

# Wait until Android's package manager and activity manager are ready.
BOOTED=""
for _ in $(seq 1 60); do
  BOOTED="$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
  if [[ "$BOOTED" == "1" ]]; then
    break
  fi
  sleep 2
done
if [[ "$BOOTED" != "1" ]]; then
  adb logcat -d -v time > build/emulator-logcat.txt || true
  echo "Android emulator did not finish booting."
  exit 1
fi

adb logcat -c
adb install -r "$APK" > build/install.log 2>&1
cat build/install.log

# monkey sends the standard MAIN/LAUNCHER intent for the installed package.
adb shell monkey -p "$PACKAGE" 1 > build/launch.log 2>&1
cat build/launch.log

# Give Godot time to initialize the 3D scene and HUD.
sleep 20

PID="$(adb shell pidof "$PACKAGE" 2>/dev/null | tr -d '\r' || true)"
echo "LIFE EMPIRE process PID: $PID"

# Android shows an immersive-mode confirmation the first time a fullscreen
# app launches. Capture it for diagnostics, tap its "Got it" area, then
# capture the unobstructed game frame.
adb shell screencap -p /sdcard/life-empire-initial.png
adb pull /sdcard/life-empire-initial.png build/life-empire-initial.png
# Use the actual captured landscape screenshot dimensions. The immersive-mode
# confirmation's "Got it" button is at roughly 73% width and 39% height.
read -r SCREEN_W SCREEN_H < <(python - <<'PY'
from PIL import Image
image = Image.open("build/life-empire-initial.png")
print(image.width, image.height)
PY
)
if [[ "$SCREEN_W" =~ ^[0-9]+$ && "$SCREEN_H" =~ ^[0-9]+$ ]]; then
  adb shell input tap "$((SCREEN_W * 73 / 100))" "$((SCREEN_H * 39 / 100))"
fi
sleep 5

adb shell dumpsys activity activities > build/emulator-activities.txt 2>&1 || true
adb shell dumpsys meminfo "$PACKAGE" > build/emulator-memory.txt 2>&1 || true
adb shell screencap -p /sdcard/life-empire-screen.png
adb pull /sdcard/life-empire-screen.png build/life-empire-screen.png
adb logcat -d -v time > build/emulator-logcat.txt

if [[ -z "$PID" ]]; then
  echo "LIFE EMPIRE process did not remain alive after launch."
  exit 1
fi

if grep -E "FATAL EXCEPTION|Fatal signal|SCRIPT ERROR:|Parse Error:|Failed to load script" build/emulator-logcat.txt; then
  echo "Android emulator log contains a fatal startup or script error."
  exit 1
fi

python - <<'PY'
from PIL import Image, ImageChops
initial = Image.open("build/life-empire-initial.png").convert("RGB")
image = Image.open("build/life-empire-screen.png").convert("RGB")
if image.width <= image.height:
    raise SystemExit(f"Expected landscape screenshot, got {image.width}x{image.height}")
if initial.size != image.size:
    raise SystemExit(f"Screenshot dimensions changed unexpectedly: {initial.size} -> {image.size}")
sample = image.resize((96, 54))
colors = len(set(sample.getdata()))
before = initial.resize((96, 54))
diff = ImageChops.difference(before, sample)
changed = sum(1 for pixel in diff.getdata() if max(pixel) > 18)
changed_ratio = changed / (96 * 54)
print(f"Emulator screenshot: {image.width}x{image.height}; sampled colors: {colors}; changed area after dismiss: {changed_ratio:.1%}")
if colors < 40:
    raise SystemExit("Screenshot looks nearly blank; refusing to pass visual startup smoke test.")
# A fresh emulator displays Android's immersive-mode prompt on first launch.
# After tapping Got it, a large part of the frame must change to the actual game.
if changed_ratio < 0.10:
    raise SystemExit("The launch overlay may still cover the game; dismiss tap was not verified.")
PY

echo "Android emulator install, launch, process, screenshot and crash-log checks passed."
