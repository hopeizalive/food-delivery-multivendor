# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository overview

This is a monorepo of independent, separately-versioned frontend applications for the Enatega food/service delivery platform. Each top-level directory is its own npm project with its own `package.json`, `node_modules`, and deployment lifecycle — there is no root `package.json` or workspace tooling tying them together. The backend/API (`enatega-multivendor-api`) lives in a separate repository and is expected to be checked out as a sibling directory (`../enatega-multivendor-api`).

Apps:

- `enatega-multivendor-admin` — Next.js (App Router) admin dashboard for the multivendor platform.
- `enatega-multivendor-web` — Next.js (App Router) customer-facing ordering website.
- `enatega-multivendor-app` — Expo/React Native customer mobile app.
- `enatega-multivendor-rider` — Expo/React Native (expo-router) rider/delivery app.
- `enatega-multivendor-store` — Expo/React Native (expo-router) vendor/restaurant management app.
- `enatega-singlevendor-admin` — Next.js admin dashboard for single-vendor deployments.

A root-level `lib/` (`api/graphql`, `utils/methods`) exists but is not currently imported by any app — treat it as early-stage/unwired scaffolding, not a shared package.

## Commands

Each app is run from its own directory (`cd <app-dir>` first). Node 18–20 is required; the Next.js apps pin `engines.node >= 20` and expect `npm` (not yarn).

### enatega-multivendor-admin / enatega-multivendor-web / enatega-singlevendor-admin (Next.js)

```bash
npm install
cp .env.example .env.local   # if present; set required env vars before running
npm run dev                  # dev server on :3000 (webpack mode, node --inspect)
npm run build                # production build
npm start                    # serve production build
npm run lint                 # next lint / eslint
npm run prettier             # prettier --write .
npm run cy:open              # open Cypress interactively
npm run cy:run               # run Cypress headless
```

`enatega-multivendor-web` additionally has Vitest unit tests:

```bash
npm test                     # vitest run
npm run test:watch           # vitest watch mode
```

All three Next.js apps expose `npm run check:single-vendor-schema` (validates single-vendor GraphQL documents against a live schema — see "Vendor mode" below).

### enatega-multivendor-app (Expo customer app, classic `src/` layout)

```bash
npm install
npx expo start -c            # start Metro; press `s` to switch to Expo Go
npm run ios / npm run android
npm run lint:fix             # eslint --fix
npm run format                # prettier --write '**/*.js'
```

Verification scripts specific to this app (run before shipping single-vendor-affecting changes):

```bash
npm run check:single-vendor-imports   # forbids unresolved/cross-boundary imports from src/singlevendor
npm run check:single-vendor-schema    # validates src/singlevendor/apollo/* against the single-vendor GraphQL schema
npm run check:order-pricing           # asserts src/utils/orderPricing.js and populateCart.js behavior
npm run check:ios-privacy             # runs automatically on eas-build-post-install
npm run check:multivendor-design      # compares UI screenshots/metrics against scripts/multivendor-design-baseline.json
npm run check:signed-media-url
```

Build/submit via EAS: `npm run build:staging|development|production[:android|:ios]`, `npm run submit:production[:android|:ios]`.

### enatega-multivendor-rider / enatega-multivendor-store (Expo Router, `app/` + `lib/` layout)

```bash
npm install
npx expo start -c
npm run android / npm run ios / npm run web
npm run lint                  # eslint + prettier --check
npm test                      # jest --watchAll (jest-expo preset)
npm run check:single-vendor-schema
```

`enatega-multivendor-store` also has `npm run check:single-vendor-auth`.

To run a single Jest test in rider/store: `npx jest <path-or-name>` (drop `--watchAll`).

### Recommended local full-stack order

1. Start the API from `../enatega-multivendor-api`.
2. Start `enatega-multivendor-admin` or `enatega-multivendor-web`.
3. Start the mobile app you need (`enatega-multivendor-app`, `-store`, or `-rider`).

## Architecture

### Vendor mode: single-vendor code lives inside the multivendor codebase

The platform ships two backend flavors — **single-vendor** (one restaurant/store per deployment) and **multivendor** (marketplace of many vendors) — but the customer app, rider app, store app, and web app are each a *single* codebase that can run in either mode, or let the user toggle between them at runtime. This is the central architectural fact of the repo; most non-trivial work touches it.

