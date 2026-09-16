# Start all 3 mobile apps (Metro bundlers) simultaneously on distinct ports with LAN IP or Tunnel support
# Usage:
#   .\start-all-apps.ps1                 # Starts on Local IP (LAN mode - e.g. 10.13.0.44)
#   .\start-all-apps.ps1 -Tunnel         # Starts with Expo Tunnel (ngrok)

param (
    [switch]$Tunnel,
    [string]$HostIp = ""
)

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Enatega Multivendor - Mobile Apps & APK Server      " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

# 1. Resolve Local IP
if ([string]::IsNullOrWhiteSpace($HostIp)) {
    $wifi = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceAlias -match 'Wi-Fi|Wireless|WLAN' -and $_.IPAddress -notmatch '^169\.' }
    if ($wifi) {
        $HostIp = $wifi[0].IPAddress
    } else {
        $allIps = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notmatch '^(127\.|169\.)' }
        if ($allIps) { $HostIp = $allIps[0].IPAddress } else { $HostIp = "localhost" }
    }
}

$modeFlag = "--host lan"
$modeDesc = "Local LAN ($HostIp)"

if ($Tunnel) {
    $modeFlag = "--tunnel"
    $modeDesc = "Expo Tunnel (Cloud / ngrok)"
}

Write-Host "`n[NETWORK MODE]: $modeDesc" -ForegroundColor Green
Write-Host "[PACKAGER HOSTNAME]: $HostIp" -ForegroundColor Cyan

# 2. Optional ADB reverse if phone is ever connected over USB (failsafe)
Write-Host "`n[ADB] Checking USB port forwarding (optional failsafe)..." -ForegroundColor Gray
try {
    & adb reverse tcp:8081 tcp:8081 2>&1 | Out-Null
    & adb reverse tcp:8082 tcp:8082 2>&1 | Out-Null
    & adb reverse tcp:8083 tcp:8083 2>&1 | Out-Null
    Write-Host "  [OK] USB ports mapped (8081, 8082, 8083)" -ForegroundColor Green
} catch {
    Write-Host "  [SKIP] No active USB ADB device detected. Proceeding with Wi-Fi network." -ForegroundColor Gray
}

# 3. Launch Local APK Download Server on Port 8080
$port8080Busy = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
if (-not $port8080Busy) {
    Write-Host "`n[APK SERVER] Starting Local APK Download Server on Port 8080..." -ForegroundColor Green
    $apkServerScript = Join-Path $PSScriptRoot "apk-download-server\server.js"
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host '=== APK Download Server (Port 8080) ===' -ForegroundColor Green; node '$apkServerScript'"
} else {
    Write-Host "`n[APK SERVER] Port 8080 already active (APK Server running)." -ForegroundColor Green
}

# 4. Launch Metro Bundlers in separate windows
Write-Host "`n[LAUNCH] Starting 3 Metro Bundlers in separate processes..." -ForegroundColor Cyan

# Customer App (Port 8081)
$custCmd = "`$env:REACT_NATIVE_PACKAGER_HOSTNAME='$HostIp'; Write-Host '=== Customer App (Port 8081 - $modeDesc) ===' -ForegroundColor Cyan; cd d:\fd\multivendor-app; npx expo start $modeFlag --port 8081"
Start-Process powershell -ArgumentList "-NoExit", "-Command", $custCmd

# Store App (Port 8082)
$storeCmd = "`$env:REACT_NATIVE_PACKAGER_HOSTNAME='$HostIp'; Write-Host '=== Store App (Port 8082 - $modeDesc) ===' -ForegroundColor Yellow; cd d:\fd\multivendor-store; npx expo start $modeFlag --port 8082"
Start-Process powershell -ArgumentList "-NoExit", "-Command", $storeCmd

# Rider App (Port 8083)
$riderCmd = "`$env:REACT_NATIVE_PACKAGER_HOSTNAME='$HostIp'; Write-Host '=== Rider App (Port 8083 - $modeDesc) ===' -ForegroundColor Magenta; cd d:\fd\multivendor-rider; npx expo start $modeFlag --port 8083"
Start-Process powershell -ArgumentList "-NoExit", "-Command", $riderCmd

Write-Host "`n======================================================" -ForegroundColor Green
Write-Host "  All Services & Metro Bundlers Successfully Started! " -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green

Write-Host "`n[APK DOWNLOAD SERVER]" -ForegroundColor Green
Write-Host "  URL: http://${HostIp}:8080" -ForegroundColor Cyan
Write-Host "  (Open on phone browser to download Customer, Store, or Rider APKs directly)" -ForegroundColor Gray

Write-Host "`n[METRO BUNDLERS - LOCAL NETWORK ACCESS]" -ForegroundColor White
Write-Host "  Customer App (Port 8081):" -ForegroundColor Cyan
Write-Host "    Metro: http://${HostIp}:8081" -ForegroundColor Gray
Write-Host "    Expo : exp://${HostIp}:8081" -ForegroundColor Gray

Write-Host "  Store App (Port 8082):" -ForegroundColor Yellow
Write-Host "    Metro: http://${HostIp}:8082" -ForegroundColor Gray
Write-Host "    Expo : exp://${HostIp}:8082" -ForegroundColor Gray

Write-Host "  Rider App (Port 8083):" -ForegroundColor Magenta
Write-Host "    Metro: http://${HostIp}:8083" -ForegroundColor Gray
Write-Host "    Expo : exp://${HostIp}:8083" -ForegroundColor Gray

Write-Host "`n[INSTRUCTIONS FOR INSTALLED DEBUG APKS]" -ForegroundColor White
Write-Host "  1. Shake phone to open React Native Dev Menu." -ForegroundColor Gray
Write-Host "  2. Tap 'Dev Settings' -> 'Debug server host & port for device'." -ForegroundColor Gray
Write-Host "  3. Enter '${HostIp}:8081' (Customer), '${HostIp}:8082' (Store), or '${HostIp}:8083' (Rider)." -ForegroundColor Gray
Write-Host "  4. Reload app. It bundles directly from this PC over Wi-Fi." -ForegroundColor Green
Write-Host ""
