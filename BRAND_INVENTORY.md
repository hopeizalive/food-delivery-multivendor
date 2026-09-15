# Brand Inventory & Rebrand Plan

Scope: case-insensitive `enatega` search across the whole repo, excluding
`node_modules`, `.git`, and build output (ripgrep respected `.gitignore`,
which already excludes these). **Total: 3,584 occurrences across 278 files**,
as of the directory rename in commit `4a4cda29` (`multivendor-*` /
`singlevendor-admin` folder names — internal identifiers below were
deliberately left untouched in that pass).

This document exists so the brand-removal work doesn't need to be
re-researched from scratch — it's a snapshot inventory plus the recommended
order of operations for a full rebrand. Counts will drift as the codebase
changes; re-run the searches below before acting on stale numbers.

## 1. Brand-name text references, by category

### A. App display names / titles / manifest metadata
~15 files, ~25 occurrences. Highest-priority — literally what users see as
the app name.

| File:line | Value |
|---|---|
| `multivendor-app/app.config.js:29` | `name: 'Enatega Multi'` |
| `multivendor-app/app.config.js:32` | `slug: 'enategamultivendor'` |
| `multivendor-rider/app.config.js:12` | `name: 'Enatega Multivendor Rider'` |
| `multivendor-store/app.json:3-4` | `"name": "Enatega Store"`, `"slug": "enatega-multivendor-restaurant"` |
| `multivendor-web/public/manifest.json:2-4` | `"name": "Enatega MultiVendor"`, `"short_name": "Enatega"` |
| `multivendor-admin/app/layout.tsx:8` | `title: 'Enatega Admin Dashboard'` |
| `multivendor-web/app/layout.tsx:19` | `title: "Enatega Multivendor"` |
| `singlevendor-admin/lib/utils/assets/svgs/logo.tsx:6` | text wordmark `Enatega` (see §2) |

`package.json` `"name"` fields also carry the brand (internal npm package
names, not user-visible) and were explicitly *not* touched in the directory
rename:

| App | package.json "name" |
|---|---|
| multivendor-admin | `enatega-frontend` |
| multivendor-app | `enatega-full-app` |
| multivendor-rider | `mobile-architecture` (already generic) |
| multivendor-store | `enatega-store-app` |
| multivendor-web | `enatega-frontend` |
| singlevendor-admin | `enatega-frontend` |

### B. UI-visible strings (locale/i18n + hardcoded component strings)
Largest category by volume — locale files repeated across every supported
language in every app.

| App | Locale dir | # lang files | Enatega mentions per file (range) |
|---|---|---|---|
| multivendor-web | `locales/*.json` | 33 | 5–92 (`en.json`: 91) |
| multivendor-admin | `locales/*.json` | 32 | 5 each |
| singlevendor-admin | `locales/*.json` | 31 | 5 each |
| multivendor-app | `translations/*.js` | 33 | 1–8 |
| multivendor-rider | `languages/*.js` | 32 | varies (`en.js`: 4) |
| multivendor-store | `languages/*.js` | 9 | 0 (brand strings live in `lib/` components instead) |

Representative examples, `multivendor-web/locales/en.json`:
- line 31: `"eyebrow": "How Enatega moves"`
- line 89: `"SearchBarPlaceholder": "Search in enatega"`
- line 118: `"tagLine": "LIFE TASTES BETTER WITH ENATEGA"`
- lines 151-152: `"enategaRider": "Enatega Rider"`, `"enategaRestaurant": "Enatega Restaurant"`
- line 275: `"app_main_heading": "Welcome to Enatega"`

**Not just values** — some i18n *keys* bake in the brand too, e.g.
`enatega_rider_page_name_card1_heading`, referenced at
`multivendor-web/lib/ui/screens/unprotected/Rider/index.tsx:23`. Renaming
those requires updating both the key and every call site.

