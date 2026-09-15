# Check whether all three apps' debug APKs exist in dist/apks/
# Usage: .\scripts\build-setup\check-apks.ps1

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Resolve-Path "$ScriptDir\..\.."
$OutDir = Join-Path $Root "dist\apks"

if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
}

$Apps = @(
    @{ Name = "multivendor-app"; Source = "$Root\multivendor-app\android\app\build\outputs\apk\debug\app-debug.apk"; Target = "$OutDir\multivendor-app-debug.apk" },
    @{ Name = "multivendor-store"; Source = "$Root\multivendor-store\android\app\build\outputs\apk\debug\app-debug.apk"; Target = "$OutDir\multivendor-store-debug.apk" },
    @{ Name = "multivendor-rider"; Source = "$Root\multivendor-rider\android\app\build\outputs\apk\debug\app-debug.apk"; Target = "$OutDir\multivendor-rider-debug.apk" }
)

$Missing = @()

Write-Host "`n[build-setup] Checking APK status in dist/apks/ ...`n" -ForegroundColor Cyan

foreach ($item in $Apps) {
    # If not in dist/apks but exists in build output, copy it over
    if (-not (Test-Path $item.Target) -and (Test-Path $item.Source)) {
        Write-Host "[build-setup] Syncing $($item.Name) from build output to dist\apks\..." -ForegroundColor Yellow
        Copy-Item -Path $item.Source -Destination $item.Target -Force
    }

    if (Test-Path $item.Target) {
        $file = Get-Item $item.Target
        $sizeMB = [math]::Round($file.Length / 1MB, 2)
        $mtime = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
        Write-Host "  [OK]      $($item.Name) -- $sizeMB MB, built $mtime" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] $($item.Name) -- $($item.Target)" -ForegroundColor Red
        $Missing += $item.Name
    }
}

Write-Host ""
if ($Missing.Count -eq 0) {
    Write-Host "[build-setup] All three debug APKs are ready in dist\apks\`n" -ForegroundColor Green
    Write-Host "Ready to serve with:" -ForegroundColor Cyan
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\build-setup\serve-apks.ps1`n" -ForegroundColor White
    exit 0
} else {
    Write-Host "[build-setup] Missing APKs: $($Missing -join ', ')" -ForegroundColor Red
    exit 1
}
