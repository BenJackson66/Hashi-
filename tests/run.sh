#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .local/test-runs
test_dir="$(mktemp -d "$PWD/.local/test-runs/run-XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
export XDG_DATA_HOME="$test_dir/data"
export XDG_CONFIG_HOME="$test_dir/config"
export XDG_CACHE_HOME="$test_dir/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/run.gd
godot --headless --path . --script tests/continuity.gd
godot --headless --path . --script tests/relaunch.gd -- --write
godot --headless --path . --script tests/relaunch.gd -- --read
timeout 30s godot --headless --path . --script tests/procedural.gd
timeout 30s godot --headless --path . --script tests/procedural_identity.gd
timeout 30s godot --headless --path . --script tests/playable_generation.gd
timeout 30s godot --headless --path . --script tests/procedural_relaunch.gd -- --write
timeout 30s godot --headless --path . --script tests/procedural_relaunch.gd -- --read
timeout 30s godot --headless --path . --script tests/home_navigation.gd
python3 tools/research/export_profile_oracle.py "$test_dir/profile-oracle.json"
timeout 30s godot --headless --path . --script tests/logical_profile.gd -- "$test_dir/profile-oracle.json"
timeout 60s godot --headless --path . --script tests/free_play.gd
timeout 60s godot --headless --path . --script tests/play_modes.gd
timeout 60s godot --headless --path . --script tests/mode_stage_boundaries.gd
timeout 90s godot --headless --path . --script tests/story.gd
timeout 90s godot --headless --path . --script tests/story_stage_boundaries.gd
timeout 90s godot --headless --path . --script tests/story_errors.gd
timeout 90s godot --headless --path . --script tests/variant_oracle.gd
timeout 90s godot --headless --path . --script tests/variants.gd
timeout 90s godot --headless --path . --script tests/variant_migration_review.gd
timeout 90s godot --headless --path . --script tests/monotone_oracle.gd
timeout 90s godot --headless --path . --script tests/quality_review.gd
timeout 90s godot --headless --path . --script tests/iron_streaks.gd
timeout 60s godot --headless --path . --script tests/art_presentation.gd
timeout 90s godot --headless --path . --script tests/cozy_domain_review.gd
timeout 60s godot --headless --path . --script tests/cozy_touch_review.gd
timeout 90s godot --headless --path . --script tests/cozy_ui_review.gd
timeout 90s godot --headless --path . --script tests/cozy_backlog_review.gd
timeout 120s godot --headless --path . --script tests/lighthouse_review.gd
python3 tests/audio_assets.py
python3 tests/signing_security.py