Hardcoded (non-i18n) component strings:
- `singlevendor-admin/lib/utils/assets/svgs/logo.tsx:6` — literal JSX text `Enatega`
- `multivendor-store/lib/ui/useable-components/splash/AnimatedSplash.tsx`
- `multivendor-store/lib/ui/screen-components/home/drawer/drawer-content/index.tsx` (×3)
- `multivendor-rider/lib/ui/screen-components/home/drawer/drawer-content/index.tsx` (×3)
- `multivendor-rider/lib/ui/screens/login/index.tsx` (×2)
- `multivendor-app/src/screens/Account/Account.js` (×3), `multivendor-app/src/components/LanguageModalize/LanguageModal.js` (×3)
- `multivendor-app/src/singlevendor/screens/{ReferAFriend,SecuritySettings,LanguageSelection}.js`, `Checkout/OrderConfirmation.js`
- `multivendor-rider/GOOGLE_PLAY_BACKGROUND_LOCATION_SUBMISSION.md` (×7) — Play Store listing copy
- `multivendor-rider/lib/services/background-location.ts:151` — `notificationTitle: "Enatega delivery tracking"` (a live system notification, directly user-visible)

### C. Bundle/package identifiers — highest risk category
| Identifier | Location(s) |
|---|---|
| `com.enatega.multivendor` | `multivendor-app/app.config.js` (iOS bundleIdentifier, Android package, app group `group.com.enatega.multivendor.shared`), `multivendor-store/google-services.json`, `multivendor-rider/google-services.json` |
| `com.enatega.multirider` | `multivendor-rider/app.config.js:21,86,108` (scheme + bundleIdentifier + Android package) |
| `multivendor.enatega.restaurant` | `multivendor-store/app.json:52,77` (iOS bundleIdentifier + Android package), referenced in `multivendor-rider/google-services.json`, web app-store links |
| `enategamultivendor` (URL scheme) | `multivendor-app/app.config.js:9,32`, `CFBundleURLSchemes` |
| EAS slug `enategamultivendor` / owner `hopeizalive` | `multivendor-app/app.config.js:32-33` |
| EAS slug `enatega-multivendor-restaurant` | `multivendor-store/app.json:4` |
| Sentry-style project tag `enatega-rider-app` | `multivendor-rider/app.config.js:69` |
| Firebase project `enatega-b7cd2` | `multivendor-app/google-services.json`, `multivendor-rider/google-services.json`, `multivendor-store/google-services.json`, `multivendor-app/GoogleService-Info.plist` |
| Firebase web project `enatega-multivender-web` | `multivendor-admin/public/firebase-messaging-sw.js:11-13`, `singlevendor-admin/public/firebase-messaging-sw.js` |

**These cannot be renamed in place if the apps are already live** — an iOS
bundle ID or Android package name change requires a new store listing, not
an edit. Treat this row as a business decision, not a text-replace task.

### D. External URLs baked into code
| Domain/URL | Where used |
|---|---|
| `aws-server-v2.enatega.com` (+ commented `backup-server.enatega.com`) | `multivendor-admin/lib/utils/constants/url.ts`, `multivendor-app/environment.config.js`, `multivendor-rider/environment.ts`, `multivendor-store/environment.ts` — **live production API domain** |
| `assets.enatega.com` | `next.config.mjs` `images.remotePatterns` in admin/web/singlevendor-admin, `singlevendor-admin/middleware.ts:11` CSP `img-src` |
| `enatega-backend.s3.eu-north-1.amazonaws.com` | same 3 `next.config.mjs` files |
| `enatega.com` | `multivendor-web/next.config.mjs:117` |
| `enatega-multivendor-api-production-9b09.up.railway.app` | `singlevendor-admin/netlify.toml`, `singlevendor-admin/lib/utils/constants/url.ts`, all mobile apps' `eas.json` production env blocks |
| `enatega-demo-mock-api.onrender.com` | staging env blocks in `multivendor-app/eas.json`, `multivendor-rider/eas.json`, `multivendor-store/eas.json` |
| App Store: `apps.apple.com/pk/app/enatega-multivendor/id1526488093` | `multivendor-app/src/components/Update/ForceUpdate.js:80`, `multivendor-web/lib/ui/useable-components/Footer/AppLinks.tsx:10` |
| Play Store: `id=com.enatega.multivendor` / `id=multivendor.enatega.restaurant` / `id=com.enatega.multirider` | `ForceUpdate.js:81`, `AppLinks.tsx:8`, `multivendor-web/lib/ui/screen-components/un-protected/Home/LifeWithEnatega/index.tsx:48-50`, `.../layout/app-footer/index.tsx:34,39` |
| GitHub org `github.com/enatega/*` | root `index.html`, `README.md` badges point at `Ninjas-Code-official/Enatega-Multivendor-Food-Delivery-Solution` |

