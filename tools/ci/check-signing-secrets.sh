#!/usr/bin/env bash
# Presence only. Never print values, including when called from a traced shell.
set +x
set -euo pipefail
if [[ -z "${HASHI_SIGNING_KEYSTORE_BASE64:-}" || -z "${HASHI_SIGNING_PASSWORD:-}" ]]; then
  echo 'Missing persistent Android signing credentials. Configure both HASHI_SIGNING_KEYSTORE_BASE64 and HASHI_SIGNING_PASSWORD; no fallback key will be generated.' >&2
  exit 1
fi
