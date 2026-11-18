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
# The game is exported in landscape. Rotate the emulator BEFORE launching so
# Android does not recreate/destroy GodotActivity during engine initialization.
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 1
sleep 2

# Suppress Android's first-launch immersive-mode confirmation.
adb shell settings put secure immersive_mode_confirmations confirmed || true
adb install -r "$APK" > build/install.log 2>&1
cat build/install.log

# Launch through the standard MAIN/LAUNCHER intent.
adb shell monkey -p "$PACKAGE" 1 > build/launch.log 2>&1
cat build/launch.log

# Godot may need extra time to initialize the Compatibility renderer and
# construct the procedural city on a software-rendered emulator.
PID=""
RENDERED=0
for attempt in $(seq 1 12); do
  sleep 5
  PID="$(adb shell pidof "$PACKAGE" 2>/dev/null | tr -d '\r' || true)"
  adb shell screencap -p /sdcard/life-empire-candidate.png
  adb pull /sdcard/life-empire-candidate.png build/life-empire-candidate.png >/dev/null
  COLORS="$(python - <<'PY'
from PIL import Image
image = Image.open("build/life-empire-candidate.png").convert("RGB")
sample = image.resize((96, 54))
print(len(set(sample.getdata())))
PY
)"
  echo "Render probe $attempt: PID=$PID, sampled colors=$COLORS"
  if [[ "$COLORS" =~ ^[0-9]+$ ]] && (( COLORS >= 200 )); then
    cp build/life-empire-candidate.png build/life-empire-screen.png
    RENDERED=1
    break
  fi
done

# Preserve the last candidate for diagnosis, even when the scene never renders.
if [[ ! -s build/life-empire-screen.png && -s build/life-empire-candidate.png ]]; then
  cp build/life-empire-candidate.png build/life-empire-screen.png
fi

adb shell dumpsys activity activities > build/emulator-activities.txt 2>&1 || true
adb shell dumpsys meminfo "$PACKAGE" > build/emulator-memory.txt 2>&1 || true
adb logcat -d -v time > build/emulator-logcat.txt

if [[ -z "$PID" ]]; then
  echo "LIFE EMPIRE process did not remain alive after launch."
  exit 1
fi

if grep -E "FATAL EXCEPTION|Fatal signal|SCRIPT ERROR:|Parse Error:|Failed to load script" build/emulator-logcat.txt; then
  echo "Android emulator log contains a fatal startup or script error."
  exit 1
fi

if [[ "$RENDERED" -ne 1 ]]; then
  echo "LIFE EMPIRE process stayed alive, but the actual game scene did not render."
  exit 1
fi

echo "Android emulator install, launch, rendered landscape frame, process and crash-log checks passed."
