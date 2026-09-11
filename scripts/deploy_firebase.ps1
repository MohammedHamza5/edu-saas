param (
    [switch]$BuildFirst,
    [switch]$Wasm
)

$ErrorActionPreference = "Stop"

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "    EduSaaS -- Firebase Hosting Deployer (site: antounios)       " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

$buildWebDir = Join-Path $PSScriptRoot "..\build\web"

if ($BuildFirst -or (-not (Test-Path (Join-Path $buildWebDir "index.html")))) {
    Write-Host "`n[1/2] Building web release..." -ForegroundColor Yellow
    $buildScript = Join-Path $PSScriptRoot "build_web_rocket.ps1"
    if ($Wasm) {
        & $buildScript -Wasm -SkipAnalyze -SkipTests
    } else {
        & $buildScript -SkipAnalyze -SkipTests
    }
} else {
    Write-Host "`n[1/2] Found existing build in build/web. Skipping rebuild." -ForegroundColor Green
}

Write-Host "`n[2/2] Deploying to Firebase Hosting..." -ForegroundColor Yellow
$env:NODE_OPTIONS = "--dns-result-order=ipv4first"
firebase deploy --only hosting

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n=================================================================" -ForegroundColor Green
    Write-Host "  [SUCCESS] Deployment complete!" -ForegroundColor Green
    Write-Host "  Live URL: https://antounios.web.app" -ForegroundColor Cyan
    Write-Host "=================================================================`n" -ForegroundColor Green
} else {
    Write-Host "`n[ERROR] Firebase deploy failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}