- Deployment behavior is controlled by an env var (`EXPO_PUBLIC_VENDOR_MODE` for the Expo apps, `NEXT_PUBLIC_VENDOR_MODE` for the web app) set to `SINGLE`, `MULTI`, or `TOGGLE`. See [VENDOR_MODE_CONFIGURATION.md](VENDOR_MODE_CONFIGURATION.md) for the full deployment matrix and required companion env vars (e.g. `NEXT_PUBLIC_SINGLE_VENDOR_ENABLED` for web toggle builds).
- In `enatega-multivendor-app`, single-vendor–specific screens, components, GraphQL documents, and stores live under `src/singlevendor/`, isolated from the multivendor code in `src/screens`, `src/components`, etc. Mode state/policy logic lives in `src/mode/` (`AppModeContext.js`, `constants.js`) — `AppModeContext` exposes `mode`, `switchMode`, `isModeToggleEnabled`, and mode-sensitive-operation guards (`beginModeSensitiveOperation`) that block switching mid-checkout/order.
- The rider and store apps mirror this with a `lib/mode/` directory alongside their expo-router `app/` trees.
- The `check:single-vendor-*` npm scripts in each app enforce this boundary at CI/pre-build time:
  - `check-single-vendor-imports.js` (app only) parses every file under `src/singlevendor` and fails if it imports something unresolvable, catching accidental leakage/coupling to multivendor-only modules.
  - `check-single-vendor-schema.js` (all four affected apps) parses the single-vendor GraphQL operations out of the source and validates them against a live single-vendor schema (`SINGLE_VENDOR_SCHEMA_URL` env var, defaults to a Railway-hosted schema).
  - `check-order-pricing.js` (app only) unit-checks the shared cart/pricing math (`src/utils/orderPricing.js`, `src/utils/populateCart.js`) outside of a test runner, via a hand-rolled Babel-transform loader.
  - `check-single-vendor-store-auth.js` (store only) checks single-vendor auth wiring.
  - `check-multivendor-design.js` (app only) compares against a checked-in baseline (`scripts/multivendor-design-baseline.json`); update it deliberately via `npm run update:multivendor-design-baseline` when a design change is intentional.
- When changing anything under `*/singlevendor` or `*/mode`, run the app's `check:single-vendor-*` scripts before considering the change done — they are the project's substitute for type-level enforcement of the mode boundary.

### App structure conventions

- **Next.js apps** (`admin`, `web`, `singlevendor-admin`): App Router under `app/`, with route groups like `(localized)` and `(protected)`/`(unprotected)` encoding locale and auth requirements in the directory structure. Shared code (API clients, hooks, context, UI primitives, config) lives in `lib/` at the app root (`lib/api`, `lib/context`, `lib/hooks`, `lib/services`, `lib/states`, `lib/ui`, `lib/utils`). i18n strings live under `locales/` with routing config in `i18n/`.
- **Expo Router apps** (`rider`, `store`): file-based routing under `app/`, business logic/shared code under `lib/` (`lib/apollo`, `lib/context`, `lib/hooks`, `lib/mode`, `lib/services`, `lib/ui`, `lib/utils`). Route groups like `(tabs)` and `(protected)`/`(un-protected)` mirror the Next.js convention.
- **Classic Expo app** (`enatega-multivendor-app`): pre-expo-router layout — `src/screens`, `src/routes` (React Navigation), `src/components`, `src/context`, `src/apollo`, `src/api`, `src/services`, `src/ui`, `src/utils`, plus the isolated `src/singlevendor` tree described above.
- All frontends talk to the API over Apollo GraphQL (queries/mutations/subscriptions), with `subscriptions-transport-ws` or `graphql-ws` for realtime (order tracking, chat, rider location).

### Cross-cutting notes

- Node version matters: Next.js apps require Node ≥20/npm ≥10 (`engines` in `package.json`); mismatches are a common source of install/build failures. Mobile apps typically expect Node 18–20 via `nvm use` (see the README's Quick Run Matrix).
- Firebase is used for auth/push across the Next.js and Expo apps; credentials are supplied via app-specific env/config files, not committed (see README's Prerequisites section for the full credential list: Facebook app IDs, Google client IDs, Amplitude key, Firebase config, Mongo/email creds for the API).
- Error monitoring: Sentry (mobile apps upload sourcemaps via `upload-sourcemaps` in rider). Analytics: Amplitude / Expo Amplitude.
- EAS (`eas.json`) drives mobile build profiles (`development`, `staging`, `production`) for app, rider, and store; `EXPO_PUBLIC_VENDOR_MODE` is set per-profile in `eas.json` for client-specific single/multi/toggle builds, per [VENDOR_MODE_CONFIGURATION.md](VENDOR_MODE_CONFIGURATION.md).
