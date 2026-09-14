# Order-Lifecycle Demo — Session Progress

Branch: `demo/order-lifecycle-mock-api`. Nothing in this session has been
committed to git — this document, and everything it describes, is currently
uncommitted working-tree state.

## Why this exists

The goal is to demo a full order lifecycle (customer orders → store accepts →
rider delivers) to a potential client, using the real
`enatega-multivendor-app` / `-store` / `-rider` apps. The real backend
(`enatega-multivendor-api`) is a separate, unavailable/proprietary repo, and
there are no demo credentials for Enatega's hosted servers (and no
self-registration for store/rider accounts). So we built a self-hosted mock
GraphQL backend (`mock-api/`) that speaks the exact contract the real apps
already send, seeded with fixed demo accounts/data — no app-side code changes
needed beyond pointing env vars at it, plus a handful of real pre-existing app
bugs we found and fixed along the way.

## Backend path forward — the decision this demo is really for (top priority)

The mock API in this repo is a **demo-only stand-in**, not a proposal for the
production backend. Its job is just to prove the order lifecycle works so we
can show it live. The real open question, which this session's work directly
feeds into, is what backend we actually run on after the demo:

1. **Check whether the template purchase includes API/backend support.**
   Enatega gives the app template for free but the backend
   (`enatega-multivendor-api`) is separate/paid — we need to confirm with
   them exactly what "purchasing" unlocks (hosted API access? source code
   license? support?) before assuming either path below.
2. **If we purchase it:** we get Enatega's real, production-grade backend
   and API, and none of the mock-api work in this repo is needed going
   forward except as a reference.
3. **If we don't purchase it:** we're not stuck. This session reverse-engineered
   and documented the *exact* GraphQL contract every screen in all three apps
   actually sends (`mock-api/CONTRACT.md`) — every query, mutation, and
   subscription, field-for-field. That means we already have the hardest
   part of building our own backend done: the spec to build against. The
   `mock-api/` in this repo is a rough, in-memory proof that the contract is
   right, not the finished thing — building our own real backend (a proper
   database, real auth, etc.) from this same contract is a well-scoped,
   known amount of work, and it costs us nothing beyond our own dev time.

Decision on option 2 vs. 3 is a business call (cost of the Enatega license
vs. cost of building our own backend from the now-documented contract) — not
something resolved in this session, but this session's output (the working
demo + the full contract doc) is what makes that decision possible either way.

## What's working right now

### 1. Mock GraphQL API (`mock-api/`)
- Express + Apollo Server v3, GraphQL over HTTP + WebSocket (legacy
  `subscriptions-transport-ws` protocol, matching all three apps' Apollo
  clients) on port 4000.
- In-memory data, no database. `resetDemo` mutation clears all orders/carts
  between rehearsals.
- Full contract documented in `mock-api/CONTRACT.md`.
- Start/stop: `mock-api/demo.sh start|stop|status` (starts mock API + store
  web + rider web together). Customer app is separate (native build, see
  below).
- Seeded accounts:
  - Customer: `demo@enatega.com` / `demo1234`
  - Store: `store-demo` / `demo1234`
  - Rider: `rider-demo` / `demo1234`

### 2. Single-vendor mode — verified end-to-end
Login → browse → cart → checkout → place order → store sees it live → store
accepts → rider sees it live → rider claims/progresses → delivered → customer
tracking updates live. Verified via `mock-api/test-lifecycle.sh` (scripted,
curl-based) and manually on the customer app running natively on the
`EnategaDemo_API34` emulator.

### 3. Multivendor mode — verified end-to-end (this session's main addition)
Real multivendor Discovery screen (not single-vendor) now works against the
mock API:
- Location resolves to **Karachi, Sindh, Pakistan** (demo is intentionally
  scoped to one city/zone).
- "Explore Cities" picker works (zone → city centroid).
- Restaurant list renders 3 seeded restaurants: **Demo Bistro**, **Sushi
  Point**, **Pizza Palace** — each with its own menu/categories/foods.
