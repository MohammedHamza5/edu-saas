param (
    [switch]$SkipBuild,
    [switch]$Wasm,
    [ValidateSet("prod", "test")]
    [string]$Target = "test"
)

$ErrorActionPreference = "Stop"

$siteName = if ($Target -eq "prod") { "antounios" } else { "antounios-test" }
$liveUrl = if ($Target -eq "prod") { "https://antounios.web.app" } else { "https://antounios-test.web.app" }

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "    EduSaaS -- Firebase Hosting Deployer (site: $siteName)       " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

$buildWebDir = Join-Path $PSScriptRoot "..\build\web"

if (-not $SkipBuild) {
    Write-Host "`n[1/2] Compiling fresh production web build..." -ForegroundColor Yellow
    $buildScript = Join-Path $PSScriptRoot "build_web_rocket.ps1"
    if ($Wasm) {
        & $buildScript -Wasm -SkipAnalyze -SkipTests
    } else {
        & $buildScript -SkipAnalyze -SkipTests
    }
} else {
    Write-Host "`n[1/2] Skipping rebuild as requested (-SkipBuild). Deploying existing build in build/web..." -ForegroundColor Yellow
}

Write-Host "`n[2/2] Deploying to Firebase Hosting (target: $Target -> site: $siteName)..." -ForegroundColor Yellow
$forceIpv4 = (Join-Path $PSScriptRoot "force_ipv4.cjs").Replace('\', '/')
$env:NODE_OPTIONS = "-r `"$forceIpv4`""
firebase deploy --only hosting:$Target
$deploySuccess = ($LASTEXITCODE -eq 0)

# Check if deploy actually completed despite CLI analytics telemetry timeout
if (-not $deploySuccess) {
    $debugLog = Join-Path $PSScriptRoot "..\firebase-debug.log"
    if (Test-Path $debugLog) {
        $tail = (Get-Content $debugLog -Tail 40) -join "`n"
        if ($tail -match "release complete" -or $tail -match "Deploy complete") {
            $deploySuccess = $true
        }
    }
}

if ($deploySuccess) {
    Write-Host "`n=================================================================" -ForegroundColor Green
    Write-Host "  [SUCCESS] Deployment complete!" -ForegroundColor Green
    Write-Host "  Live URL: $liveUrl" -ForegroundColor Cyan
    Write-Host "=================================================================`n" -ForegroundColor Green
} else {
    Write-Host "`n[ERROR] Firebase deploy failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}