Root **`index.html`** carries 283 of the 3,584 total matches by itself — it's
a saved snapshot of `github.com/enatega/food-delivery-multivendor`'s GitHub
page (nav chrome, embedded JSON, avatar URLs). Not runtime app code;
candidate for deletion rather than rebranding.

### E. Code comments / internal doc references (non-user-facing)
- `multivendor-app/app.config.js:41` — comment about Enatega's analytics/diagnostics
- `multivendor-app/patches/activity-controller+1.0.0.patch:21-24` and `package-lock.json:33` — patches/pulls a dependency from `git+https://github.com/enatega/activity-controller.git`
- `multivendor-app/src/utils/themeColors.js:1` — `export const ENATEGA_BRAND_COLORS`, consumed in `BottomTabIcon/icons.js` (×15) and `liveActivityService.js` (×6) — internal constant name threaded through many files
- `multivendor-app/targets/widget/WidgetLiveActivity.swift` (23 matches) — internal Swift identifiers (`enategaGreen`, `enategaAccent`, `enategaNavy`, struct `EnategaLogo`, image name `"EnategaLogo"`) plus a **user-visible** `.accessibilityLabel("Enatega")` at line 108
- `CLAUDE.md:7` — one mention (agent-facing doc, not shipped)
- Scattered single mentions: `multivendor-admin/README.md`, `multivendor-web/README.md`, `multivendor-rider/README.md`, `multivendor-store/README.md`, `multivendor-app/README.md`, `multivendor-app/QUAL-012_BACKEND_INSTRUCTIONS.md`, `multivendor-rider/AUDIT-REMEDIATION-FIXED.md`
- Brand in filenames: `multivendor-admin/ENATEGA_ADMIN_SECURITY_PERFORMANCE_CLEANUP_AUDIT.pdf`, `multivendor-store/ENATEGA_STORE_APP_SECURITY_PERFORMANCE_CLEANUP_AUDIT.pdf`
- `demo-recorder/` — Maestro/adb flow scripts and `HANDOFF.md`/`inspect.xml` (test tooling, not shipped)

### F. Config/metadata files
| File | Enatega content |
|---|---|
| `multivendor-app/eas.json`, `multivendor-rider/eas.json`, `multivendor-store/eas.json` | staging/production `GRAPHQL_URL`/`WS_GRAPHQL_URL` point at Render/Railway enatega domains |
| `multivendor-app/app.config.js`, `multivendor-rider/app.config.js`, `multivendor-store/app.json` | name, slug, scheme, bundle IDs, `extra.liveActivity.brandName: 'Enatega'`, `logoResourceName: 'enatega_logo'`, `riderResourceName: 'enatega_rider'` |
| `google-services.json` (app, rider, store) | Firebase `project_id: "enatega-b7cd2"`, storage bucket, package name entries |
| `multivendor-app/GoogleService-Info.plist` | `BUNDLE_ID: com.enatega.multivendor`, `PROJECT_ID`/`STORAGE_BUCKET: enatega-b7cd2*` |
| `multivendor-admin/public/firebase-messaging-sw.js`, `singlevendor-admin/public/firebase-messaging-sw.js` | Firebase web config (`authDomain`/`projectId`/`storageBucket`: `enatega-multivender-web*`) |
| `singlevendor-admin/netlify.toml` | API URLs → enatega Railway backend |
| `multivendor-web/public/manifest.json` | PWA `name`/`short_name` |

## 2. Logo / image / icon asset inventory

