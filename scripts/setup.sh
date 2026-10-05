#!/usr/bin/env bash
# Environment setup for Claude Code cloud sessions and local clones.
set -euo pipefail
python3 -m pip install -q -r requirements-dev.txt 2>/dev/null \
  || python3 -m pip install -q --break-system-packages -r requirements-dev.txt
# Luau runtime for parity tests (backlog item 1). Optional; skips if offline.
if ! command -v lune >/dev/null 2>&1; then
  echo "lune not installed; Luau parity tests will skip (see STATUS backlog item 1)."
fi
