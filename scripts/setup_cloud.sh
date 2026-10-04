#!/usr/bin/env bash
# Setup for Claude Code cloud sessions and local dev: pytest + Lune (Luau runtime).
set -euo pipefail
LUNE_VERSION="${LUNE_VERSION:-0.10.5}"
pip install -q pytest 2>/dev/null || pip install -q --break-system-packages pytest
if ! command -v lune >/dev/null 2>&1; then
  mkdir -p "$HOME/.local/bin"
  curl -sSL -o /tmp/lune.zip "https://github.com/lune-org/lune/releases/download/v${LUNE_VERSION}/lune-${LUNE_VERSION}-linux-x86_64.zip"
  unzip -o -q /tmp/lune.zip -d "$HOME/.local/bin"
  chmod +x "$HOME/.local/bin/lune"
fi
export PATH="$HOME/.local/bin:$PATH"
lune --version
