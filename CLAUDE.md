# CLAUDE.md — MQL5 repo (Exness account, macOS + Wine)

## Repo layout
- **This repo IS the `MQL5/Experts/EAI/` folder.** Clone it directly into the MT5 data folder's `Experts/` dir (`git clone <url>` from inside `<MT5 data>/MQL5/Experts/` → produces `EAI/`). Repo root holds the EAs (`LondonORB_EA.mq5`, `PortfolioORB_EA.mq5`); `tools/`, `tests/`, `docs/` are siblings.
- All repo-relative commands below run from the repo root (= `MQL5/Experts/EAI/`).

## Build & test MQL5 headlessly (no MetaTrader GUI required)
- **Compile:** `bash tools/compile.sh "<abs path to .mq5>"` → `[compile] PASS` / per-line errors. (homebrew `wine` + throwaway prefix `~/.wine_orb` holding a copy of the real `Include/`.)
- Do NOT run homebrew `wine` against the MetaQuotes bundle prefix (wineserver version mismatch); the bundle's `wine64` opens the GUI instead of batch-compiling.
- **`compile.sh` builds into the sandbox prefix (`~/.wine_orb/drive_c/mt/MQL5/...`), NOT the real tree.** The Strategy Tester loads `.ex5` from the real tree, so after compiling you MUST copy the fresh `.ex5` over: `cp ~/.wine_orb/drive_c/mt/MQL5/Experts/EAI/<EA>.ex5 MQL5/Experts/EAI/`. Skipping this silently tests a stale build.
- **Strategy Tester headless:** bundled wine64 (`/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine64`) + `WINEPREFIX="$HOME/Library/Application Support/net.metaquotes.wine.metatrader5"`, run `terminal64.exe "/config:C:\Program Files\MetaTrader 5\<x>.ini"`. Use a `[Tester]` ini with `ShutdownTerminal=1`; `[TesterInputs]` overrides EA inputs. Auto-logs into the saved Exness account and downloads history on demand.

## Tester gotchas (each cost real debugging time)
- Symbol is **`GBPUSDm`** (Exness "m" suffix), not `GBPUSD`.
- **`MQL5/Profiles/Tester/<expert>.set` silently overrides compiled defaults** when `[TesterInputs]` is absent — delete it to test true defaults.
- Use **Model=1 (1-min OHLC)** for multi-year runs (real-tick cache is sparse).
- Results: parse `Tester/Agent-127.0.0.1-3000/logs/<YYYYMMDD>.log` (UTF-16) for `final balance`; `rm` it before each run to isolate. The agent log has ONLY `final balance` (no DD/PF).
- For full stats use `Report=<name>` + `ReplaceReport=1` in `[Tester]` → generates `<name>.htm` in the MT5 root (this DID work reliably). Parse: UTF-16, `tr -d '\n'` first, values are in `<b>…</b>` right after each label (e.g. `Equity Drawdown Maximal:</td> … <b>2 293.31 (17.79%)</b>`).
- A killed sweep leaves a terminal-rewritten `<expert>.set` (terminal saves inputs on exit) and an un-restored backup — `sweep.sh` moves the `.set` aside (trap-restores on clean exit); if killed, restore manually.
- Sequential terminal launches occasionally fail silently (no log) — retry 2–3×.

## Conventions
- EAs may be single-file `.mq5` (e.g. `LondonORB_EA.mq5` at repo root) — keep clean commented sections; modular isn't required.
- The unit-test script lives under `tests/` (it's a Script, but kept inside this Experts subtree so the project stays self-contained — it shows under MT5's *Experts* navigator group, not *Scripts*).
- `.ex5` are build artifacts — don't commit.
- End commit messages with the `Co-Authored-By: Claude ...` line.
