param (
    [switch]$Wasm,
    [switch]$SkipAnalyze,
    [switch]$SkipTests,
    [switch]$DeployFirebase
)

$ErrorActionPreference = "Stop"

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "    EduSaaS -- Web Rocket Speed Production Compiler              " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# Step 1: Static Code Analysis
if (-not $SkipAnalyze) {
    Write-Host "[1/5] Running strict Flutter analyzer..." -ForegroundColor Yellow
    flutter analyze
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Analyzer failed! Aborting build to ensure code quality." -ForegroundColor Red
        exit $LASTEXITCODE
    }
    Write-Host "[PASS] Analyzer passed with 0 issues!`n" -ForegroundColor Green
} else {
    Write-Host "[SKIP] Skipping analyzer as requested.`n" -ForegroundColor Gray
}

# Step 2: Automated Tests
if (-not $SkipTests) {
    Write-Host "[2/5] Running core unit test suite..." -ForegroundColor Yellow
    flutter test test/core/utils/cache_manager_test.dart test/features/attendance/
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Tests failed! Aborting build." -ForegroundColor Red
        exit $LASTEXITCODE
    }
    Write-Host "[PASS] Test suite passed with 100% success!`n" -ForegroundColor Green
} else {
    Write-Host "[SKIP] Skipping test suite as requested.`n" -ForegroundColor Gray
}

# Step 3: Production Build
$buildStart = Get-Date

if ($Wasm) {
    Write-Host "[3/5] Compiling to WebAssembly (WasmGC + Skwasm + Level-4 Optimization)..." -ForegroundColor Yellow
    flutter build web --release --wasm -O4 --strip-wasm --tree-shake-icons --pwa-strategy=none --base-href=/ --no-source-maps --dart-define-from-file=.env
} else {
    Write-Host "[3/5] Compiling with Level-4 Optimization, Icon Tree-Shaking, and Clean Reload Strategy..." -ForegroundColor Yellow
    flutter build web --release -O4 --tree-shake-icons --pwa-strategy=none --base-href=/ --no-source-maps --dart-define-from-file=.env
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "Flutter Web build failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}

$buildDuration = (Get-Date) - $buildStart
$seconds = [math]::Round($buildDuration.TotalSeconds, 1)
Write-Host "[DONE] Compilation succeeded in $seconds seconds!`n" -ForegroundColor Green

# Step 4: Edge Caching & COOP/COEP Headers Injection for Cloudflare Pages
Write-Host "[4/5] Injecting Cloudflare Pages _headers..." -ForegroundColor Yellow

$webHeadersSource = Join-Path $PSScriptRoot "..\web\_headers"
$buildWebDir = Join-Path $PSScriptRoot "..\build\web"
$webHeadersDest = Join-Path $buildWebDir "_headers"

if (Test-Path $webHeadersSource) {
    Copy-Item -Path $webHeadersSource -Destination $webHeadersDest -Force
    Write-Host "[OK] _headers successfully copied to build/web/_headers" -ForegroundColor Green
} else {
    Write-Host "[WARN] web/_headers not found! Make sure it exists." -ForegroundColor Yellow
}

# Step 5: Bundle Size & Performance Artifacts Audit
Write-Host "`n[5/5] Performance Artifacts Report..." -ForegroundColor Yellow

$wasmPath = Join-Path $buildWebDir "main.dart.wasm"
$jsPath = Join-Path $buildWebDir "main.dart.js"

if (Test-Path $wasmPath) {
    $wasmSize = [math]::Round((Get-Item $wasmPath).Length / 1MB, 2)
    Write-Host "  * WebAssembly Binary (main.dart.wasm): $wasmSize MB (Native WasmGC bytecode)" -ForegroundColor Cyan
}

if (Test-Path $jsPath) {
    $jsSize = [math]::Round((Get-Item $jsPath).Length / 1MB, 2)
    Write-Host "  * Optimized JavaScript (main.dart.js): $jsSize MB" -ForegroundColor Cyan
}

Write-Host "`nRocket-Speed Production Build Complete! Ready for deployment." -ForegroundColor Green

# Step 6: Deploy to Firebase Hosting (Optional)
if ($DeployFirebase) {
    Write-Host "`n=================================================================" -ForegroundColor Cyan
    Write-Host "    Deploying to Firebase Hosting (site: antounios) ...           " -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    $env:NODE_OPTIONS = "--dns-result-order=ipv4first"
    firebase deploy --only hosting
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n[SUCCESS] Successfully deployed to: https://antounios.web.app" -ForegroundColor Green
    } else {
        Write-Host "`n[ERROR] Firebase deploy failed!" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}
