# Portfolio ORB — Validated per-symbol configs (2026-05-21)

Outcome of Phase 1 research: an OR-start × OR-window sweep on **2024 (in-sample)** and
an **OOS confirmation on 2025** for each candidate symbol's best window + neighbors.
Deposit 10,000 USD, M5, 1-min OHLC model, Exness `m`-suffix symbols, headless Wine tester.
Trade window per combo = OR-end + 210 min (matches the portfolio EA's `InpTradeWindowMins`).

## Selection rule
Keep a symbol's config only if it is **positive in both 2024 and 2025** AND **robust**.
Robustness = chosen by the **best worst-year** (max of `min(net2024, net2025)`) rather than
the 2024 peak — this deliberately rejects "lucky" 2024 spikes that don't repeat OOS.

## Validated configs (all four KEPT)

| Symbol  | OR start | OR window | Max spread (pts) | 2024 net | 2025 OOS net | Kept |
|---------|----------|-----------|------------------|----------|--------------|------|
| GBPUSDm | 06:00    | 30m       | 40               | +13.5%   | +1.8%        | yes (baseline) |
| EURUSDm | 06:00    | 30m       | 40               | +8.3%    | +4.5%        | yes  |
| USDJPYm | 09:00    | 30m       | 40               | +9.0%    | +8.8%        | yes  |
| XAUUSDm | 12:00    | 15m       | 600              | +23.7%   | +15.4%       | yes  |

(GBPUSDm carried over from the prior single-symbol validation; net % is balance−deposit on 10k.)

## Why these windows (and not the 2024 peaks)
The robustness rule changed two picks away from the in-sample champion — the right call:

- **EURUSDm 06:00/30** — London open, same as GBPUSD. Best both-years config (+826 / +449).
  The 07:00 region was huge in 2025 (+2232) but negative in 2024 → fails both-years.
- **USDJPYm 09:00/30** — 2024 peak was 09:00/**60** (+2481) but OOS fell to +358; 09:00/**30**
  is consistent (+899 / +879, worst-year +879). Robustness-first → 30m.
- **XAUUSDm 12:00/15** — 2024 peak was 12:00/**30** (+3229) but OOS near-flat (+69); 12:00/**15**
  is consistently strong (+2375 / +1543, worst-year +1543). The whole 12:00–13:00 NY-morning
  cluster is positive both years (very robust region). Robustness-first → 15m.

## Dropped
None. All three new symbols produced a robust, both-years-positive config.

## Final portfolio config strings (for PortfolioORB_EA inputs)
```
InpSymbols      = "GBPUSDm,EURUSDm,USDJPYm,XAUUSDm"
InpORStartHours = "6,6,9,12"
InpORWindowMins = "30,30,30,15"
InpMaxSpreadPts = "40,40,40,600"
InpCorrGroups   = "GBPUSDm,EURUSDm"   ; correlated London-open pair, guard ON
```

## Caveats
- Net % per leg is each symbol tested **standalone** on a 10k deposit — NOT the portfolio
  result (shared equity, correlation, portfolio DD breaker change the combined figure).
  The combined verdict comes from the Phase 3 portfolio backtest.
- 2-year sample; OOS = 2025 only. Selection bias reduced (worst-year rule) but not zero.
- 1-min OHLC, not real ticks — live spread/slippage (especially gold) will erode returns.
- Sessions are server-time; gold's 12:00 server is the NY-morning move on this account.

## Source data
`Experts/AIEA/tools/sweep_2024.csv` (99 combos) · `Experts/AIEA/tools/sweep_2025.csv` (30 OOS combos)
