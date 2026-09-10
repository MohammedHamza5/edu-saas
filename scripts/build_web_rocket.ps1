# ═══════════════════════════════════════════════════════════════════════════════
# 🚀 EduSaaS Rocket Performance Web Build Script
# Compiles Flutter Web with WebAssembly (WasmGC) + Skwasm + Aggressive Optimizations (-O4)
# Configures Cloudflare Pages edge headers (COOP/COEP) and PWA Offline-First
# ═══════════════════════════════════════════════════════════════════════════════

param (
    [switch]$SkipAnalyze,
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"

Write-Host "`n═════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   🚀 EduSaaS — Web Rocket Speed Production Compiler (WASM)   " -ForegroundColor Cyan
Write-Host "═════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

# Step 1: Static Code Analysis
if (-not $SkipAnalyze) {
    Write-Host "🔍 [1/5] Running strict Flutter analyzer..." -ForegroundColor Yellow
    flutter analyze
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Analyzer failed! Aborting build to ensure code quality." -ForegroundColor Red
        exit $LASTEXITCODE
    }
    Write-Host "✅ Analyzer passed with 0 issues!`n" -ForegroundColor Green
} else {
    Write-Host "⏩ [1/5] Skipping analyzer as requested.`n" -ForegroundColor Gray
}

# Step 2: Automated Tests
if (-not $SkipTests) {
    Write-Host "🧪 [2/5] Running test suite..." -ForegroundColor Yellow
    flutter test
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Tests failed! Aborting build." -ForegroundColor Red
        exit $LASTEXITCODE
    }
    Write-Host "✅ Test suite passed with 100% success!`n" -ForegroundColor Green
} else {
    Write-Host "⏩ [2/5] Skipping test suite as requested.`n" -ForegroundColor Gray
}

# Step 3: WebAssembly (WASM) + Skwasm Build
Write-Host "⚡ [3/5] Compiling to WebAssembly (WasmGC + Skwasm + Level-4 Optimization)..." -ForegroundColor Yellow
Write-Host "    Flags: --wasm -O4 --strip-wasm --tree-shake-icons --pwa-strategy=offline-first --no-source-maps" -ForegroundColor DarkGray

$buildStart = Get-Date

flutter build web --release --wasm -O4 --strip-wasm --tree-shake-icons --pwa-strategy=offline-first --no-source-maps

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Flutter Web build failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}

$buildDuration = (Get-Date) - $buildStart
Write-Host "✅ Compilation succeeded in $($buildDuration.TotalSeconds.ToString('F1')) seconds!`n" -ForegroundColor Green

# Step 4: Edge Caching & COOP/COEP Headers Injection for Cloudflare Pages
Write-Host "🌐 [4/5] Injecting Cloudflare Pages _headers..." -ForegroundColor Yellow

$webHeadersSource = Join-Path $PSScriptRoot "..\web\_headers"
$buildWebDir = Join-Path $PSScriptRoot "..\build\web"
$webHeadersDest = Join-Path $buildWebDir "_headers"

if (Test-Path $webHeadersSource) {
    Copy-Item -Path $webHeadersSource -Destination $webHeadersDest -Force
    Write-Host "✅ _headers successfully copied to build/web/_headers" -ForegroundColor Green
} else {
    Write-Host "⚠️ Warning: web/_headers not found! Make sure it exists." -ForegroundColor Yellow
}

# Step 5: Bundle Size & Performance Artifacts Audit
Write-Host "`n📊 [5/5] Generating Artifacts Performance Report..." -ForegroundColor Yellow

$wasmPath = Join-Path $buildWebDir "main.dart.wasm"
$jsPath = Join-Path $buildWebDir "main.dart.js"

if (Test-Path $wasmPath) {
    $wasmSize = (Get-Item $wasmPath).Length / 1MB
    Write-Host ("  ✓ WebAssembly Binary (main.dart.wasm): {0:N2} MB (Native WasmGC bytecode)" -f $wasmSize) -ForegroundColor Cyan
}

if (Test-Path $jsPath) {
    $jsSize = (Get-Item $jsPath).Length / 1MB
    Write-Host ("  ✓ Fallback JavaScript (main.dart.js):   {0:N2} MB (Legacy browser fallback)" -f $jsSize) -ForegroundColor Cyan
}

Write-Host "`n🎉 Rocket-Speed Production Build Complete! Ready for Cloudflare Pages deployment." -ForegroundColor Green
