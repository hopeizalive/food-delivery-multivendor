const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');

const PORT = process.env.PORT || 8080;
const APK_DIR = path.resolve(__dirname, '..', 'dist', 'apks');

// Discover all local network IPv4 addresses
function getNetworkInfo() {
  const interfaces = os.networkInterfaces();
  const list = [];
  for (const name of Object.keys(interfaces)) {
    for (const net of interfaces[name]) {
      if (net.family === 'IPv4' && !net.internal) {
        list.push({ name, ip: net.address, url: `http://${net.address}:${PORT}` });
      }
    }
  }
  return list;
}

// Get APK metadata
function getApks() {
  const result = [];
  if (!fs.existsSync(APK_DIR)) return result;

  const files = fs.readdirSync(APK_DIR);
  for (const file of files) {
    if (file.endsWith('.apk')) {
      const fullPath = path.join(APK_DIR, file);
      const stat = fs.statSync(fullPath);
      let role = 'App';
      let icon = '📱';
      let color = '#3b82f6';

      if (file.includes('rider')) {
        role = 'Rider Delivery App';
        icon = '🛵';
        color = '#10b981';
      } else if (file.includes('store')) {
        role = 'Store / Merchant App';
        icon = '🏪';
        color = '#f59e0b';
      } else if (file.includes('app')) {
        role = 'Customer Ordering App';
        icon = '🍔';
        color = '#8b5cf6';
      }

      result.push({
        filename: file,
        role,
        icon,
        color,
        sizeMb: (stat.size / (1024 * 1024)).toFixed(2),
        sizeBytes: stat.size,
        path: fullPath
      });
    }
  }
  return result;
}

