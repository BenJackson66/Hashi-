#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${JAVA_HOME:?Set JAVA_HOME to a JDK (17 recommended)}"
: "${ANDROID_HOME:?Set ANDROID_HOME to the Android SDK}"
ci_dir="$PWD/.local/android-ci"
export XDG_DATA_HOME="$ci_dir/data"
export XDG_CONFIG_HOME="$ci_dir/config"
export XDG_CACHE_HOME="$ci_dir/cache"
mkdir -p "$XDG_CONFIG_HOME/godot" "$XDG_CACHE_HOME" build/android
[[ "$(godot --version)" == 4.6.3.stable.* ]]
[[ -f "$XDG_DATA_HOME/godot/export_templates/4.6.3.stable/android_debug.apk" ]]
# Ephemeral debug identity. Never commit/upload its key, password or editor data.
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$ci_dir/debug.keystore"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD
GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="$(openssl rand -hex 24)"
trap 'rm -f "$GODOT_ANDROID_KEYSTORE_DEBUG_PATH" "$XDG_DATA_HOME/godot/keystores/debug.keystore"' EXIT
rm -f "$GODOT_ANDROID_KEYSTORE_DEBUG_PATH"
"$JAVA_HOME/bin/keytool" -genkeypair -noprompt -keystore "$GODOT_ANDROID_KEYSTORE_DEBUG_PATH" \
  -storetype PKCS12 -storepass:env GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD \
  -keypass:env GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD -alias "$GODOT_ANDROID_KEYSTORE_DEBUG_USER" \
  -keyalg RSA -keysize 2048 -validity 365 -dname 'CN=Hashi Debug,O=Hashi Development,C=US'
# This directory belongs to CI, not to the developer's editor profile.
python3 - <<'PY'
import json, os
from pathlib import Path
settings = Path(os.environ['XDG_CONFIG_HOME']) / 'godot/editor_settings-4.6.tres'
settings.write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
    + 'export/android/android_sdk_path = ' + json.dumps(os.environ['ANDROID_HOME']) + '\n'
    + 'export/android/java_sdk_path = ' + json.dumps(os.environ['JAVA_HOME']) + '\n'
    + 'export/android/debug_keystore = ' + json.dumps(os.environ['GODOT_ANDROID_KEYSTORE_DEBUG_PATH']) + '\n'
    + 'export/android/shutdown_adb_on_exit = false\n')
PY
godot --headless --path . --editor --import --quit
./tests/run.sh
# Remove stale outputs so a failed export can never upload an old APK.
rm -f build/android/hashi-h01-debug-arm64.apk build/android/hashi-h01-debug-arm64.apk.idsig \
  build/android/SHA256SUMS.txt build/android/apk-verification.txt build/android/apk-manifest.txt
godot --headless --path . --export-debug Android build/android/hashi-h01-debug-arm64.apk
./tools/ci/verify-apk.sh
