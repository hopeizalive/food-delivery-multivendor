# Start all 3 mobile apps (Metro bundlers) simultaneously on distinct ports with ADB port forwarding
# Usage: powershell -ExecutionPolicy Bypass -File .\start-all-apps.ps1

Write-Host "`n[start-all] Setting up ADB port forwarding for all 3 apps over USB..." -ForegroundColor Cyan

try {
    adb reverse tcp:8081 tcp:8081
    adb reverse tcp:8082 tcp:8082
    adb reverse tcp:8083 tcp:8083
    Write-Host "  [OK] Forwarded 8081 (Customer), 8082 (Store), 8083 (Rider) over USB`n" -ForegroundColor Green
} catch {
    Write-Host "  [WARNING] Could not run adb reverse. Make sure phone is connected." -ForegroundColor Yellow
}

Write-Host "[start-all] Launching Metro bundlers in separate windows..." -ForegroundColor Cyan

# 1. Customer App on port 8081
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host '--- Customer App (Port 8081) ---' -ForegroundColor Cyan; cd d:\fd\multivendor-app; npx expo start --port 8081"

# 2. Store App on port 8082
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host '--- Store App (Port 8082) ---' -ForegroundColor Yellow; cd d:\fd\multivendor-store; npx expo start --port 8082"

# 3. Rider App on port 8083
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host '--- Rider App (Port 8083) ---' -ForegroundColor Magenta; cd d:\fd\multivendor-rider; npx expo start --port 8083"

Write-Host "`nAll 3 Metro bundlers launched!" -ForegroundColor Green
Write-Host "On your phone:" -ForegroundColor White
Write-Host "  * Customer App connects to http://localhost:8081" -ForegroundColor Cyan
Write-Host "  * Store App connects to    http://localhost:8082" -ForegroundColor Yellow
Write-Host "  * Rider App connects to    http://localhost:8083`n" -ForegroundColor Magenta