- Restaurant detail screen renders fully: image, cuisine tag, rating/review
  count, delivery time, open/closed status, category tabs, food items with
  images/descriptions/add buttons.
- Multivendor `placeOrder` (different mutation shape than single-vendor —
  takes `restaurant` + `orderInput` args, client computes pricing) works and
  was tested directly against the API (order priced/created correctly).
- **Only Demo Bistro is wired to the store/rider apps** — orders against
  Sushi Point/Pizza Palace are browsable and orderable but won't show up
  anywhere else (deliberate scope decision, not a bug: full accept/deliver
  walkthrough is only ever demoed against Demo Bistro).
- App runs in `TOGGLE` vendor mode, so the same build can switch between
  Single Vendor and Multi Vendor live via the Profile tab — no rebuild
  needed to show both.

### 4. Customer app — native Android build
- Builds and installs successfully on the `EnategaDemo_API34` emulator via
  `gradlew app:assembleDebug`, connects to Metro for the JS bundle (this is
  normal for a debug/dev-client build, not a workaround — any React Native
  debug build needs a running Metro bundler).
- Two real Windows-environment build blockers were found and fixed:
  - Windows `MAX_PATH` (260 char) limit broke a native C++ codegen build
    (`react-native-keyboard-controller`). Windows' registry "long paths"
    setting did **not** fix it (the native `ninja.exe` toolchain isn't
    long-path aware). Fixed by mapping a short drive letter to the project
    (`subst X: D:\dev\food-delivery-multivendor\enatega-multivendor-app`)
    and building from `X:\android` instead. **This subst mapping is
    session-only — it will need to be re-created (same command) after a
    reboot before rebuilding natively again.**
  - Broken/incomplete Android NDK install — reinstalled via `sdkmanager`.

### 5. Full order lifecycle — customer side confirmed end-to-end (native Android, multivendor)
Login → browse → cart → checkout → place order → live order tracking all
verified working on the real native build against the mock API:
- Login (`demo@enatega.com` / `demo1234`) works and survives an app restart
  (session token is JWT-shaped now, matching what the client decodes).
- Demo Bistro menu → add to cart → checkout → tipping → address (pre-seeded
  Karachi "Home" address) → **Place Order** succeeds.
- Track Order screen loads correctly and shows the real order (`#DB-1001`),
  status stepper (Placed/Accepted/Rider/Picked up/Delivered), item list, and
  price — "Waiting for the store to confirm your order."
- Getting here required fixing **16 separate real schema/data gaps** between
  the mock API and what the actual client sends — every one documented with
  a one-line problem→solution in **`mock-api/SCHEMA_BUGS.md`** (read that
  file for the full list; not duplicated here). Highlights: opening-hours
  day/time format, `emailExist`/`login` argument and type mismatches, a
  session token that needed to be real-JWT-shaped, a missing `profile`
  query (crashed Cart/Checkout after login), `tips` returning a list instead
  of a single object, an `AddressInput` missing two demo-mode fields the
  client already sends, and `getUsersActiveOrders`/`getUsersPastOrders`
  returning a thin summary type instead of the full `Order` shape (this
  turned out to be core plumbing every logged-in screen depends on, not an
  out-of-scope "order history" feature as first assumed).
- **Mock API now persists its in-memory state to `mock-api/.demo-snapshot.json`**
  (autosaved every 2s, reloaded on boot) specifically so that restarting the
  server to pick up a schema fix no longer wipes whatever order/cart/login
  state was already built up mid-test.
- **Not yet exercised this session**: rider claiming/delivering the order,
  live status updates flowing back to this Track Order screen. That's the
  next step (see Pending).

