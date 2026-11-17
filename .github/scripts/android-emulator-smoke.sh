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
# Suppress Android's first-launch immersive-mode confirmation for this app
# so the screenshot validates the rendered game rather than a system overlay.
adb shell settings put secure immersive_mode_confirmations confirmed || true
adb install -r "$APK" > build/install.log 2>&1
cat build/install.log

# monkey sends the standard MAIN/LAUNCHER intent for the installed package.
adb shell monkey -p "$PACKAGE" 1 > build/launch.log 2>&1
cat build/launch.log

# Give Godot time to initialize the 3D scene and HUD.
sleep 25

PID="$(adb shell pidof "$PACKAGE" 2>/dev/null | tr -d '\r' || true)"
echo "LIFE EMPIRE process PID: $PID"

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
    raise SystemExit("Screenshot looks nearly blank or is covered by a system overlay.")
PY

echo "Android emulator install, launch, process, screenshot and crash-log checks passed."
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

def immersive_button_area(frame):
    width, height = frame.size
    pixels = frame.load()
    count = 0
    for y in range(int(height * 0.25), int(height * 0.82)):
        for x in range(int(width * 0.60), int(width * 0.90)):
            red, green, blue = pixels[x, y]
            if 45 <= red <= 115 and 60 <= green <= 140 and 100 <= blue <= 210 and blue > red * 1.25 and green > red * 1.10:
                count += 1
    return count

remaining_button_pixels = immersive_button_area(image)
if remaining_button_pixels >= 8000:
    raise SystemExit(f"Android immersive-mode confirmation is still visible ({remaining_button_pixels} blue button pixels).")
sample = image.resize((96, 54))
colors = len(set(sample.getdata()))
before = initial.resize((96, 54))
diff = ImageChops.difference(before, sample)
changed = sum(1 for pixel in diff.getdata() if max(pixel) > 18)
changed_ratio = changed / (96 * 54)
print(f"Emulator screenshot: {image.width}x{image.height}; sampled colors: {colors}; changed area after prompt dismissal: {changed_ratio:.1%}; remaining confirmation pixels: {remaining_button_pixels}")
if colors < 40:
    raise SystemExit("Screenshot looks nearly blank; refusing to pass visual startup smoke test.")
PY

echo "Android emulator install, launch, process, screenshot and crash-log checks passed."
