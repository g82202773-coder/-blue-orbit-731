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
DISPLAY_SIZE="$(adb shell wm size | awk '/Physical size|Override size/ {print $3}' | tail -1 | tr -d '\r')"
SCREEN_W="${DISPLAY_SIZE%x*}"
SCREEN_H="${DISPLAY_SIZE#*x}"
if [[ "$SCREEN_W" =~ ^[0-9]+$ && "$SCREEN_H" =~ ^[0-9]+$ ]]; then
  # wm size may report portrait physical dimensions while the full-screen game
  # rotates the captured display to landscape.
  if (( SCREEN_W < SCREEN_H )); then
    TEMP="$SCREEN_W"
    SCREEN_W="$SCREEN_H"
    SCREEN_H="$TEMP"
  fi
  # "Got it" sits near the middle-right of Android's immersive-mode dialog.
  adb shell input tap "$((SCREEN_W * 56 / 100))" "$((SCREEN_H * 38 / 100))"
fi
sleep 4

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
from PIL import Image
image = Image.open("build/life-empire-screen.png").convert("RGB")
if image.width <= image.height:
    raise SystemExit(f"Expected landscape screenshot, got {image.width}x{image.height}")
sample = image.resize((96, 54))
colors = len(set(sample.getdata()))
print(f"Emulator screenshot: {image.width}x{image.height}; sampled colors: {colors}")
if colors < 40:
    raise SystemExit("Screenshot looks nearly blank; refusing to pass visual startup smoke test.")
PY

echo "Android emulator install, launch, process, screenshot and crash-log checks passed."