### 6. Store app — native Android build, first full order accept confirmed
Built natively for the first time this session (reused the same emulator as
the customer app, sequential use — installed as a second app, not a second
device, since it's a different package). Required adding a missing env-var
override for MULTI vendor mode in `environment.ts` (customer/rider already
had this; store didn't — see `SCHEMA_BUGS.md`'s note on this, since it's
config plumbing rather than a schema-shape change). Logged in as
`store-demo`/`demo1234`, saw the real customer-placed order `#DB-1001` with
correct customer/address/items/price, and accepted it — server confirms
`orderStatus: ACCEPTED`, `preparationTime: "10"`. Full list of schema gaps
found/fixed while getting here is in `mock-api/SCHEMA_BUGS.md` (entries
14-17), not duplicated here.

## Bugs found and fixed in the actual app code (not just the mock API)

These are real, pre-existing bugs in `enatega-multivendor-app`, found because
this session is the first time multivendor mode has been run against a real
backend locally:

1. **`src/screens/CreateAccount/CreateAccount.js`** — the "Continue as
   Guest" button called `navigation.navigate('Discovery')` directly, but
   `Discovery` is nested inside the `Main` tab navigator, not a top-level
   route — this threw a navigation error and silently did nothing. Fixed to
   use the existing `getModeHomeRoute(mode)` helper (already used correctly
   elsewhere in the same file for the Google/Apple sign-in paths).
2. **`environment.config.js`** — multivendor mode's `GRAPHQL_URL`/
   `WS_GRAPHQL_URL`/`SERVER_REST_URL` were hardcoded to Enatega's live
   `aws-server-v2.enatega.com`, with no env var override (single-vendor mode
   already had one). Added `EXPO_PUBLIC_GRAPHQL_URL` /
   `EXPO_PUBLIC_WS_GRAPHQL_URL` / `EXPO_PUBLIC_SERVER_REST_URL` overrides,
   mirroring the existing single-vendor pattern, so local/demo builds can
   point multivendor mode at the mock API too.
3. Two earlier fixes (store/rider **web** apps, before priority shifted to
   the customer app):
   - `Appearance.setColorScheme is not a function` crash on web (react-native-web
     doesn't implement it) — guarded with a `typeof` check in both apps'
     `theme.context.tsx`.
   - `react-native-maps` has no web support and broke Metro's entire web
     bundle (expo-router eagerly resolves every route file) — added a Metro
     `resolveRequest` alias to web-only stub modules in the rider app.

## Google Maps

Multivendor mode needs a **Google Maps API key for Android**, baked into
`AndroidManifest.xml` at native-build time (`app.config.js` reads
`EXPO_PUBLIC_GOOGLE_MAPS_API_KEY_ANDROID`). Retrieved an existing unrestricted
key from the `cosmic-bonus-385504` ("Google Map Api Demo") GCP project via
`gcloud` CLI and wired it into both `.env` and directly into the already-built
`AndroidManifest.xml` (faster/safer than re-running `expo prebuild`, which
could have disturbed other native fixes already in place).

## Mock API additions made for multivendor (this session)

All in `mock-api/src/`:
- **`data.js`**: added `restaurant2` (Sushi Point) and `restaurant3` (Pizza
  Palace) fixtures, each with their own nested categories/foods/variations;
  `restaurants` array, `findRestaurant`/`findRestaurantFood`/
  `findRestaurantVariation` helpers; a real `zones` fixture (Karachi-centered
  polygon, needed for the city picker's centroid math); `cuisines`/
  `shopTypes` stub lists.
- **`schema.js`**: extended `Restaurant` type with browse/detail fields
  (`categories`, `addons`, `options`, `rating`, `cuisines`, `tags`, etc.);
  extended `Zone` with `title`/`location`/`tax` (was `_id`-only); new types
  for the multivendor-specific shapes (`RestaurantCategory`/`RestaurantFood`/
  `RestaurantVariation`/`RestaurantAddon`/`RestaurantOption`/
  `RestaurantCarouselPreview`/`NearByRestaurantsResult`/`ZonePolygon`); new
  Query fields (`nearByRestaurantsPreview`, `topRatedVendorsPreview`,
  `recentOrderRestaurantsPreview`, `mostOrderedRestaurantsPreview`, `zones`,
  `cuisines`, `fetchAllShopTypes`, `userFavourite`); extended `placeOrder`
  with optional multivendor-only args (`restaurant`, `orderInput`,
  `taxationAmount`, `deliveryCharges`).
- **`resolvers.js`**: resolvers for all of the above; `placeOrder` now
  branches — multivendor path (order lines from `orderInput`, looked up
  against the named restaurant) vs. the original single-vendor path
  (server-side cart + checkout quote) — sharing one order-building code path
  either way.
- **`mapsProxy.js`** (new file): the app expects its *own backend* to proxy
  Google Places/Geocoding (`GET /maps/reverse-geocode`, `/maps/autocomplete`,
  `/maps/place-details`) rather than calling Google directly. Implemented all
  three as simple stubs scoped to Karachi (a small canned list of
  neighborhoods for autocomplete; reverse-geocode always resolves to
  "Karachi, Sindh, Pakistan").
- **`metricsGeneral` mutation**: the customer app calls this on startup as a
  "public access token" handshake (unrelated to real user auth — an
  anti-abuse token for all three apps' `bop-auth` header). Wasn't
  implemented, causing a visible red error toast on launch. Added a stub
  resolver returning a fixed token + 24h expiry.

## Known limitations / things stubbed for the 2-day scope

- Only one zone (Karachi), one fully-wired restaurant (Demo Bistro) for the
  live store/rider walkthrough.
- Restaurant "open" status is real (computed from seeded `openingTimes` vs.
  actual device clock) — currently `09:00–23:00`. **If you demo outside
  those hours, restaurants will correctly show "Closed."** Say the word and
  I'll widen this to 24/7 for testing convenience.
- Multivendor cart is 100% client-side by design (matches the real app's
  actual behavior) — no server cart mutations were needed for multivendor.
- `calculateCheckout` is not used in multivendor mode (also matches real app
  behavior — pricing is computed client-side there).
- Autocomplete/reverse-geocode are static Karachi-only stubs, not real
  geocoding.

## Pending / not yet done

- **Rider app — up next.** Customer and store sides are both done: a real
  order (`#DB-1001`) went customer places → store accepts, and now sits at
  `orderStatus: ACCEPTED`, `rider: null`, waiting to be claimed. Rider app
  was already built natively on a second emulator (`EnategaRider_API34`)
  and logged into multivendor mode earlier this session, but not yet
  re-tested against this specific order end-to-end (claim → progress →
  deliver). The two emulators are run **sequentially, not simultaneously**
  (RAM-constrained machine) — stop whichever emulator is currently up before
  starting the other.
- **Full three-app live rehearsal**: place a real order on the customer app
  → confirm it appears live in the store app → accept → confirm it appears
  live in the rider app → claim → progress to delivered → confirm the
  customer app reflects every step live, with no manual refresh anywhere.
  This is the actual demo rehearsal and hasn't been run this session (all
  verification so far has been per-app/per-flow, or scripted via
  `test-lifecycle.sh` for single-vendor only).
- **Do at least 2 full rehearsals** before the real client call, per the
  original plan — none have been done yet this session with the current
  (post-multivendor) mock API build.
- Not committed: everything above is uncommitted working-tree changes on
  `demo/order-lifecycle-mock-api`.

## Running everything (quick reference)

```bash
# Mock API + store/rider web
mock-api/demo.sh start
mock-api/demo.sh status
mock-api/demo.sh stop

# Customer app (native, Android emulator) - separate, not covered by demo.sh
# One-time per reboot, before any native rebuild:
#   (PowerShell) subst X: D:\dev\food-delivery-multivendor\enatega-multivendor-app
cd /x/android && ./gradlew.bat app:assembleDebug -x lint -x test --build-cache -PreactNativeArchitectures=x86_64
# then: start the emulator, adb install the APK, adb reverse tcp:8081 tcp:8081,
# npx expo start -c from enatega-multivendor-app/, launch the app.

# Reset demo data between rehearsals
curl -s -X POST http://localhost:4000/graphql -H "Content-Type: application/json" -d '{"query":"mutation{ resetDemo }"}'
```
