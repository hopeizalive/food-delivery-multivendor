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
  setup-android.sh                  # one-time: JDK 21 + Android SDK, for local APK builds
  verify-android.sh                 # check the Android toolchain actually installed correctly
  setup-swap.sh                     # best-effort swapfile, guards against OOM during build-apk.sh
  build-apk.sh                      # build one app's debug .apk with Gradle (no EAS)
  check-apks.sh                     # check whether all 3 debug APKs are built yet
  serve-apks.sh                     # serve dist/apks with a per-APK QR code for the team
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

## Native builds

### Option A: EAS (cloud, uses Expo build credits)

Documented in the root `README.md` ("Building Development Versions") and
each app's `package.json` (`npm run build:staging`, `build:development`,
`build:production`, etc.) — runs on Expo's own build infrastructure, not
this container. Covers both Android and iOS.

### Option B: local Android APK build in this container (no EAS credits)

Android only — iOS needs Xcode, which doesn't run on Linux, so this path
has no iOS equivalent; use EAS for iOS. This is a genuinely heavier lift
than the JS-only setup above (Gradle/Android builds are resource- and
time-intensive — expect ~15–25 min for a first build, several GB of SDK/
Gradle-cache disk use, and it counts against your Codespaces core-hour
quota, not Expo's). It's opt-in and never runs automatically — nothing in
`postCreateCommand` touches it.

```bash
# once per container
bash scripts/build-setup/setup-android.sh

# confirm it actually installed correctly before trying a build
bash scripts/build-setup/verify-android.sh

# once per app, repeat for each (they don't run in parallel on a small
# machine — build one, then the next)
bash scripts/build-setup/build-apk.sh multivendor-rider
bash scripts/build-setup/build-apk.sh multivendor-store
bash scripts/build-setup/build-apk.sh multivendor-app

# confirm all three actually landed in dist/apks/ before serving
bash scripts/build-setup/check-apks.sh

# serve dist/apks/*.apk with a QR code per APK for the team to scan
bash scripts/build-setup/serve-apks.sh
```

`setup-android.sh` installs JDK 21 (matching the team's existing local
build setup — not 17, which is Expo/RN's usual minimum but not what this
repo is actually built with) plus the Android SDK platform/build-tools
versions `multivendor-app`/`-rider`/`-store` need, via plain `sdkmanager`
calls — not a devcontainer Feature, since that's exactly what broke
container creation before Features were dropped from
`.devcontainer/devcontainer.json` (see git history). It's idempotent, safe
to re-run. Its downloads and `sdkmanager` output print live (progress
bars, license prompts) rather than being redirected to `/dev/null` — a
quiet multi-minute gap here looks identical to a hang, so don't Ctrl+C
early just because nothing new printed for a bit.

`verify-android.sh` checks the actual files on disk — `java`, `sdkmanager`,
`adb`, both platforms, both build-tools versions, accepted licenses — and
reports pass/fail per item instead of trusting that the installer "said"
it finished. Run it any time something in the Android build chain seems
off, not just right after `setup-android.sh`.

`build-apk.sh <app>` runs `expo prebuild --platform android --clean` then
`./gradlew assembleDebug`, and copies the result to
`dist/apks/<app>-debug.apk` (git-ignored — see `/dist` in `.gitignore`).
It's a debug-signed APK: installs fine for internal team testing via
"unknown sources", not Play-Store-eligible. Same dev-client behavior as an
EAS `development`-profile build, since `expo-dev-client` is already a
dependency of all three apps.

It also caps Gradle's memory usage (`GRADLE_OPTS`, `--no-daemon`,
`--max-workers=2`, plus a `kotlin.daemon.jvm.options` cap in
`~/.gradle/gradle.properties`) and runs `setup-swap.sh` first. Without
this, the default free Codespaces machine (`basicLinux32gb`: 2 cores / 8GB
RAM) can get **OOM-killed mid-build** — either the whole container
(platform-level kill, looks like "the codespace just stopped" with no
build error at all) or just the Gradle daemon (Gradle's own low-memory
self-check killing itself, surfaced as "Gradle build daemon disappeared
unexpectedly" in the build output). If that ever happens again:
`gh codespace list` / `gh codespace view -c <name>` shows the machine size
and last-used/updated timestamps — a stop within a couple minutes of heavy
build activity (not ~30 min later, which would be the idle timeout
instead) points at OOM. If it recurs even with the caps in place, the
remaining lever is closing other memory users first — any other terminal
still running `expo start`/Metro (`start-app.sh`) is competing for the
same 8GB.

`setup-swap.sh [size-in-GB, default 4]` adds a swapfile so a memory spike
degrades (slower) instead of something getting killed — best-effort, and
harmless to the build if the container doesn't allow `swapon` (some don't;
it just warns and continues without it). Runs automatically at the start
of `build-apk.sh`; safe to re-run on its own too, since it no-ops if swap
is already active.

`check-apks.sh` just checks `dist/apks/` for all three
`<app>-debug.apk` files and reports size + build time for whichever exist,
or the exact `build-apk.sh <app>` command for whichever don't — quick
sanity check before serving.

`serve-apks.sh [port]` (default port `9000`, already forwarded + set
Public in `devcontainer.json`) generates a QR code per `.apk` in
`dist/apks/` pointing at that file's Codespaces-forwarded download URL,
and serves an index page showing all of them — open the forwarded `9000`
URL in a browser, scan with a phone camera, done. Uses the same
`codespaces_forwarded_url()` helper (`lib.sh`) as `start-app.sh`.

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

