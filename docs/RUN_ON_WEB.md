# Running & Serving CPF Mobile (`cpf_mobile`) on the Web

This guide explains how to run CPF Mobile in a browser during development or serve a production static build locally (or over a Cloudflare Tunnel).

---

## Quick-Start Cheat Sheet

Once the one-time web setup below is done, run either of these from `C:\laragon\www\cpf_mobile`:

```powershell
# Option 1: Interactive dev mode in Chrome (hot restart with 'r')
flutter run -d chrome --web-port=5050

# Option 2: Headless web server (open http://localhost:5050 in any browser)
flutter run -d web-server --web-hostname=127.0.0.1 --web-port=5050

# Option 3: Build & serve static release bundle
flutter build web --release
python -m http.server 5050 --directory build/web
```

> **Tip:** Always pass a fixed `--web-port=5050` so your saved **Server URL**, **Theme** (`Soft Cream`, `Dark`, `Sunrise`, `Joy`, `Vice`), and **Bearer token** remain intact in browser storage across restarts.

---

## 1. One-Time Web Setup

Because this repository was initially scaffolded for Android only (`android/` exists, root `web/` does not yet exist), generate the `web/` folder once before your first web run:

```powershell
cd C:\laragon\www\cpf_mobile

# Ensure Flutter web support is enabled
flutter config --enable-web

# Generate the root web/ directory (index.html, manifest.json, icons/)
flutter create --platforms=web .

# Optional: set the browser tab favicon to the official CPF emblem
Copy-Item assets\images\cpf_logo.png web\favicon.png -Force
```

Verify Chrome / Edge / `web-server` appear as available targets:

```powershell
flutter devices
```

---

## 2. Option A — Run in Development Mode

### Launch directly in Chrome or Edge

```powershell
# Google Chrome
flutter run -d chrome --web-port=5050

# Microsoft Edge
flutter run -d edge --web-port=5050
```

Inside the running terminal:
- Press **`r`** for Hot Reload
- Press **`R`** for Hot Restart
- Press **`q`** to stop the dev server

### Serve headless (`web-server`) for any browser or LAN device

```powershell
# Localhost only
flutter run -d web-server --web-hostname=127.0.0.1 --web-port=5050

# Or bind to all interfaces (0.0.0.0) to test from another device on your Wi-Fi
flutter run -d web-server --web-hostname=0.0.0.0 --web-port=5050
```

Open `http://127.0.0.1:5050` (or `http://localhost:5050`) in your browser.

---

## 3. Option B — Build & Serve a Release Static Bundle

Compile an optimized static web build into `build\web\`:

```powershell
flutter build web --release
```

Serve `build\web\` using any static HTTP server:

```powershell
# Using Python 3 (built into most dev setups)
python -m http.server 5050 --directory build/web

# Or using Node.js `serve`
npx serve build/web -l 5050
```

Then visit `http://localhost:5050`.

### Optional: Expose the Web App via Cloudflare Tunnel

If you want to demo the web build over HTTPS (also required by browsers to unlock webcam access on non-localhost origins):

```powershell
cloudflared tunnel --url http://localhost:5050
```

---

## 4. Configuring the Backend Server URL in the Browser

By default, `lib/config/api_config.dart` sets `defaultBaseUrl = 'http://10.0.2.2:8000'`.  
`10.0.2.2` only works inside the **Android Emulator** — desktop browsers cannot reach `10.0.2.2`.

When the Login screen opens in your browser:

1. Click the **`Server URL`** button in the top-right header.
2. Choose one of the following:
   - Click the **`Localhost (127.0.0.1:8000)`** quick-fill chip (if running `php artisan serve --port=8000`).
   - Enter your Laragon URL (for example `http://localhost/cpf/public`).
   - Enter your Cloudflare Tunnel HTTPS backend URL (for example `https://your-api-tunnel.trycloudflare.com`).
3. Click **`Save URL`**. The app automatically appends `/api/v1` and persists the URL in browser storage.

---

## 5. Web Troubleshooting

### A. CORS Errors (`XMLHttpRequest` / `connectionError` in Chrome DevTools)
Unlike Android, web browsers enforce **CORS** when `http://localhost:5050` calls a different origin/port such as `http://127.0.0.1:8000` or `http://localhost/cpf/public`.

In your Laravel backend (`config/cors.php`):
- Ensure `'paths'` includes `'api/*'`.
- Ensure `'allowed_origins'` includes your web origin (e.g. `'http://localhost:5050'`, `'http://127.0.0.1:5050'`, or `'*'` during local testing).
- Ensure `'allowed_methods'` and `'allowed_headers'` allow `GET`, `POST`, `Accept`, `Content-Type`, and `Authorization`.
- Clear Laravel config cache after editing:
  ```bash
  php artisan config:clear
  ```

### B. QR Camera Scanner on Web (`mobile_scanner`)
- Browsers only grant webcam access on **secure contexts** (`https://...` or `http://localhost:...` / `http://127.0.0.1:...`). Plain `http://<lan-ip>:5050` blocks camera access.
- If a desktop device has no webcam or camera permission is denied, switch to the **`Manual Checklist`** tab inside the Officer Attendance Scanner to enter Member IDs (`CPF-ALIJIS-2026-0019`) or paste QR payloads directly.

### C. Saved Settings Disappeared Between Runs
`flutter_secure_storage` on Flutter Web scopes storage (`localStorage` / WebCrypto) to the exact origin (`scheme + host + port`). Always run with the same `--web-port=5050` so your saved Server URL, active theme, and token stay intact.
