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
