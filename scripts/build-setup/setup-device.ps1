# One-shot setup for testing the Expo apps on a physical Android device
# connected over USB (adb), from native Windows PowerShell (no WSL/Git
# Bash required). Verifies the device, wires up `adb reverse` for each
# app's Metro port so the device can reach Metro over the USB cable (no
# Wi-Fi/LAN needed), and starts any Metro bundlers that aren't already
# running.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\scripts\build-setup\setup-device.ps1 [-App customer|store|rider|all]
#
# Examples:
#   .\scripts\build-setup\setup-device.ps1            # all three apps
#   .\scripts\build-setup\setup-device.ps1 -App rider  # rider only

param(
    [ValidateSet("customer", "store", "rider", "all")]
    [string]$App = "all"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Resolve-Path "$ScriptDir\..\.."

$AppDirs = @{
    customer = "multivendor-app"
    store    = "multivendor-store"
    rider    = "multivendor-rider"
}
$AppPorts = @{
    customer = 8081
    store    = 8082
    rider    = 8083
}

$Targets = if ($App -eq "all") { @("customer", "store", "rider") } else { @($App) }

function Write-Log($msg) { Write-Host "[build-setup] $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "[build-setup] warning: $msg" -ForegroundColor Yellow }
function Write-Err($msg) { Write-Host "[build-setup] error: $msg" -ForegroundColor Red }

# 1. adb + device check
$adb = Get-Command adb -ErrorAction SilentlyContinue
if (-not $adb) {
    Write-Err "adb not found on PATH. Install Android platform-tools first."
    exit 1
}

$deviceLines = & adb devices | Select-Object -Skip 1 | Where-Object { $_.Trim() -ne "" }
$connected = $deviceLines | Where-Object { $_ -match "\tdevice$" }

if (-not $connected) {
    Write-Err "no device connected. Plug in the phone via USB, enable USB debugging, and accept the 'Allow USB debugging?' prompt."
    if ($deviceLines) { $deviceLines | ForEach-Object { Write-Host "  $_" } }
    exit 1
}
if (@($connected).Count -gt 1) {
    Write-Warn "multiple devices detected, using the first one listed. Pass -DeviceId or set ANDROID_SERIAL to pin a specific one."
}

$DeviceId = (@($connected)[0] -split "\t")[0]
Write-Log "using device: $DeviceId"

# 2. Reverse tunnels — lets the USB-connected device reach 127.0.0.1:<port>
#    on this machine as its own localhost:<port>, so Metro's QR/dev-client
#    deep link (which points at localhost) works with no LAN/Wi-Fi step.
foreach ($t in $Targets) {
    $port = $AppPorts[$t]
    & adb -s $DeviceId reverse "tcp:$port" "tcp:$port" | Out-Null
    Write-Log "adb reverse tcp:$port <-> tcp:$port ($t)"
}

# 3. Start Metro for any app not already running; skip ones that are.
function Test-PortListening([int]$Port) {
    $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    return [bool]$conn
}

foreach ($t in $Targets) {
    $dir = $AppDirs[$t]
    $port = $AppPorts[$t]
    $appPath = Join-Path $Root $dir

    if (-not (Test-Path $appPath)) {
        Write-Warn "[$t] directory not found: $appPath -- skipping"
        continue
    }

    if (Test-PortListening $port) {
        Write-Log "[$t] Metro already running on port $port -- leaving it as-is"
        continue
    }

    Write-Log "[$t] starting Metro on port $port"
    $logFile = Join-Path $appPath ".metro-$port.log"
    Start-Process -FilePath "npx" -ArgumentList "expo", "start", "--port", "$port" `
        -WorkingDirectory $appPath `
        -RedirectStandardOutput $logFile -RedirectStandardError "$logFile.err" `
        -WindowStyle Hidden
}

# 4. Wait for each requested app's port to come up, then report status.
Write-Log "waiting for Metro bundlers to come up..."
foreach ($t in $Targets) {
    $dir = $AppDirs[$t]
    $port = $AppPorts[$t]
    $appPath = Join-Path $Root $dir
    if (-not (Test-Path $appPath)) { continue }

    $ready = $false
    for ($i = 0; $i -lt 30; $i++) {
        if (Test-PortListening $port) { $ready = $true; break }
        Start-Sleep -Seconds 1
    }

    if ($ready) {
        Write-Host "  [OK]      $t -- http://localhost:$port (device reaches it via adb reverse)" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] $t -- Metro did not come up on port $port, check $appPath\.metro-$port.log" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Next steps on the device:" -ForegroundColor Cyan
Write-Host "  - Open the Expo dev-client / app build already installed on the phone."
Write-Host "  - It should connect automatically via the USB reverse tunnel(s) above."
Write-Host "  - If an app shows a 'no bundler found' screen, shake the device (or run:"
Write-Host "    adb -s $DeviceId shell input keyevent 82) and pick 'Change bundle"
Write-Host "    location' -> host 'localhost', the app's port from the list above."
Write-Host ""
Write-Host "Re-run this script any time the device is reconnected (adb reverse tunnels"
Write-Host "do not survive a USB replug)."
