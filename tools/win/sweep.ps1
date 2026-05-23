<#
.SYNOPSIS
  Sweep OR-start-hour x OR-window for ONE symbol over ONE date range (Windows port of sweep.sh).
.DESCRIPTION
  Drives PortfolioORB_EA in single-symbol mode via [TesterInputs] overrides. Per combo it sets
  InpSymbols / InpORStartHours / InpORWindowMins / InpMaxSpreadPts (single-element CSVs). The
  shared InpTradeWindowMins (default 210) auto-follows each symbol's OR end, so no trade-end
  adjustment is needed (unlike the LondonORB scalar-input sweep).

  Generates a per-combo HTML report and reads net profit / PF / trades from it (reliable across
  builds), then appends a CSV row. Any Profiles\Tester\<EA>.set is moved aside for the duration
  (it would otherwise silently override [TesterInputs]) and restored on exit.
.EXAMPLE
  .\sweep.ps1 -Symbol XAUUSD. -From 2026.01.01 -To 2026.05.23 -MaxSpread 600 -Out gold_2026.csv
.EXAMPLE
  .\sweep.ps1 -Symbol GBPUSD. -From 2025.01.01 -To 2025.12.31 -MaxSpread 40 `
              -StartHours 6,7,8,9 -Windows 15,30,60 -Out gbp_2025.csv
#>
[CmdletBinding()]
param(
    [string]$Symbol = 'XAUUSD.',
    [Parameter(Mandatory)][string]$From,
    [Parameter(Mandatory)][string]$To,
    [string]$Label = 'sweep',
    [int]$MaxSpread = 600,
    [string]$Out = 'sweep.csv',
    [int[]]$StartHours = @(6,7,8,9,10,11,12,13,14,15,16),
    [int[]]$Windows    = @(15,30,60),
    [string]$Expert = 'EAI\PortfolioORB_EA.ex5',
    [int]$Deposit = 10000,
    [string]$Currency = 'USD',
    [int]$Leverage = 500,
    [string]$Period = 'M5',
    [int]$Model = 1,
    [int]$TimeoutSec = 540
)
. "$PSScriptRoot\Mt5Common.ps1"
Assert-Mt5

# Resolve output to repo's tools dir if a bare name was given.
if (-not [IO.Path]::IsPathRooted($Out)) { $Out = Join-Path (Get-Location) $Out }

$ini        = Join-Path $script:DataDir 'EAI_sweep.ini'
$reportName = 'EAI_sweep_tmp'
$reportHtm  = Join-Path $script:DataDir "$reportName.htm"
$expertName = [IO.Path]::GetFileNameWithoutExtension($Expert)
$setFile    = Join-Path $script:Mql5Dir "Profiles\Tester\$expertName.set"

# Move the .set aside so it can't override [TesterInputs]; always restore.
$setMoved = $false
if (Test-Path $setFile) { Move-Item $setFile "$setFile.sweepbak" -Force; $setMoved = $true }

try {
    if (-not (Test-Path $Out)) { 'symbol,label,or_start,or_window,net_profit,profit_factor,trades,final_balance' | Set-Content -Path $Out -Encoding UTF8 }

    foreach ($sh in $StartHours) {
        foreach ($win in $Windows) {
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
                '[TesterInputs]'
                "InpSymbols=$Symbol"
                "InpORStartHours=$sh"
                "InpORWindowMins=$win"
                "InpMaxSpreadPts=$MaxSpread"
            )
            [IO.File]::WriteAllLines($ini, $lines, [Text.UnicodeEncoding]::new($false, $true))

            $netProfit = ''; $pf = ''; $trades = ''; $finalBal = ''
            foreach ($attempt in 1..3) {
                if (Test-Path $reportHtm) { Remove-Item $reportHtm -Force }
                $p = Start-Process -FilePath $script:Terminal -ArgumentList "/config:$ini" -PassThru
                if (-not $p.WaitForExit($TimeoutSec * 1000)) { try { $p.Kill() } catch {} }
                if (Test-Path $reportHtm) {
                    $s = Get-ReportStats $reportHtm
                    $netProfit = ($s.TotalNetProfit -replace '[^\d.\-]', '')
                    $pf        = $s.ProfitFactor
                    $trades    = $s.TotalTrades
                    if ($netProfit -ne '') { $finalBal = [double]$Deposit + [double]$netProfit; break }
                }
                Start-Sleep -Seconds 2   # silent launch failure: retry
            }

            $row = '{0},{1},{2},{3},{4},{5},{6},{7}' -f $Symbol, $Label, $sh, $win, $netProfit, $pf, $trades, $finalBal
            Add-Content -Path $Out -Value $row
            Write-Host ("[sweep] {0,-9} {1} OR={2:00}:00 win={3,2}m -> net={4} PF={5} trades={6}" -f $Symbol, $Label, $sh, $win, $netProfit, $pf, $trades)
        }
    }
}
finally {
    if ($setMoved -and (Test-Path "$setFile.sweepbak")) { Move-Item "$setFile.sweepbak" $setFile -Force }
}
Write-Host "[sweep] done -> $Out" -ForegroundColor Green
