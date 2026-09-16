# APK Local Download & Verification Server

A lightweight, zero-dependency Node.js HTTP server designed to distribute Android APKs over the local network and verify mobile device connectivity.

---

## Features

* **Zero Dependencies:** Runs on standard Node.js built-ins (`http`, `fs`, `path`, `os`).
* **HTTP 206 Partial Content (Range Support):** Allows Android Chrome and download managers to stream large APKs in parallel chunks with resume capability.
* **Auto IP Discovery:** Automatically detects all active local IPv4 network adapters (Wi-Fi, Ethernet, Hotspot).
* **Live Connection Logging:** Prints incoming device connections, IP addresses, and User-Agents directly in the terminal.
* **Mobile-Optimized Web UI:** Clean, responsive dark-mode web page with direct download buttons for all available APKs in `dist/apks`.

---

## Quick Start

### Starting Standalone
```powershell
node d:\fd\apk-download-server\server.js
```

### Starting via All-in-One Launcher
The download server is automatically started as part of the multi-app launcher:
```powershell
.\start-all-apps.ps1
```

---

## Accessing from Mobile Device

1. Ensure your phone and PC are connected to the same Wi-Fi network (or phone Personal Hotspot).
2. Open Chrome on your phone and navigate to:
   ```text
   http://<YOUR_PC_IP>:8080
   ```
   *(e.g., `http://10.13.0.44:8080`)*
3. Tap any of the download buttons to download the APK directly:
   * **Customer App:** `multivendor-app-debug.apk`
   * **Rider App:** `multivendor-rider-debug.apk`
   * **Store App:** `multivendor-store-debug.apk`
4. Once downloaded, open the APK from your phone's notification bar or Files app to install.
