#!/usr/bin/env bash
# Official 4.6.3 artifacts; SHA-512 from the release's SHA512-SUMS.txt.
set -euo pipefail
cd "$(dirname "$0")/../.."
ci_dir="$PWD/.local/android-ci"
mkdir -p "$ci_dir/downloads" "$ci_dir/bin" "$ci_dir/data/godot/export_templates/4.6.3.stable"
cd "$ci_dir/downloads"
base_url=https://github.com/godotengine/godot/releases/download/4.6.3-stable
fetch_verified() {
  local filename="$1" checksum="$2"
  if [[ ! -f "$filename" ]]; then
    curl --fail --location --show-error --retry 2 "$base_url/$filename" -o "$filename"
  fi
  printf '%s  %s\n' "$checksum" "$filename" | sha512sum --check --strict
}
fetch_verified Godot_v4.6.3-stable_linux.x86_64.zip a035258da32b77f966a5376f9fa29c30a6adde826a85ba918e1605bd1fc9823eba7d85f1dd5e748956bd2ba72827c0025ffa11bb82aec91128c407a2e723c99c
fetch_verified Godot_v4.6.3-stable_export_templates.tpz da606b61c10157844f8300172df374472665f95015495cb1a7cd132c40ede404faa96cc1016a4b9662db9909ddea69632c4948b2cd11163438dad4808881fb68
unzip -o -j Godot_v4.6.3-stable_linux.x86_64.zip 'Godot_v4.6.3-stable_linux.x86_64' -d "$ci_dir/bin"
mv -f "$ci_dir/bin/Godot_v4.6.3-stable_linux.x86_64" "$ci_dir/bin/godot"
chmod +x "$ci_dir/bin/godot"
# Only the precompiled Android debug template is needed; no native/Gradle build.
unzip -o -j Godot_v4.6.3-stable_export_templates.tpz 'templates/android_debug.apk' -d "$ci_dir/data/godot/export_templates/4.6.3.stable"