### multivendor-app — `assets/` (12 files)
```
appIcon.png, icon.png, not-icon.png, splash.png, splash-old.png, splashTransparent.png,
_splash.png, login-icon.png, mobile-login.svg, customMarker-1.png, customMarker-2.png,
Group1000003768.png
```
Referenced from `app.config.js`: `icon` (top-level + iOS), `android.icon`,
`android.adaptiveIcon.foregroundImage`, `notification.icon`. The
`expo-splash-screen` plugin points at `splashTransparent.png` (a 1×1
transparent PNG) — the visible splash art is actually drawn at runtime.

**Real splash artwork lives outside `assets/`**, in `targets/widget/` and
`splash_claud_assets/enatega-animated-splash/assets/`:
- `wordmarkNavy.png`, `wordmarkWhite.png` — the Enatega wordmark, drawn by the JS `AnimatedSplash` component
- `glow.png`, `pin.png` — supporting graphics
- Duplicated verbatim under `multivendor-rider/splash_claud_assets/enatega-animated-splash/`

**iOS widget/Live Activity assets** (`targets/widget/Assets.xcassets/`):
- `EnategaLogo.imageset/` — `enatega-logo.png` (+@2x/@3x)
- `EnategaRider.imageset/` — `enatega-rider.png` (+@2x/@3x)
- Loose copies directly in `targets/widget/`: `enatega-logo.png`, `enatega-rider.png`
- Consumed by `WidgetLiveActivity.swift` (`Image("EnategaLogo")`, `.accessibilityLabel("Enatega")`) — imageset names and the Swift reference both need updating together

### multivendor-rider — `lib/assets/` (23 files)
No top-level `assets/`; Expo paths point into `lib/assets/images/`.
`icon.png`, `splashTransparent.png` (same transparent-splash pattern),
`appIcon.png` for `android.icon`. Non-brand: flag PNGs, `welldone.png`,
`graphic.png`, `placeholder.jpg`. Also carries its own copy of the wordmark
PNGs under `splash_claud_assets/enatega-animated-splash/`.

### multivendor-store — `lib/assets/` (20 files)
`icon.png`, `splashTransparent.png`, `appIcon.png` for
`android.icon`/`adaptiveIcon`. Other assets: `RiderLogin.png`,
`mobile-splash.mp4` (video splash), flag icons. No file literally named
"enatega" — brand exposure here is mostly the wordmark drawn by
`AnimatedSplash.tsx`, not a static image.

