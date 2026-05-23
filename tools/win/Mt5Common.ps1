# Mt5Common.ps1 - shared helpers for the Windows (native MT5) backtest tooling.
# Dot-source this from compile.ps1 / test.ps1 / sweep.ps1:  . "$PSScriptRoot\Mt5Common.ps1"
#
# Resolves the MT5 install + data folder, and provides UTF-16 log / HTML report parsers.
# Unlike the macOS+Wine setup there is NO sandbox prefix and NO .ex5 copy step:
# MetaEditor compiles in place into the real tree where the Strategy Tester looks.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Paths -----------------------------------------------------------------
# MT5 install (terminal64.exe + MetaEditor64.exe). Override with $env:MT5_HOME.
$script:Mt5Home = if ($env:MT5_HOME) { $env:MT5_HOME } else { 'C:\Program Files\MetaTrader 5' }
$script:Terminal   = Join-Path $Mt5Home 'terminal64.exe'
$script:MetaEditor = Join-Path $Mt5Home 'MetaEditor64.exe'

# Data folder = repo is at <data>\MQL5\Experts\EAI ; tools\win is two below repo root.
$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path          # ...\EAI
$script:DataDir  = (Resolve-Path (Join-Path $RepoRoot   '..\..\..')).Path          # ...\Terminal\<hash>
$script:Mql5Dir  = Join-Path $DataDir 'MQL5'
# Expert path relative to MQL5\Experts, used in the [Tester] ini (e.g. EAI\PortfolioORB_EA.ex5)
$script:ExpertsDir = Join-Path $Mql5Dir 'Experts'
$script:AgentLogDir = Join-Path $DataDir 'Tester\Agent-127.0.0.1-3000\logs'

function Assert-Mt5 {
    if (-not (Test-Path $script:Terminal))   { throw "terminal64.exe not found at $script:Terminal (set `$env:MT5_HOME)" }
    if (-not (Test-Path $script:MetaEditor))  { throw "MetaEditor64.exe not found at $script:MetaEditor (set `$env:MT5_HOME)" }
    $proc = Get-Process terminal64 -ErrorAction SilentlyContinue
    if ($proc) { throw "MT5 terminal is running (PID $($proc.Id)). Close it first - a second /config launch with the same data folder is ignored." }
}

# Read a UTF-16 (or UTF-8/ASCII) MT5 log/report into a single string.
function Read-Mt5Text {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    # MT5 logs/reports are UTF-16LE with BOM; -Encoding Unicode handles it. Fall back to default.
    try   { return (Get-Content -Path $Path -Encoding Unicode -Raw) }
    catch { return (Get-Content -Path $Path -Raw) }
}

# Final balance from a tester agent log: the number AFTER the literal "final balance ".
function Get-FinalBalance {
    param([Parameter(Mandatory)][string]$LogPath)
    $txt = Read-Mt5Text $LogPath
    if (-not $txt) { return $null }
    $m = [regex]::Matches($txt, 'final balance\s+([0-9]+(?:\.[0-9]+)?)')
    if ($m.Count -gt 0) { return [double]$m[$m.Count-1].Groups[1].Value }
    return $null
}

# Parse the Strategy Tester HTML report for key stats. Values sit in <b>...</b>
# right after each label cell; we strip newlines first (labels/values can wrap).
function Get-ReportStats {
    param([Parameter(Mandatory)][string]$ReportPath)
    $html = Read-Mt5Text $ReportPath
    if (-not $html) { return $null }
    $flat = $html -replace "`r?`n", ' '
    $grab = {
        param($label)
        $rx = [regex]::Escape($label) + '\s*:?\s*</td>\s*<td[^>]*>\s*<b>\s*([^<]+?)\s*</b>'
        $mm = [regex]::Match($flat, $rx)
        if ($mm.Success) { return ($mm.Groups[1].Value -replace '&nbsp;|\s+', ' ').Trim() }
        return $null
    }
    [pscustomobject]@{
        InitialDeposit  = & $grab 'Initial Deposit'
        TotalNetProfit  = & $grab 'Total Net Profit'
        ProfitFactor    = & $grab 'Profit Factor'
        ExpectedPayoff  = & $grab 'Expected Payoff'
        EquityDDMaximal = & $grab 'Equity Drawdown Maximal'
        BalanceDDMaximal= & $grab 'Balance Drawdown Maximal'
        TotalTrades     = & $grab 'Total Trades'
        ProfitTradesPct = & $grab 'Profit Trades (% of total)'
        SharpeRatio     = & $grab 'Sharpe Ratio'
    }
}
