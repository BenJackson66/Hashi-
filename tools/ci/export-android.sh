#!/usr/bin/env bash
set +x
set -euo pipefail
cd "$(dirname "$0")/../.."
./tools/ci/check-signing-secrets.sh
: "${JAVA_HOME:?Set JAVA_HOME to a JDK (17 recommended)}"
: "${ANDROID_HOME:?Set ANDROID_HOME to the Android SDK}"
ci_dir="$PWD/.local/android-ci"
export XDG_DATA_HOME="$ci_dir/data"
export XDG_CONFIG_HOME="$ci_dir/config"
export XDG_CACHE_HOME="$ci_dir/cache"
mkdir -p "$XDG_CONFIG_HOME/godot" "$XDG_CACHE_HOME" build/android
[[ "$(godot --version)" == 4.6.3.stable.* ]]
[[ -f "$XDG_DATA_HOME/godot/export_templates/4.6.3.stable/android_debug.apk" ]]
python3 - <<'PRESET'
import configparser
from pathlib import Path
config = configparser.ConfigParser(interpolation=None)
config.read('export_presets.cfg')
for section in config.sections():
    if section.endswith('.options'):
        for name in ('keystore/debug', 'keystore/debug_user', 'keystore/debug_password'):
            value = config.get(section, name, fallback='""').strip().strip('"')
            if value:
                raise SystemExit('Preset signing credentials must remain empty; use Actions secrets only.')
if Path('export_credentials.cfg').exists():
    raise SystemExit('Remove local export_credentials.cfg before running the isolated CI export.')
PRESET
# Persistent identity only. Register cleanup BEFORE decoding potentially bad input.
umask 077
signing_dir="$(mktemp -d "$ci_dir/signing-XXXXXX")"
cleanup_signing() {
  rm -rf "$signing_dir"
  rm -f "$XDG_DATA_HOME/godot/keystores/debug.keystore"
}
trap cleanup_signing EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$signing_dir/debug.keystore"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="$HASHI_SIGNING_PASSWORD"
if ! printf '%s' "$HASHI_SIGNING_KEYSTORE_BASE64" | base64 --decode > "$GODOT_ANDROID_KEYSTORE_DEBUG_PATH" 2>/dev/null; then
  echo 'Invalid signing keystore encoding; export aborted.' >&2
  exit 1
fi
unset HASHI_SIGNING_KEYSTORE_BASE64 HASHI_SIGNING_PASSWORD
# Do not forward keytool diagnostics or command arguments to the runner log.
if ! "$JAVA_HOME/bin/keytool" -J-Duser.language=en -J-Duser.country=US -list -v \
  -keystore "$GODOT_ANDROID_KEYSTORE_DEBUG_PATH" -storepass:env GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD \
  -alias "$GODOT_ANDROID_KEYSTORE_DEBUG_USER" > "$signing_dir/entry.txt" 2>&1; then
  echo 'Unable to open signing identity with the supplied password and alias.' >&2
  exit 1
fi
if ! grep -q '^Entry type: PrivateKeyEntry' "$signing_dir/entry.txt"; then
  echo 'Signing alias must contain a private key, not only a certificate.' >&2
  exit 1
fi
if ! "$JAVA_HOME/bin/keytool" -exportcert -keystore "$GODOT_ANDROID_KEYSTORE_DEBUG_PATH" \
  -storepass:env GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD -alias "$GODOT_ANDROID_KEYSTORE_DEBUG_USER" \
  -file "$signing_dir/certificate.der" > /dev/null 2>&1; then
  echo 'Unable to read the public signing certificate; export aborted.' >&2
  exit 1
fi
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
  build/android/SHA256SUMS.txt build/android/apk-verification.txt build/android/apk-manifest.txt build/android/signing-certificate-sha256.txt
godot --headless --path . --export-debug Android build/android/hashi-h01-debug-arm64.apk
./tools/ci/verify-apk.sh
python3 tools/ci/apk-signing.py verify build/android/hashi-h01-debug-arm64.apk \
  --certificate "$signing_dir/certificate.der" --output build/android/signing-certificate-sha256.txt