### multivendor-admin — `public/`
- `public/assets/images/png/logo.png`, `public/assets/images/svgs/logo.svg` (+ stray `logo copy.svg`) — vector wordmark
- `public/favicon.png`, `public/favsicons.png` (referenced from `app/layout.tsx` `icons.icon`)
- Verify whether the sidebar/app-bar logo is this image or a text component (singlevendor-admin uses text — see below; admin's layout is structurally similar)

### multivendor-web — `public/` (~55 image files)
- `public/assets/images/svgs/logo.svg` / `logo.png` — vector wordmark (SVG path data spells "Enatega" as a real logotype — needs redesign, not a string swap)
- `public/144.png`, `public/192.png`, `public/512.png` — PWA icons (`manifest.json` "icons")
- `public/favicon.ico`, `public/favicon.png`, `public/favsicon.png`
- `public/splash-screen.png` — web splash
- `public/assets/images/png/enategaApp.png` — used in `RestaurantInfo/index.tsx`
- `lib/assets/enatega-logo.png` — imported directly in `gm-tracking-comp.tsx`
- Landing hero art under `public/assets/images/landing/quiet-orbit/` — generic filenames but part of the current visual identity

### singlevendor-admin — `public/`
- Same logo pair as multivendor-admin: `logo.png`, `logo.svg` (+ `logo copy.svg`)
- `favicon.png`, `favsicons.png`, `_favsicons.png` (odd underscore-prefixed duplicate)
- **The actual on-screen logo is plain text, not the image files above**:
  [singlevendor-admin/lib/utils/assets/svgs/logo.tsx](singlevendor-admin/lib/utils/assets/svgs/logo.tsx)
  renders `<span>Enatega</span><span>Admin</span>` as JSX — despite living in
  a file named "logo.tsx" inside an `svgs/` directory, there's no actual
  vector graphic rendered. Rebrand here is a one-line string edit.

### Repo-root `assets/` folder (~65 files)
Marketing/README screenshots and diagrams (`Admin.webp`, `Customer-app.webp`,
`RiderApp.webp`, `dasboard-scaled.png`, tech-stack logos), not app runtime
assets. Two brand-named files: `LOGOS-FOR-ENATGEA-res.png`,
`LOGOS-FOR-ENATGEA-res1.png` (note the typo "ENATGEA" in the filename
itself). Matters only because root `README.md`'s screenshots show the old
brand/UI.

### Summary — what needs actual visual asset replacement
| App | Icon/splash art | Logo graphic | Logo is just text (cheap) |
|---|---|---|---|
| multivendor-app | Yes — icon/appIcon/notification PNGs, wordmark PNGs, widget imagesets | Yes (wordmark + widget images) | — |
| multivendor-rider | Yes — icon/appIcon, duplicated wordmark PNGs | Yes (shared wordmark) | — |
| multivendor-store | Yes — icon/appIcon, splash video/transparent PNG | Partial — mostly text-driven, verify no baked wordmark image | — |
| multivendor-admin | Yes — favicon/favsicons | Yes — `logo.png`/`logo.svg` | Possibly (verify) |
| multivendor-web | Yes — favicon, PWA icons, splash-screen.png | Yes — `logo.svg`/`logo.png`, `enatega-logo.png`, `enategaApp.png` | — |
| singlevendor-admin | Yes — favicon/favsicons | Vector logo exists but is unused on screen | **Yes** — `AppLogo()` text component |

## 3. Existing rebrand/whitelabel tooling — none usable

Searched `rebrand`, `whitelabel`/`white-label`, `tenant` across
`*.md/*.yml/*.yaml/*.js/*.ts/*.json`.

- No dedicated rebrand doc or script exists anywhere in the repo.
- `.github/workflows/build-tenant-apk.yml` ("Build White-Label Tenant APK")
  looks like partial rebrand infrastructure but is for a different purpose —
  a `workflow_dispatch` job that takes `tenant_slug`/`tenant_name`/
  `tenant_app_name`/`tenant_icon_url` inputs, pushes them as EAS secrets, and
  kicks off an EAS Android build on a `tenant` profile, then POSTs the APK
  URL to a callback. Built for on-demand SaaS-style white-labeling of
  `multivendor-app` per customer, not for rebranding the whole repo.
- **This workflow is stale/non-functional today**: it checks out `ref:
  saas-demo`, which doesn't exist locally or on the remote (only `main` and
  two `demo/*` branches exist); it references a `prepare-tenant-icon.js`
  script that isn't in the repo; `multivendor-app/eas.json` has no `tenant`
  build profile (only `development`/`staging`/`production`). Introduced in
  commit `37f71271` ("ci: add tenant APK build workflow"), before the
  directory-rename commit `4a4cda29`.
- The only other "tenant" hits in the repo are false positives — the
  substring inside the French word "maintenant" in six locale files.
- No `whitelabel.config.*`, no theming/branding config layer, no build-time
  brand-token substitution. Every brand string is a hardcoded literal.

## 4. Rebrand strategy — recommended order

**Step 1 — Decide the hard stuff first (business/infra, not code):**
- New brand name + new bundle identifiers. `com.enatega.multivendor`,
  `com.enatega.multirider`, `multivendor.enatega.restaurant` **cannot be
  renamed in place** if these apps are already live on the App/Play Store —
  that requires new store listings. This is a business decision, not a text
  edit.
- Whether to keep or migrate the Firebase project (`enatega-b7cd2`) and the
  live API domains (`aws-server-v2.enatega.com`, the Railway production API,
  the Render staging mock API). All six apps point at the same shared infra,
  so this is one decision, not six.

**Step 2 — Low-risk text pass (mechanical, safe to do first):**
- Locale/i18n files (largest volume, ~170 files across 6 apps) — mostly
  find/replace, but watch for i18n **keys** that bake in the brand (e.g.
  `enatega_rider_page_name_card1_heading`) — renaming those means updating
  both the key and every call site.
