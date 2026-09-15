# Quickstart: Run in GitHub Codespaces

Fast path to a running app in a fresh Codespace. Full details, flags, and
troubleshooting: [BUILD_SETUP.md](BUILD_SETUP.md).

## 1. Create the Codespace

GitHub → **Code** → **Codespaces** → **Create codespace on this branch**.
Setup (`scripts/build-setup/setup-all.sh`) runs automatically — wait for it
to print `all done` in the terminal.

## 2. (Optional) Confirm it builds

```bash
bash scripts/build-setup/verify-build.sh
```

## 3. Start each app on its own port

One terminal tab per app — use `start-app.sh`, not `expo start` directly.
It detects Codespaces and points Metro at your Codespace's own forwarded
domain automatically, so the QR code / dev-client deep link it prints
works straight away on your phone (no `--tunnel`, no ngrok, no manual
URL-pasting):

```bash
bash scripts/build-setup/start-app.sh multivendor-app 8081
```
```bash
bash scripts/build-setup/start-app.sh multivendor-rider 8082
```
```bash
bash scripts/build-setup/start-app.sh multivendor-store 8083
```

All three can run at once — scan whichever QR code you need, switch
between apps without restarting anything.

Ports 8081/8082/8083 are already set to **Public** visibility in
`.devcontainer/devcontainer.json`, so there's no manual Ports-tab step.
If you forked/customized the devcontainer and lost that, set it manually:
**Ports** tab (bottom panel) → right-click the port → **Port Visibility**
→ **Public**.

> Plain `npx expo start --port <n>` still works, but its QR code embeds
> the container's internal LAN IP (e.g. `10.0.1.45`), which your phone
> can't reach — that's what `start-app.sh` fixes. `--tunnel` (ngrok) is
> a fallback for containers without Codespaces' env vars, but only one
> tunnel runs at a time on ngrok's free tier.

> All three apps depend on `expo-dev-client`, so the QR code/link above
> only opens in each app's own **custom dev-client build** — not the
> generic Expo Go app from the App/Play Store. If that build isn't on your
> phone yet, see step 4.

## 4. Don't have the app installed yet? Build an APK, no EAS needed

```bash
bash scripts/build-setup/setup-android.sh        # once per container
bash scripts/build-setup/build-apk.sh multivendor-rider
bash scripts/build-setup/serve-apks.sh            # QR code to scan + download
```

Slower than steps 1–3 (a real Gradle build, ~15–25 min first time) but
free of EAS build credits — see [BUILD_SETUP.md](BUILD_SETUP.md#native-builds)
for the full explanation and the other two apps.
