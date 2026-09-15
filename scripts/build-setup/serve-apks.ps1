param (
    [int]$Port = 9000
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Resolve-Path "$ScriptDir\..\.."
$OutDir = Join-Path $Root "dist\apks"
$QrDir = Join-Path $OutDir "qr"

if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
}
if (-not (Test-Path $QrDir)) {
    New-Item -ItemType Directory -Force -Path $QrDir | Out-Null
}

# Ensure APKs are synced from build outputs if needed
$Apps = @(
    @{ Name = "Customer App (multivendor-app)"; Source = "$Root\multivendor-app\android\app\build\outputs\apk\debug\app-debug.apk"; Target = "$OutDir\multivendor-app-debug.apk"; Filename = "multivendor-app-debug.apk" },
    @{ Name = "Store App (multivendor-store)"; Source = "$Root\multivendor-store\android\app\build\outputs\apk\debug\app-debug.apk"; Target = "$OutDir\multivendor-store-debug.apk"; Filename = "multivendor-store-debug.apk" },
    @{ Name = "Rider App (multivendor-rider)"; Source = "$Root\multivendor-rider\android\app\build\outputs\apk\debug\app-debug.apk"; Target = "$OutDir\multivendor-rider-debug.apk"; Filename = "multivendor-rider-debug.apk" }
)

foreach ($item in $Apps) {
    if (-not (Test-Path $item.Target) -and (Test-Path $item.Source)) {
        Write-Host "[build-setup] Syncing $($item.Filename) to dist\apks\..." -ForegroundColor Yellow
        Copy-Item -Path $item.Source -Destination $item.Target -Force
    }
}

$ApkFiles = Get-ChildItem -Path $OutDir -Filter "*.apk"
if ($ApkFiles.Count -eq 0) {
    Write-Host "[build-setup] Error: No APKs found in $OutDir!" -ForegroundColor Red
    Write-Host "Please build them first or verify build output folders." -ForegroundColor Red
    exit 1
}

# Determine local network IPv4 address for phone downloads
$LocalIP = "localhost"
try {
    $ipObj = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
        $_.InterfaceAlias -notmatch 'vEthernet|Loopback|WSL|Pseudo' -and
        $_.IPAddress -notmatch '^127\.' -and
        $_.IPAddress -notmatch '^169\.254'
    } | Select-Object -First 1
    if ($ipObj) {
        $LocalIP = $ipObj.IPAddress
    }
} catch {
    # Fallback to localhost if Get-NetIPAddress is restricted
}

$BaseUrl = "http://${LocalIP}:${Port}"
$LocalUrl = "http://localhost:${Port}"

Write-Host "`n[build-setup] Generating QR codes and download portal..." -ForegroundColor Cyan

$CardsHtml = ""
foreach ($file in $ApkFiles) {
    $name = $file.Name
    $sizeMB = [math]::Round($file.Length / 1MB, 1)
    $url = "$BaseUrl/$name"

    $encodedUrl = [Uri]::EscapeDataString($url)
    $qrSrc = "https://api.qrserver.com/v1/create-qr-code/?size=160x160&data=$encodedUrl"

    $title = $name
    if ($name -match 'multivendor-app') { $title = "Customer App" }
    elseif ($name -match 'multivendor-store') { $title = "Store App" }
    elseif ($name -match 'multivendor-rider') { $title = "Rider App" }

    $CardsHtml += @"
    <div class="card">
      <img src="$qrSrc" alt="QR Code for $title" class="qr-img" onerror="this.style.display='none'" />
      <div class="card-info">
        <h3>$title</h3>
        <p class="filename">$name</p>
        <div class="meta">
          <span class="badge">$sizeMB MB</span>
          <span class="badge badge-date">$($file.LastWriteTime.ToString("yyyy-MM-dd HH:mm"))</span>
        </div>
        <a class="btn-download" href="$name" download>Download APK</a>
      </div>
    </div>
"@
}