- Titles, `manifest.json`, `layout.tsx` metadata.
- The one-line text fix in singlevendor-admin's `AppLogo()` component.

**Step 3 — Design pass (needs an actual designer/asset pipeline):**
- New wordmark (SVG/PNG) at every required size: app icons, adaptive icons,
  splash art, favicons, PWA icon set, iOS widget imagesets. This step
  produces the binary assets Step 4 wires in.

**Step 4 — Wire in new assets + identifiers (increasing blast radius):**
- Swap icon/splash/logo file references in `app.config.js`/`app.json` once
  new art exists from Step 3.
- Bundle IDs, EAS slugs/owner, `google-services.json`/
  `GoogleService-Info.plist`, Sentry project tags — only after the
  store-listing decision in Step 1, since it's irreversible for published
  apps.
- Update API/CDN domains once infra is decided.

**Step 5 — Housekeeping (any time, no dependencies):**
- Delete root `index.html` (stray saved GitHub page, not app code).
- Rename `ENATEGA_*_AUDIT.pdf` files and the typo'd
  `LOGOS-FOR-ENATGEA-res*.png` in root `assets/`.

## Per-app change checklist

- **multivendor-app**: `app.config.js` name/slug/scheme/bundleIdentifier/
  Android package/app-group entitlement/EAS owner; icon/splash/notification
  PNGs; wordmark PNGs in `splash_claud_assets/`; iOS widget
  `Assets.xcassets` imagesets (+ rename imagesets + the Swift
  `Image("EnategaLogo")` reference); `google-services.json`/
  `GoogleService-Info.plist`; `ENATEGA_BRAND_COLORS` constant name
  (cosmetic); all `translations/*.js` strings; App/Play Store URLs in
  `ForceUpdate.js`; API domain in `environment.config.js`.
- **multivendor-rider**: `app.config.js` name/scheme/bundleIdentifier/
  Android package; icon/splash assets (shared wordmark PNGs);
  `google-services.json`; `languages/*.js` strings; drawer/login screen
  text; `environment.ts` API domain; Sentry project tag
  `enatega-rider-app`.
- **multivendor-store**: `app.json` name/slug/scheme/bundleIdentifier/
  Android package; icon/splash assets; `google-services.json`; drawer text;
  `environment.ts` API domain; `store-mode.ts`.
- **multivendor-admin**: `next.config.mjs` image remote host allowlist
  (`assets.enatega.com`, S3 bucket); `app/layout.tsx` title/favicon;
  `logo.png`/`logo.svg` (verify whether a text logo component exists too,
  as in singlevendor-admin); `firebase-messaging-sw.js` Firebase config;
  `constants/url.ts` API domain; locale JSON strings (32 files × 5 lines
  each).
- **multivendor-web**: heaviest text footprint — 33 locale files (up to 91
  mentions each), plus hardcoded marketing copy in landing/footer/rider/
  restaurant-info screens; PWA `manifest.json` name/short_name/icons;
  favicon set; `splash-screen.png`; `logo.svg`/`logo.png`;
  `enatega-logo.png`/`enategaApp.png` image imports; hardcoded App/Play
  Store URLs (3 places); `next.config.mjs` image domains; `<title>` and
  design-brief comment in `app/layout.tsx`.
- **singlevendor-admin**: `netlify.toml` env vars; `next.config.mjs` image
  domains; `middleware.ts` CSP allowlist; `AppLogo()` text component
  (cheapest fix — one string); favicon set; `firebase-messaging-sw.js`
  config; 31 locale files; sign-up screen text.
- **Cross-cutting / infra**: the live backend domains and the shared
  Firebase project are referenced by every app — this is a backend/infra
  decision that should happen before or alongside the frontend text/asset
  changes, since all six apps point at the same values.
- **Housekeeping, not rebrand-critical**: root `index.html`; two
  `ENATEGA_*_AUDIT.pdf` filenames; `LOGOS-FOR-ENATGEA-res*.png`; README/
  CLAUDE.md prose mentions.
