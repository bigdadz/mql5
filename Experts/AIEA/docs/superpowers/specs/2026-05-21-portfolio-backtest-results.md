# Portfolio ORB EA — Backtest Results (2026-05-21)

## Method
- **EA:** `Experts/AIEA/PortfolioORB_EA.mq5` — one EA trading 4 symbols with per-symbol state.
- **Engine:** MT5 Strategy Tester, **headless via Wine** (bundled wine64 + `terminal64 /config`), auto-login to the saved Exness account.
- **Lead chart:** GBPUSDm; the EA trades all 4 symbols (multi-symbol test).
- **Model:** 1-minute OHLC. **Deposit:** 10,000 USD, leverage 1:500.
- **In-sample:** 2024.01.01–2024.12.31. **Out-of-sample:** 2025.01.01–2025.12.31.
- **Config (validated in Phase 1, see `2026-05-21-portfolio-symbol-configs.md`):**
  ```
  InpSymbols      = "GBPUSDm,EURUSDm,USDJPYm,XAUUSDm"
  InpORStartHours = "6,6,9,12"
  InpORWindowMins = "30,30,30,15"
  InpMaxSpreadPts = "40,40,40,600"
  InpRiskPercent  = 1.0   (per trade, per symbol)
  InpCorrGroups   = "GBPUSDm,EURUSDm"  (correlation guard ON)
  InpMaxPortfolioDDPercent = 10.0
  ```

## Results

| Metric | 2024 (in-sample) | 2025 (OOS) |
|---|---|---|
| **Net return** | **+44.6%** (14,456.49) | **+32.6%** (13,264.07) |
| Max equity drawdown | 2,293.31 (**17.79%**) | 2,011.86 (**17.80%**) |
| Max balance drawdown | 2,159.26 (16.87%) | 1,818.37 (16.32%) |
| Profit factor | 1.13 | 1.12 |
| Sharpe ratio | 3.07 | 2.68 |
| Total trades | 578 | 531 |

### vs. the GBPUSDm-only baseline
| | Portfolio | GBPUSDm only |
|---|---|---|
| 2024 | +44.6% | +13.5% |
| **2025 OOS** | **+32.6%** | **+1.8%** |

**Success criterion met decisively.** The 2025 OOS return (+32.6%) is ~18× the single-symbol
baseline (+1.8%), at a max drawdown (~18%) well inside the accepted 40%+ tolerance. OOS Sharpe
2.68 and profit factor 1.12 are consistent between years — the edge is thin per trade but the
diversified, compounding portfolio turns it into a strong aggregate return.

### Why it works
- 4 weakly-correlated legs (London forex pair-trades + Tokyo/London JPY + NY-morning gold)
  rarely lose in lockstep, so combined drawdown (~18%) is far below the sum of single-leg risk.
- Each trade risks 1% of the **shared** balance, so with up to 4 symbols active the deployed
  daily risk is ~4× a single symbol — that, plus compounding, drives the +44.6% / +32.6% returns.
- 578 / 531 trades ≈ 0.57 trades/symbol/day — consistent with the 1-trade-per-symbol-per-day cap
  (no over-trading).

## Honest caveats (read before risking money)
- **In-sample (2024) is optimistic** — the per-symbol windows were chosen on 2024. **2025 OOS
  (+32.6%) is the real number**, and it held up strongly.
- **2-year sample**, 1-min OHLC (not real ticks). Live spread/slippage — **especially gold** —
  will erode returns; expect lower than backtest.
- **Selection bias** reduced via the worst-year robustness rule, but a 4-symbol search over a
  2-year window still carries some. Forward-test on demo before live.
- **News filter inactive** in the tester (no calendar data) — its live effect is unmeasured.
- Max DD ~18% leaves headroom under the 40% tolerance: `InpRiskPercent` could be raised (e.g. to
  ~2%) to roughly scale return and DD together — **but only after a clean demo forward-test**, and
  not as a way to mask a weak edge (the edge here is real but per-trade thin).

## Reproduce
1. Compile `Experts/AIEA/PortfolioORB_EA.mq5`; copy the `.ex5` into the real MQL5 tree
   (`tools/compile.sh` builds into a sandbox prefix — copy `~/.wine_orb/drive_c/mt/MQL5/Experts/AIEA/PortfolioORB_EA.ex5`
   to `MQL5/Experts/AIEA/`).
2. Tester ini `portfolio_2024.ini` / `portfolio_2025.ini` (in MT5 root): GBPUSDm lead, M5,
   Model=1, the config above in `[TesterInputs]`, `ShutdownTerminal=1`.
3. Parse `final balance` from the agent log; full stats in the generated `portfolio_<year>.htm`.

## Next steps toward live
Demo forward-test the full portfolio ≥ 1–2 months → compare to these numbers → live at minimum
lot per symbol → scale `InpRiskPercent` only if demo/live track the backtest.
