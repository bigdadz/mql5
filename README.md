# EAI — ORB Expert Advisors for MetaTrader 5

Opening-Range-Breakout EAs for MT5 (Exness `m`-suffix symbols).
MQL5 Algo Forge / [dreamwongrak](https://www.mql5.com/en/users/dreamwongrak)

## Install (clone into MT5)

This repo **is** the `MQL5/Experts/EAI/` folder. In MetaTrader 5: *File → Open Data Folder*, go into `MQL5/Experts/`, then clone it there (the repo name makes the folder `EAI/`):

```sh
cd "<MT5 data folder>/MQL5/Experts"
git clone git@github.com:bigdadz/EAI.git
```

The EAs then appear in the MetaEditor / Navigator under **Experts → EAI**. Open an `.mq5` and press **F7** to compile (or use the headless `tools/compile.sh`).

## Layout

```
EAI/                        (= MQL5/Experts/EAI/)
├── LondonORB_EA.mq5        single-symbol ORB EA
├── PortfolioORB_EA.mq5     multi-symbol portfolio ORB EA
├── tests/                  standalone math regression script
├── tools/                  headless compile + Strategy-Tester sweep scripts (bash, macOS+Wine)
└── docs/                   design specs, plans, backtest results
```

`.ex5` build artifacts are git-ignored — recompile after cloning.

See [CLAUDE.md](CLAUDE.md) for the headless build/test workflow and tester gotchas.
