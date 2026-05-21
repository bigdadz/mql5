#!/usr/bin/env bash
# Sweep OR-start hour x OR-window length for ONE symbol over ONE date range,
# using the existing compiled LondonORB_EA.ex5 via [TesterInputs] overrides.
#
# Per combo it overrides: OR start/end, the trade-end window (OR-end + 210 min,
# matching the portfolio EA's InpTradeWindowMins so late/NY-session OR starts
# still get a non-empty trading window), and max spread. All other inputs use
# the EA's compiled (validated) defaults. The Profiles/Tester *.set is moved
# aside for the duration so it cannot override our values, then restored.
#
# Appends CSV rows: symbol,year,or_start,or_window,final_balance
# Usage: sweep.sh <SYMBOL> <FROM yyyy.mm.dd> <TO yyyy.mm.dd> <YEAR_LABEL> <MAXSPREAD> <out.csv>
#   Optional env: START_HOURS="6 7 ..."  WINDOWS="15 30 60"  (override the grids)
set -euo pipefail

SYMBOL="${1:?symbol}"; FROM="${2:?from}"; TO="${3:?to}"; YEAR="${4:?year}"; MAXSPREAD="${5:?maxspread}"; OUT="${6:?out.csv}"

MT5_DIR="$HOME/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5"
WINE="/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine64"
export WINEPREFIX="$HOME/Library/Application Support/net.metaquotes.wine.metatrader5"
export WINEDEBUG=-all
AGENTLOG="$MT5_DIR/Tester/Agent-127.0.0.1-3000/logs"
SETFILE="$MT5_DIR/MQL5/Profiles/Tester/LondonORB_EA.set"
INI="$MT5_DIR/sweep.ini"
HERE="$(cd "$(dirname "$0")" && pwd)"
TRADE_WINDOW_MIN=210

# Grids (overridable via env)
read -r -a START_HOURS <<< "${START_HOURS:-6 7 8 9 10 11 12 13 14 15 16}"
read -r -a WINDOWS     <<< "${WINDOWS:-15 30 60}"

# Move the .set aside so it can't override [TesterInputs]; always restore.
SET_MOVED=0
if [ -f "$SETFILE" ]; then mv "$SETFILE" "$SETFILE.sweepbak"; SET_MOVED=1; fi
restore() { [ "$SET_MOVED" = 1 ] && [ -f "$SETFILE.sweepbak" ] && mv "$SETFILE.sweepbak" "$SETFILE" || true; }
trap restore EXIT

[ -f "$OUT" ] || echo "symbol,year,or_start,or_window,final_balance" > "$OUT"

for sh in "${START_HOURS[@]}"; do
  for win in "${WINDOWS[@]}"; do
    or_end=$(( sh*60 + win ))
    eh=$(( or_end/60 )); em=$(( or_end%60 ))
    tend=$(( or_end + TRADE_WINDOW_MIN )); [ "$tend" -gt 1439 ] && tend=1439
    th=$(( tend/60 )); tm=$(( tend%60 ))

    cat > "$INI" <<EOF
[Tester]
Expert=AIEA\\LondonORB_EA.ex5
Symbol=$SYMBOL
Period=M5
Optimization=0
Model=1
FromDate=$FROM
ToDate=$TO
ForwardMode=0
Deposit=10000
Currency=USD
Leverage=500
ExecutionMode=0
Visual=0
ShutdownTerminal=1
[TesterInputs]
InpORStartHour=$sh
InpORStartMin=0
InpOREndHour=$eh
InpOREndMin=$em
InpTradeEndHour=$th
InpTradeEndMin=$tm
InpMaxSpreadPoints=$MAXSPREAD
EOF

    bal=""
    for attempt in 1 2 3; do
      rm -f "$AGENTLOG/"*.log 2>/dev/null || true
      ( cd "$MT5_DIR" && "$WINE" terminal64.exe "/config:C:\\Program Files\\MetaTrader 5\\sweep.ini" ) >/dev/null 2>&1 || true
      latest="$(ls -t "$AGENTLOG/"*.log 2>/dev/null | head -1 || true)"
      [ -n "$latest" ] && bal="$(bash "$HERE/parse_balance.sh" "$latest")"
      case "$bal" in ""|NO_LOG|NO_BALANCE) sleep 2 ;; *) break ;; esac
    done

    echo "$SYMBOL,$YEAR,$sh,$win,${bal:-FAIL}" >> "$OUT"
    printf '[sweep] %-8s %s OR=%02d:00 win=%2dm trade-end=%02d:%02d -> %s\n' \
      "$SYMBOL" "$YEAR" "$sh" "$win" "$th" "$tm" "${bal:-FAIL}"
  done
done
