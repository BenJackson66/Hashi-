#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export XDG_DATA_HOME="$PWD/.local/share"
export XDG_CONFIG_HOME="$PWD/.local/config"
export XDG_CACHE_HOME="$PWD/.local/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/run.gd