$HtmlContent = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Food Delivery Apps - Team APK Downloads</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    :root {
      --primary: #2563eb;
      --primary-hover: #1d4ed8;
      --bg: #0f172a;
      --card-bg: #1e293b;
      --border: #334155;
      --text: #f8fafc;
      --text-dim: #94a3b8;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      background: var(--bg);
      color: var(--text);
      padding: 32px 16px;
      display: flex;
      justify-content: center;
    }
    .container {
      max-width: 680px;
      width: 100%;
    }
    header {
      text-align: center;
      margin-bottom: 32px;
    }
    h1 {
      font-size: 1.8rem;
      font-weight: 700;
      margin-bottom: 8px;
      background: linear-gradient(135deg, #60a5fa, #a78bfa);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    p.subtitle {
      color: var(--text-dim);
      font-size: 0.95rem;
      line-height: 1.5;
    }
    .card {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 20px;
      margin-bottom: 20px;
      display: flex;
      gap: 20px;
      align-items: center;
      box-shadow: 0 4px 16px rgba(0,0,0,0.3);
      transition: transform 0.2s ease, border-color 0.2s ease;
    }
    .card:hover {
      border-color: #475569;
      transform: translateY(-2px);
    }
    .qr-img {
      width: 130px;
      height: 130px;
      border-radius: 10px;
      background: #ffffff;
      padding: 6px;
      flex-shrink: 0;
    }
    .card-info {
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .card-info h3 {
      font-size: 1.25rem;
      font-weight: 600;
    }
    .filename {
      font-size: 0.82rem;
      color: var(--text-dim);
      font-family: monospace;
    }
    .meta {
      display: flex;
      gap: 8px;
      align-items: center;
      margin: 4px 0;
    }
    .badge {
      background: #334155;
      color: #cbd5e1;
      font-size: 0.75rem;
      padding: 3px 8px;
      border-radius: 6px;
      font-weight: 500;
    }
    .badge-date {
      color: #94a3b8;
    }
    .btn-download {
      display: inline-block;
      text-decoration: none;
      background: var(--primary);
      color: #ffffff;
      font-weight: 600;
      font-size: 0.9rem;
      padding: 10px 18px;
      border-radius: 8px;
      text-align: center;
      transition: background 0.2s;
      align-self: flex-start;
    }
    .btn-download:hover {
      background: var(--primary-hover);
    }
    .instructions {
      margin-top: 32px;
      padding: 18px;
      border-radius: 12px;
      background: rgba(30, 41, 59, 0.6);
      border: 1px dashed var(--border);
      font-size: 0.85rem;
      color: var(--text-dim);
      line-height: 1.6;
    }
    .instructions h4 {
      color: var(--text);
      margin-bottom: 6px;
      font-size: 0.95rem;
    }
    ol { padding-left: 20px; }
    @media (max-width: 520px) {
      .card {
        flex-direction: column;
        text-align: center;
      }
      .card-info {
        align-items: center;
      }
      .btn-download {
        align-self: stretch;
      }
    }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>Team APK Downloads</h1>
      <p class="subtitle">Scan the QR code with your phone camera or tap <strong>Download APK</strong> to install.</p>
    </header>

    $CardsHtml

    <div class="instructions">
      <h4>How to Install on Android:</h4>
      <ol>
        <li>Scan the QR code above with your mobile phone camera or open this page in Chrome.</li>
        <li>Tap <strong>Download APK</strong> and wait for the file to finish downloading.</li>
        <li>Tap the completed notification or file in Downloads and choose <strong>Install</strong>.</li>
        <li>If prompted with <em>"Install unknown apps"</em>, toggle <strong>Allow from this source</strong> in Settings.</li>
      </ol>
    </div>
  </div>
</body>
</html>
"@

$IndexPath = Join-Path $OutDir "index.html"
Set-Content -Path $IndexPath -Value $HtmlContent -Encoding UTF8

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "  Team APK Download Server Ready!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host "`n  Local PC URL:   $LocalUrl" -ForegroundColor Cyan
Write-Host "  Phone/Wi-Fi URL: $BaseUrl" -ForegroundColor Yellow
Write-Host "`n  * Make sure your phone is connected to the same Wi-Fi network." -ForegroundColor Gray
Write-Host "  * Scan QR codes directly with your phone camera or visit the Wi-Fi URL.`n" -ForegroundColor Gray

# Start http server
if (Get-Command "npx.cmd" -ErrorAction SilentlyContinue) {
    Write-Host "Starting http-server on port $Port (Press Ctrl+C to stop)...`n" -ForegroundColor White
    Set-Location $OutDir
    & npx.cmd --yes http-server . -p $Port -a 0.0.0.0 --cors -c-1
} elseif (Get-Command "python.exe" -ErrorAction SilentlyContinue) {
    Write-Host "Starting python http.server on port $Port (Press Ctrl+C to stop)...`n" -ForegroundColor White
    Set-Location $OutDir
    & python.exe -m http.server $Port --bind 0.0.0.0
} else {
    Write-Host "Please install node/npx or python to host the server automatically." -ForegroundColor Red
}
