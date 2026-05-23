<#
.SYNOPSIS
  Run a single headless Strategy Tester backtest on native Windows MT5.
.DESCRIPTION
  Writes a [Tester] ini (optionally with [TesterInputs] overrides), launches
  terminal64.exe /config, waits for it to shut down, then parses the HTML report
  + agent log and prints the key stats.
.PARAMETER Expert    Expert path relative to MQL5\Experts (e.g. EAI\PortfolioORB_EA.ex5).
.PARAMETER Symbol    Tester chart symbol. IUX is unsuffixed (GBPUSD, XAUUSD).
.PARAMETER From/To   yyyy.MM.dd date range.
.PARAMETER Inputs    Hashtable of [TesterInputs] overrides, e.g. @{ InpSymbols='XAUUSD' }.
.EXAMPLE
  .\test.ps1 -Symbol XAUUSD -From 2026.01.01 -To 2026.05.23 -Inputs @{ InpSymbols='XAUUSD' }
#>
[CmdletBinding()]
param(
    [string]$Expert  = 'EAI\PortfolioORB_EA.ex5',
    [Parameter(Mandatory)][string]$Symbol,
    [string]$Period  = 'M5',
    [Parameter(Mandatory)][string]$From,
    [Parameter(Mandatory)][string]$To,
    [int]$Deposit    = 10000,
    [string]$Currency= 'USD',
    [int]$Leverage   = 500,
    [int]$Model      = 1,                 # 1 = 1-min OHLC (robust for multi-year/-month)
    [string]$Report  = "bt_$(Get-Date -Format yyyyMMdd_HHmmss)",
    [hashtable]$Inputs = @{},
    [int]$TimeoutSec = 1200
)
. "$PSScriptRoot\Mt5Common.ps1"
Assert-Mt5

$ini        = Join-Path $script:DataDir 'EAI_test.ini'
$reportName = $Report
$reportHtm  = Join-Path $script:DataDir "$reportName.htm"   # MT5 writes report under the data folder

# Build ini content.
$lines = @(
    '[Tester]'
    "Expert=$Expert"
    "Symbol=$Symbol"
    "Period=$Period"
    'Optimization=0'
    "Model=$Model"
    "FromDate=$From"
    "ToDate=$To"
    'ForwardMode=0'
    "Deposit=$Deposit"
    "Currency=$Currency"
    "Leverage=$Leverage"
    'ExecutionMode=0'
    'Visual=0'
    "Report=$reportName"
    'ReplaceReport=1'
    'ShutdownTerminal=1'
)
if ($Inputs.Count -gt 0) {
    $lines += '[TesterInputs]'
    foreach ($k in $Inputs.Keys) { $lines += "$k=$($Inputs[$k])" }
}
# MT5 ini files are read as UTF-16LE.
[IO.File]::WriteAllLines($ini, $lines, [Text.UnicodeEncoding]::new($false, $true))

# Isolate results: clear prior agent log + stale report.
if (Test-Path $script:AgentLogDir) { Get-ChildItem "$script:AgentLogDir\*.log" -EA SilentlyContinue | Remove-Item -Force -EA SilentlyContinue }
if (Test-Path $reportHtm) { Remove-Item $reportHtm -Force }

Write-Host "[test] $Expert  $Symbol $Period  $From..$To  (Model=$Model, Deposit=$Deposit)"
if ($Inputs.Count) { Write-Host "[test] inputs: $(($Inputs.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' ')" }

$p = Start-Process -FilePath $script:Terminal -ArgumentList "/config:$ini" -PassThru
if (-not $p.WaitForExit($TimeoutSec * 1000)) {
    Write-Warning "[test] terminal did not exit within ${TimeoutSec}s; killing."
    try { $p.Kill() } catch {}
}

# Results.
$bal = $null
$latest = Get-ChildItem "$script:AgentLogDir\*.log" -EA SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
if ($latest) { $bal = Get-FinalBalance $latest.FullName }

Write-Host ""
Write-Host "===== RESULT: $reportName =====" -ForegroundColor Cyan
if (Test-Path $reportHtm) {
    $s = Get-ReportStats $reportHtm
    Write-Host ("Initial deposit : {0}" -f $s.InitialDeposit)
    Write-Host ("Total net profit: {0}" -f $s.TotalNetProfit)
    Write-Host ("Profit factor   : {0}" -f $s.ProfitFactor)
    Write-Host ("Expected payoff : {0}" -f $s.ExpectedPayoff)
    Write-Host ("Equity DD max   : {0}" -f $s.EquityDDMaximal)
    Write-Host ("Balance DD max  : {0}" -f $s.BalanceDDMaximal)
    Write-Host ("Total trades    : {0}" -f $s.TotalTrades)
    Write-Host ("Win %           : {0}" -f $s.ProfitTradesPct)
    Write-Host ("Sharpe ratio    : {0}" -f $s.SharpeRatio)
    Write-Host "Report: $reportHtm"
} else {
    Write-Warning "No HTML report at $reportHtm"
}
if ($null -ne $bal) { Write-Host ("Final balance   : {0}  (from agent log)" -f $bal) }
elseif (-not (Test-Path $reportHtm)) { Write-Warning "No agent log either - check the tester log; the symbol may be unavailable or no ticks." }
