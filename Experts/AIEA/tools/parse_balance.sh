#!/usr/bin/env bash
# Print the final balance from a UTF-16 MT5 tester agent log.
# Usage: parse_balance.sh <path-to-log>
# Prints the numeric balance (e.g. 10182.74), or NO_LOG / NO_BALANCE.
set -euo pipefail
log="${1:-}"
[ -f "$log" ] || { echo "NO_LOG"; exit 0; }

# Logs are UTF-16. Capture the number that appears AFTER the literal
# "final balance " (NOT the timestamp earlier on the line).
bal="$(iconv -f UTF-16 -t UTF-8 "$log" 2>/dev/null \
        | sed -nE 's/.*final balance ([0-9]+(\.[0-9]+)?).*/\1/p' \
        | tail -1)"
[ -n "$bal" ] && echo "$bal" || echo "NO_BALANCE"
