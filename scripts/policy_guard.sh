#!/usr/bin/env bash
# Fails if game code uses wagering words or any file names a specific Claude model.
# Docs may discuss betting (to explain why it's banned); game code and UI strings may not.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

game_paths=()
for p in src/*.luau game; do [ -e "$p" ] && game_paths+=("$p"); done
if [ ${#game_paths[@]} -gt 0 ]; then
  if grep -rniE '\b(bet|bets|betting|wager|wagers|odds|stake|stakes|payout|bookie)\b' \
       --include='*.luau' --include='*.lua' --include='*.json' "${game_paths[@]}" \
       | grep -viE 'Stakes race|StakesRace|-- policy-ok'; then
    echo "::error::Wagering vocabulary in game code (CLAUDE.md hard rule 1)."; fail=1
  fi
fi

if git grep -nIiE 'Claude (Opus|Sonnet|Haiku|Fable|Mythos)' -- . ':!scripts/policy_guard.sh'; then
  echo "::error::Specific Claude model named (CLAUDE.md hard rule 5). Write \"Claude\"."; fail=1
fi

exit $fail
