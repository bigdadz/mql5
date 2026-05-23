<#
.SYNOPSIS
  Headless MQL5 compile on native Windows MT5.
.DESCRIPTION
  Runs MetaEditor64.exe /compile against a .mq5 inside the real MQL5 tree, waits,
  parses the UTF-16 build log, and prints errors/warnings + PASS/FAIL.
  Compiles in place: the .ex5 lands next to the .mq5 where the Strategy Tester
  already looks - no copy step (unlike the macOS+Wine setup).
.PARAMETER Source
  Path to the .mq5 (absolute, or relative to repo root). Defaults to PortfolioORB_EA.mq5.
.EXAMPLE
  .\compile.ps1 ..\..\PortfolioORB_EA.mq5
#>
[CmdletBinding()]
param(
    [string]$Source = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path 'PortfolioORB_EA.mq5')
)
. "$PSScriptRoot\Mt5Common.ps1"

if (-not (Test-Path $script:MetaEditor)) { throw "MetaEditor64.exe not found at $script:MetaEditor (set `$env:MT5_HOME)" }
$src = (Resolve-Path $Source).Path
if (-not $src.ToLower().StartsWith($script:Mql5Dir.ToLower())) {
    throw "Source must live inside the real MQL5 tree:`n  $src`n  not under $script:Mql5Dir"
}

$log = Join-Path $env:TEMP ('mt5_compile_{0}.log' -f ([IO.Path]::GetFileNameWithoutExtension($src)))
if (Test-Path $log) { Remove-Item $log -Force }

Write-Host "[compile] $src"
$p = Start-Process -FilePath $script:MetaEditor `
        -ArgumentList @("/compile:$src", "/log:$log") `
        -Wait -PassThru -NoNewWindow
# MetaEditor /compile is quick; give the log a moment to flush.
$deadline = (Get-Date).AddSeconds(10)
while (-not (Test-Path $log) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 200 }

$out = Read-Mt5Text $log
if ($out) {
    $out -split "`r?`n" | Where-Object { $_ -match 'error|warning|Result' } | ForEach-Object { Write-Host $_ }
}

if ($out -and $out -match 'Result:\s*0\s*errors') {
    Write-Host "[compile] PASS: $([IO.Path]::GetFileName($src))" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[compile] FAIL: $([IO.Path]::GetFileName($src))" -ForegroundColor Red
    exit 1
}
