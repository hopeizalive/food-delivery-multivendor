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

One terminal tab per app:

```bash
cd multivendor-app && npx expo start --port 8081
```
```bash
cd multivendor-rider && npx expo start --port 8082
```
```bash
cd multivendor-store && npx expo start --port 8083
```

## 4. Make the ports reachable from your phone

**Ports** tab (bottom panel) → for each of 8081/8082/8083 → right-click →
**Port Visibility** → **Public**.

## 5. Open in Expo Go

Copy each port's forwarded URL from the Ports tab
(`https://<codespace-name>-8081.app.github.dev`, etc). In Expo Go on your
phone: **Enter URL manually** → paste it. Repeat per app/port — all three
stay running at once, so you can switch between them without restarting.

> Don't use `expo start --tunnel` for more than one app at a time — it goes
> through ngrok, whose free tier allows only one tunnel per machine. Port
> forwarding (above) has no such limit.
