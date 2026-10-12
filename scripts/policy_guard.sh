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

# Commit messages too. bed9d9e and 67f503f slipped through before this check; history is never rewritten (rule 6).
if git rev-parse -q --verify origin/main >/dev/null; then
  if git log origin/main..HEAD --format='%H %B' \
       | awk '/^[0-9a-f]{40} /{sha=$1} {print sha" "$0}' \
       | grep -vE '^(bed9d9e|67f503f)' \
       | grep -iE 'Claude (Opus|Sonnet|Haiku|Fable|Mythos)'; then
    echo "::error::Specific Claude model named in a commit message (CLAUDE.md hard rule 5)."; fail=1
  fi
fi

exit $fail
