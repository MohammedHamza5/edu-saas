$buildWebDir = "build\web"
$buildId = (Get-Date -Format "yyyyMMddHHmmss")
$bootstrapPath = Join-Path $buildWebDir "flutter_bootstrap.js"
if (Test-Path $bootstrapPath) {
    $bootstrapContent = Get-Content $bootstrapPath -Raw
    $bootstrapContent = $bootstrapContent -replace 'serviceWorkerSettings:\s*\{[^}]*\}', 'serviceWorkerSettings: null'
    $bootstrapContent = $bootstrapContent -replace '"mainJsPath":\s*"main\.dart\.js"', ('"mainJsPath":"main.dart.js?v=' + $buildId + '"')
    $bootstrapContent = $bootstrapContent -replace '"mainWasmPath":\s*"main\.dart\.wasm"', ('"mainWasmPath":"main.dart.wasm?v=' + $buildId + '"')
    $bootstrapContent | Set-Content $bootstrapPath -NoNewline
    Write-Host "[OK] Neutralized serviceWorkerSettings & injected cache-busting (v=$buildId)"
}
$versionPath = Join-Path $buildWebDir "version.json"
@{
    app_name = "edu_saas"
    version = "1.0.0"
    build_number = $buildId
    package_name = "edu_saas"
} | ConvertTo-Json -Compress | Set-Content $versionPath -NoNewline
Write-Host "[OK] Generated version.json with build_number $buildId"