// HTML Download Page
function renderHtml(req) {
  const apks = getApks();
  const netInfo = getNetworkInfo();
  const clientIp = req.socket.remoteAddress.replace('::ffff:', '');

  const apkCards = apks.map(apk => `
    <div class="card" style="--accent: ${apk.color};">
      <div class="card-icon">${apk.icon}</div>
      <div class="card-content">
        <div class="card-role">${apk.role}</div>
        <div class="card-name">${apk.filename}</div>
        <div class="card-size">📦 ${apk.sizeMb} MB</div>
      </div>
      <a href="/download/${encodeURIComponent(apk.filename)}" class="btn-download" download="${apk.filename}">
        Download APK
      </a>
    </div>
  `).join('');

  const ipList = netInfo.map(n => `<code>${n.url}</code> (${n.name})`).join('<br>');

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Food Delivery Apps - Direct APK Download</title>
  <style>
    :root {
      --bg: #0b0f19;
      --surface: #141c2e;
      --border: #23314f;
      --text: #f8fafc;
      --muted: #94a3b8;
      --primary: #3b82f6;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: var(--bg);
      color: var(--text);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 24px 16px;
    }
    .container {
      width: 100%;
      max-width: 580px;
    }
    .header {
      text-align: center;
      margin-bottom: 24px;
    }
    .badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 6px 14px;
      border-radius: 9999px;
      background: rgba(16, 185, 129, 0.15);
      border: 1px solid rgba(16, 185, 129, 0.3);
      color: #34d399;
      font-size: 13px;
      font-weight: 600;
      margin-bottom: 12px;
    }
    .badge-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: #10b981;
      box-shadow: 0 0 10px #10b981;
    }
    h1 {
      font-size: 24px;
      font-weight: 700;
      margin-bottom: 6px;
      letter-spacing: -0.5px;
    }
    p.sub {
      color: var(--muted);
      font-size: 14px;
    }
    .card-list {
      display: flex;
      flex-direction: column;
      gap: 16px;
      margin-bottom: 28px;
    }
    .card {
      background: var(--surface);
      border: 1px solid var(--border);
      border-left: 4px solid var(--accent);
      border-radius: 12px;
      padding: 16px 18px;
      display: flex;
      align-items: center;
      gap: 16px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.25);
    }
    .card-icon {
      font-size: 32px;
      line-height: 1;
    }
    .card-content {
      flex: 1;
      min-width: 0;
    }
    .card-role {
      font-size: 16px;
      font-weight: 600;
      color: var(--text);
    }
    .card-name {
      font-size: 12px;
      color: var(--muted);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      margin-top: 2px;
      font-family: monospace;
    }
    .card-size {
      font-size: 12px;
      color: #38bdf8;
      margin-top: 4px;
      font-weight: 500;
    }
    .btn-download {
      background: var(--accent);
      color: #fff;
      text-decoration: none;
      font-weight: 600;
      font-size: 14px;
      padding: 10px 18px;
      border-radius: 8px;
      white-space: nowrap;
      transition: opacity 0.15s, transform 0.15s;
    }
    .btn-download:active {
      transform: scale(0.96);
      opacity: 0.9;
    }
    .info-box {
      background: rgba(30, 41, 59, 0.7);
      border: 1px solid var(--border);
      border-radius: 10px;
      padding: 16px;
      font-size: 13px;
      color: var(--muted);
      line-height: 1.6;
    }
    .info-box strong { color: var(--text); }
    code {
      background: rgba(0,0,0,0.35);
      padding: 2px 6px;
      border-radius: 4px;
      color: #38bdf8;
      font-family: monospace;
      font-size: 12px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="badge">
        <span class="badge-dot"></span>
        Device Connected (${clientIp})
      </div>
      <h1>Food Delivery APK Downloads</h1>
      <p class="sub">Tap below to download directly over the local network</p>
    </div>

    <div class="card-list">
      ${apkCards}
    </div>

    <div class="info-box">
      <strong>Network Server Active:</strong><br>
      ${ipList}<br><br>
      <strong>Installation Note:</strong> After downloading, open your phone's notification shade or Files app and tap the APK to install.
    </div>
  </div>
</body>
</html>`;
}

// Stream file with HTTP 206 Range support for fast and resumable downloads
function streamApk(req, res, filename) {
  const safeFilename = path.basename(filename);
  const filePath = path.join(APK_DIR, safeFilename);

  if (!fs.existsSync(filePath)) {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('APK not found: ' + safeFilename);
    return;
  }

  const clientIp = req.socket.remoteAddress.replace('::ffff:', '');
  const userAgent = req.headers['user-agent'] || 'Unknown';
  console.log(`\n\x1b[32m[DOWNLOAD STARTED]\x1b[0m ${safeFilename}`);
  console.log(`  Device IP: \x1b[36m${clientIp}\x1b[0m`);
  console.log(`  User-Agent: ${userAgent.slice(0, 70)}...`);

  const stat = fs.statSync(filePath);
  const totalSize = stat.size;
  const range = req.headers.range;

  if (range) {
    const parts = range.replace(/bytes=/, '').split('-');
    const start = parseInt(parts[0], 10);
    const end = parts[1] ? parseInt(parts[1], 10) : totalSize - 1;

    if (start >= totalSize || end >= totalSize) {
      res.writeHead(416, { 'Content-Range': `bytes */${totalSize}` });
      return res.end();
    }

    const chunkSize = end - start + 1;
    res.writeHead(206, {
      'Content-Range': `bytes ${start}-${end}/${totalSize}`,
      'Accept-Ranges': 'bytes',
      'Content-Length': chunkSize,
      'Content-Type': 'application/vnd.android.package-archive',
      'Content-Disposition': `attachment; filename="${safeFilename}"`
    });

    const stream = fs.createReadStream(filePath, { start, end });
    stream.pipe(res);
  } else {
    res.writeHead(200, {
      'Content-Length': totalSize,
      'Content-Type': 'application/vnd.android.package-archive',
      'Accept-Ranges': 'bytes',
      'Content-Disposition': `attachment; filename="${safeFilename}"`
    });
    fs.createReadStream(filePath).pipe(res);
  }
}

const server = http.createServer((req, res) => {
  const clientIp = req.socket.remoteAddress.replace('::ffff:', '');
  const userAgent = req.headers['user-agent'] || 'Unknown Device';
  const parsedUrl = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const pathname = parsedUrl.pathname;

  if (clientIp !== '127.0.0.1' && clientIp !== '::1') {
    console.log('\n======================================================');
    console.log(`\x1b[32m[LOCAL NETWORK VERIFIED] Device reached server!\x1b[0m`);
    console.log(`  Phone IP:    \x1b[36m${clientIp}\x1b[0m`);
    console.log(`  Device info: ${userAgent.slice(0, 80)}`);
    console.log(`  Endpoint:    ${pathname}`);
    console.log('======================================================\n');
  } else {
    console.log(`[LOCAL ACCESS] ${req.method} ${pathname} from ${clientIp}`);
  }

  if (pathname === '/' || pathname === '/index.html' || pathname === '/verify') {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(renderHtml(req));
    return;
  }

  if (pathname.startsWith('/download/')) {
    const filename = decodeURIComponent(pathname.replace('/download/', ''));
    return streamApk(req, res, filename);
  }

  res.writeHead(404, { 'Content-Type': 'text/plain' });
  res.end('404 Not Found');
});

server.listen(PORT, '0.0.0.0', () => {
  console.log('======================================================');
  console.log('      LOCAL NETWORK DEVICE VERIFICATION & APK SERVER   ');
  console.log('======================================================');
  console.log('To verify connection & download APKs, open this on your phone:');
  const addrs = getNetworkInfo();
  addrs.forEach(a => {
    console.log(`  --> \x1b[32m${a.url}\x1b[0m  (${a.name})`);
  });
  console.log('======================================================\n');
});
