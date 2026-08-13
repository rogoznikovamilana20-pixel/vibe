# Local CI gate for Vibe (MASTER_PLAN 9.5).
# Run:  powershell -ExecutionPolicy Bypass -File tool\verify.ps1 [-Apk]
# Without [-Apk]: analyze + unit tests + working-copy cleanliness (~1 min).
# With [-Apk]: additionally release APK build (~5-10 min).

param([switch]$Apk)

$ErrorActionPreference = "Stop"
$proj = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location "$proj\app"

Write-Host "[1/3] flutter analyze" -ForegroundColor Cyan
flutter analyze | Out-String | Write-Host
if ($LASTEXITCODE -ne 0) { throw "analyze failed" }

Write-Host "[2/3] flutter test" -ForegroundColor Cyan
flutter test | Out-String | Write-Host
if ($LASTEXITCODE -ne 0) { throw "tests failed" }

Write-Host "[3/3] working copy clean of stray files" -ForegroundColor Cyan
$strays = Get-ChildItem -Path . -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^(test_out|test_full|integ_out|golden_tmp)\.txt$' }
if ($strays) {
    $strays | ForEach-Object { $_.FullName }
    throw "stray test output files found - remove them"
}

if ($Apk) {
    Write-Host "[4/4] flutter build apk --release" -ForegroundColor Cyan
    flutter build apk --release | Out-String | Write-Host
    if ($LASTEXITCODE -ne 0) { throw "apk build failed" }
}

Write-Host "CI gate passed." -ForegroundColor Green