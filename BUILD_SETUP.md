# Container Build Setup

Scripts and config for getting the three Expo apps — `multivendor-app`,
`multivendor-rider`, `multivendor-store` — installed, configured, and
verified to build inside a fresh container: a GitHub Codespace, another
devcontainer, or plain CI. Covers JS-level builds only (install, env,
typecheck, lint, `expo export`) — native Android/iOS binaries are still
built on EAS's cloud infrastructure, not in this container.

## What's here

```
.devcontainer/devcontainer.json     # Codespaces/devcontainer config
scripts/build-setup/
  setup-all.sh                      # entry point: installs deps + writes .env for all 3 apps
  setup-app.sh                      # same, for a single app
  start-app.sh                      # run one app's dev server, reachable from a phone
  verify-build.sh                   # typecheck + lint (+ optional `expo export`)
  lib.sh                            # shared shell helpers
  env-templates/*.env               # .env template per app
```

## GitHub Codespaces

Opening a Codespace on this repo runs `scripts/build-setup/setup-all.sh`
automatically via `postCreateCommand` — dependencies installed and `.env`
written for all three apps by the time the container is ready. Run
`bash scripts/build-setup/verify-build.sh` afterwards to confirm the apps
actually build.

## Testing on a physical device (QR code / dev client)

Plain `npx expo start` advertises the container's own internal LAN IP
(e.g. `10.0.1.45`) in its QR code and dev-client deep link — unreachable
from a phone that isn't on the same network, which is always the case for
a cloud container. Use `start-app.sh` instead of calling `expo start`
directly:

```bash
bash scripts/build-setup/start-app.sh multivendor-rider 8082
```

In a Codespace, it detects the `CODESPACES`/`CODESPACE_NAME`/
`GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN` env vars Codespaces injects
automatically and sets `EXPO_PACKAGER_PROXY_URL` to that Codespace's own
forwarded domain before starting Metro. `@expo/cli` reads that env var
ahead of everything else when building the manifest/bundle/websocket URLs
(see `UrlCreator.js`'s `getProxyUrl()`), so the QR code / deep link it
prints points at a URL your phone can actually reach — no `--tunnel`,
no ngrok, and (unlike ngrok's free-tier one-tunnel limit) all three apps
can run this way at once. The port still needs Public visibility, which
`.devcontainer/devcontainer.json` already sets for 8081/8082/8083.

Outside Codespaces (plain Docker, other CI), those env vars won't be set,
`start-app.sh` warns and falls back to Metro's default LAN behavior — use
`npx expo start --port <n> --tunnel` there instead.

## Any other container / CI

No devcontainer support needed — the scripts are plain bash with no
Codespaces-specific dependency:

```bash
bash scripts/build-setup/setup-all.sh
bash scripts/build-setup/verify-build.sh
```

Requires Node 20.x (`.nvmrc` in each app pins `v20.16.0`) and npm ≥10 on
`PATH`; `setup-all.sh` warns but doesn't fail on a mismatched Node major
version.

### Options

```bash
# only set up one app
bash scripts/build-setup/setup-all.sh multivendor-rider

# overwrite an existing .env instead of leaving it alone
bash scripts/build-setup/setup-all.sh --force

# point every app at a different GraphQL/REST/WS host, e.g. a mock-api
# running locally instead of the hosted demo instance
bash scripts/build-setup/setup-all.sh --api-url http://localhost:4000

# also run a real Metro bundle (`expo export`), not just typecheck/lint
bash scripts/build-setup/verify-build.sh --full
```

`setup-app.sh` takes the same `--force`/`--api-url` flags for a single app,
e.g. `bash scripts/build-setup/setup-app.sh multivendor-store --force`.

## What `setup-all.sh` actually does

For each app:

1. `npm ci` (or `npm install` if there's no lockfile yet), with
   `--legacy-peer-deps` since that's what these apps' own docs/CI expect.
2. Writes `.env` from `scripts/build-setup/env-templates/<app>.env`, with
   the GraphQL/REST/WS URLs filled in — **unless `.env` already exists**,
   so it never clobbers a developer's real credentials without `--force`.

## Env defaults: the hosted mock-api

There's no real backend credential checked into this repo (see the root
`CLAUDE.md` — `multivendor-api` is a separate, private repo). By default
the generated `.env` files point at the same hosted demo backend the repo's
own untracked `.env` files already use:
`https://enatega-demo-mock-api.onrender.com` — the deployed instance of
[`mock-api`](mock-api/) in this repo (see `mock-api/DEPLOYMENT.md`). That's
enough for the apps to install, typecheck, lint, and bundle without any
secrets. Swap it for a different host — a locally running `mock-api`, or
a real API — with `--api-url`.

One value the templates leave blank on purpose:
`EXPO_PUBLIC_GOOGLE_MAPS_API_KEY_ANDROID`. It's a real, non-public API key
(already excluded from git via `.gitignore`), only needed to render maps
at runtime — not for a JS build. Set it yourself in the app's `.env` if
you need maps to render.

## Verifying a build

`verify-build.sh` runs, per app:

- `npx tsc --noEmit` — typecheck
- the app's lint, in check-only form (no auto-fix/auto-format writes)
- with `--full`: `npx expo export --platform all` — an actual Metro bundle,
  the closest thing to "does this app build" short of a native EAS build

Exits non-zero and lists which app(s)/step(s) failed if anything breaks.

## Native (EAS) builds

This setup does not install Android SDK/Xcode — that's out of scope for a
lightweight Codespace/CI container. Once JS-level verification passes,
native builds still go through EAS as documented in the root `README.md`
("Building Development Versions") and each app's `package.json`
(`npm run build:staging`, `build:development`, `build:production`, etc.),
which run on Expo's own build infrastructure, not this container.

## Windows Local Native Builds: Ninja MAX_PATH (260-Character Limit)

### Problem
When building Android native modules on Windows (`assembleDebug` or `assembleRelease`), CMake/Ninja can fail with:
```text
ninja: error: Stat(...): Filename longer than 260 characters
```
This occurs because Android SDK CMake 3.22.1 ships an older version of Ninja (`1.10.2`) with a hardcoded 260-character `MAX_PATH` restriction on Windows. Even with Windows registry `LongPathsEnabled = 1`, older Ninja binaries reject paths longer than 260 characters.

### Permanent Solution (Applied Across All 3 Apps)
Update `ninja.exe` in the Android SDK directory to **Ninja ≥ 1.12** (e.g. **v1.13.2**), which natively supports Windows long paths without requiring temporary virtual drive mappings (`subst X:`):

```powershell
# 1. Download modern Ninja binary
Invoke-WebRequest -Uri "https://github.com/ninja-build/ninja/releases/latest/download/ninja-win.zip" -OutFile "$env:TEMP\ninja-win.zip"
Expand-Archive -Path "$env:TEMP\ninja-win.zip" -DestinationPath "$env:TEMP\ninja-latest" -Force

# 2. Replace the Android SDK bundled Ninja binary (backup original first)
$cmakeBin = "$env:LOCALAPPDATA\Android\Sdk\cmake\3.22.1\bin"
Copy-Item "$cmakeBin\ninja.exe" "$cmakeBin\ninja.exe.bak" -Force
Copy-Item "$env:TEMP\ninja-latest\ninja.exe" "$cmakeBin\ninja.exe" -Force

# 3. Verify version (should show 1.13.x)
& "$cmakeBin\ninja.exe" --version
```

With this fix, `multivendor-app`, `multivendor-store`, and `multivendor-rider` build cleanly from standard filesystem paths without needing drive mapping workarounds.

