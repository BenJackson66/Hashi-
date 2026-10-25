#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${ANDROID_HOME:?Set ANDROID_HOME to the Android SDK}"
apk=build/android/hashi-h01-debug-arm64.apk
build_tools="$ANDROID_HOME/build-tools/36.1.0"
test -s "$apk"
"$build_tools/apksigner" verify --verbose "$apk"
"$build_tools/zipalign" -c -P 16 -v 4 "$apk"
"$build_tools/aapt" dump badging "$apk" > build/android/apk-verification.txt
"$build_tools/aapt" dump xmltree "$apk" AndroidManifest.xml > build/android/apk-manifest.txt
python3 - <<'PY'
import re, zipfile
from pathlib import Path
apk = Path('build/android/hashi-h01-debug-arm64.apk')
badging = Path('build/android/apk-verification.txt').read_text()
assert "package: name='org.hashi.prototype'" in badging, 'Unexpected package ID'
assert "sdkVersion:'24'" in badging, 'Unexpected minimum Android API'
assert "targetSdkVersion:'36'" in badging, 'Unexpected target Android API'
assert "application-debuggable" in badging, 'Expected debug APK'
assert re.search(r"^native-code: 'arm64-v8a'\s*$", badging, re.M), 'Expected ARM64 only'
# aapt badging omits Godot 4.6.3's activity-alias launcher. Inspect the tree.
manifest = Path('build/android/apk-manifest.txt').read_text()
alias_blocks = [m.group(0) for m in re.finditer(r'(?ms)^(?P<indent> +)E: activity-alias\b.*?(?=^(?P=indent)E:|\Z)', manifest)]
assert any('android.intent.action.MAIN' in block and 'android.intent.category.LAUNCHER' in block
           and re.search(r'android:exported[^\n]*0xffffffff', block)
           and 'com.godot.game.GodotApp' in block for block in alias_blocks), 'Missing exported launcher alias'
with zipfile.ZipFile(apk) as archive:
    assert archive.testzip() is None, 'Corrupt APK archive'
    assert 'assets/data/puzzles.json' in archive.namelist(), 'Missing puzzle data'
print('APK structure, debug flag, ARM64, manifest, puzzle data, signature and alignment verified.')
print('This is static verification, not an Android install/device test.')
PY
cat build/android/apk-manifest.txt >> build/android/apk-verification.txt
(cd build/android && sha256sum hashi-h01-debug-arm64.apk > SHA256SUMS.txt)
