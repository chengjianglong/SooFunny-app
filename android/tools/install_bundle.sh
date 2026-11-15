#!/bin/sh
# Builds the app as an Android App Bundle (with the voices asset pack) and installs it
# on the connected emulator or phone the way Google Play would, using bundletool's local testing.
# Plain `./gradlew installDebug` installs the app without the asset packs (no natural voices).
set -eu
cd "$(dirname "$0")/.."
BUNDLETOOL_VERSION=1.18.3
JAR="tools/bundletool-all-$BUNDLETOOL_VERSION.jar"
if [ ! -f "$JAR" ]; then
    curl -L --fail -o "$JAR" "https://github.com/google/bundletool/releases/download/$BUNDLETOOL_VERSION/bundletool-all-$BUNDLETOOL_VERSION.jar"
fi
./gradlew :app:bundleDebug
OUT=app/build/outputs/apks
mkdir -p "$OUT"
rm -f "$OUT/app-debug.apks"
ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
java -jar "$JAR" build-apks --bundle=app/build/outputs/bundle/debug/app-debug.aab \
    --output="$OUT/app-debug.apks" --local-testing --connected-device --adb="$ADB"
java -jar "$JAR" install-apks --apks="$OUT/app-debug.apks" --adb="$ADB"
echo "Installed with asset packs."
