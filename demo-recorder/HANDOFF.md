# Demo recorder — handoff notes

Status snapshot for whoever (human or agent) picks this up next. Read this
before touching anything — it captures hours of empirically-learned gotchas
that aren't obvious from the code alone.

## Goal

Build a narrated demo video of the full order lifecycle (customer places an
order -> store accepts -> rider delivers) across the three Expo/React Native
apps (`enatega-multivendor-app`, `-store`, `-rider`), driven against the
self-hosted mock GraphQL backend (`mock-api/`), for a client demo.

## Two automation approaches exist — use `adb-flows/`, not `flows/`

- **`demo-recorder/adb-flows/`** — the current, active approach. Pure `adb
  shell` automation (uiautomator dumps + `input tap`/`input text`), runs
  natively on Windows via Git Bash. **No WSL2, no Maestro.** This is what
  works and what you should extend.
- **`demo-recorder/flows/`** (Maestro YAML) + `demo-recorder/scripts/maestro-run.sh`
  — the earlier approach, abandoned. Required WSL2 (Maestro has no native
  Windows CLI) and proved too unreliable driving a Windows-hosted emulator
  from inside WSL2 (silent hangs, adb-server contention when another adb
  binary — e.g. scrcpy's bundled copy — is also running). **Do not build on
  this.** It's left in place for reference only; do not delete without asking.

## `adb-flows/` structure

```
adb-flows/
  lib/adb-ui.sh          # the core library - read this first
  dump-text.sh           # fast diagnostic tool: dumps all on-screen text and bounding boxes
  customer/01-login.sh ... 05-place-order.sh
  store/01-login.sh, 02-accept-order.sh
  rider/01-login.sh ... 04-deliver-order.sh
  run-customer.sh        # chains all 5 customer steps
  run-store.sh           # chains store login and accept-order
  run-rider.sh           # chains rider login, claim, pickup, and deliver
  run-all.sh             # single-command master runner: Customer -> Store -> Rider
```

All 3 apps have fully automated, passing ADB shell flows.

### `lib/adb-ui.sh` — function reference

All functions log a timestamped one-line action, so a run's stdout is a
readable transcript. Source it (`source lib/adb-ui.sh`) from a script that
first `cd`s to `adb-flows/` (see any existing flow script's header for the
pattern).

- `ui_dump` — pulls a fresh uiautomator dump to `/tmp/demo-dumps/current.xml`, returns its path.
- `wait_for_id <testID> [timeoutSec]`, `wait_for_text <exact text> [timeoutSec]` — poll using **wall-clock time** (`$SECONDS`), not an iteration counter. (Earlier bug: counting iterations as seconds under-counted real elapsed time 3-4x, because each dump+pull round trip itself takes several seconds.)
- `tap_id`, `tap_text`, `tap_desc` — find-and-tap by testID / exact text / exact `content-desc`. `tap_desc` matters because some elements (e.g. Expo dev-launcher's server-list rows) put their label in `content-desc` on the actual clickable node while the visible text sits on a separate non-clickable child — text-matching alone can miss the truly-clickable target.
- `tap_id_retry <id> [tries] [pause]` — retries a tap; covers a confirmed real flakiness where the first automated tap after a screen transition sometimes doesn't register even though Maestro/adb reports success.
- `type_text` — wraps `adb shell input text`, escaping spaces as `%s` (required, `input text` chokes on literal spaces).
- `force_relaunch` / `clean_relaunch` — force-stop+relaunch, or `pm clear`+relaunch for a fully deterministic run (wipes AsyncStorage: cart, login session, dev-client's "last connected server" memory).
- `ensure_dev_client_connected <metroUrl> [timeoutSec]` — see "Expo dev-client connect screen" below. This is the trickiest part of the whole framework.
- `dismiss_dev_menu [timeoutSec]` — dismisses the Expo dev-client's developer-menu overlay (Reload/Go home/Continue/...). Keys on `"Reload"` + `"Go home"` both being present, **not** on `"Continue"` or the descriptive text — both are confirmed to sometimes be absent from the accessibility tree even while the menu is visibly showing.
- `wait_for_stable_screen [timeoutSec]` — polls until the screen has any non-empty text content, for use right after a cold launch.

## Hard-won lessons (read before you re-debug these)

1. **Never press Back blindly at the very start of a flow.** On the Expo
   dev-launcher's root chooser screen, Back **exits the app entirely**
   (confirmed — dropped straight to the home launcher), it does not dismiss
   anything. Only ever act on a screen after confirming via a dump what's
   actually showing.

2. **The dev-launcher chooser screen's server list loads asynchronously,
   after the header.** The "Development Build" header can render several
   seconds before the actual "Recently opened" / "Development servers" row
   you need to tap exists in the tree. A single one-shot check-then-tap is
   not reliable — you must poll for the row itself, not just the screen.

3. **A tap command "succeeding" (adb returns 0) does not mean navigation
   happened.** Confirmed: a tap can silently miss (e.g. row not fully
   interactive yet, mid ripple-in) with adb reporting success anyway.
   `ensure_dev_client_connected` verifies the chooser screen was actually
   left before declaring success, and retries otherwise (5 attempts, 10s
   apart — tune via the function's params, not a magic number rewrite).

4. **Every app running on the shared emulator steals focus from every
   other app.** Before starting any flow, force-stop the *other* apps, or
   you'll end up scripting taps against the wrong app's screen (this
   happened — a whole debugging detour chasing a "stuck screen" that was
   actually the rider app's dev-launcher in the foreground).

5. **`pm clear` wipes more than app data — it wipes the dev-client's own
   "last connected Metro server" memory too**, since that's stored in the
   same AsyncStorage. So after `pm clear`, expect the dev-launcher chooser
   screen on next launch (not an auto-reconnect), and handle it.

6. **Manual interaction and an active automated script must never run at
   the same time against the same emulator.** Confirmed: doing both caused
   a race (double-tap navigation, confusing/contradictory results). If you
   need to look at the screen while a script runs, use **read-only**
   `uiautomator dump` / `adb exec-out screencap` only — never `input tap`
   — until the script has finished.

7. **A second `adb` binary running concurrently (e.g. scrcpy's bundled
   copy) can cause silent, intermittent hangs** in `adb shell`/`adb pull`
   calls — no error, just a script that stalls with no further log output
   for far longer than any configured timeout. If a run mysteriously stalls
   with no log progress, check `ps aux | grep -i adb` (or `Get-Process
   adb` in PowerShell) for more than one adb process and consider whether
   something (scrcpy, Android Studio) started its own.

8. **A native notification-permission Android dialog appears the first
   time an order is placed** ("Allow Enatega Multi to send you
   notifications?"), blocking the Track Order screen until dismissed.
   `customer/05-place-order.sh` already handles this — mirror that
   pattern for any other first-time-permission dialogs you hit.

9. **Two apps sharing the same LAN Metro-discovery mechanism can surface
   each other's server URL in their own dev-launcher's "Development
   servers" list** — this is normal (Expo's discovery isn't scoped per
   package), not a sign anything is misconfigured. Just make sure you tap
   the URL for the correct port.

10. **`dump-text.sh` is your best friend when elements aren't found.**
    Instead of guessing coordinates or reading through 50KB XML dumps, run
    `bash dump-text.sh`. It prints each visible text node alongside its exact
    bounding box coordinates (`[x1,y1][x2,y2]`).

11. **Tall order cards in Store app push the Accept button below the viewport.**
    On a 1080x2400 screen, when an order has multiple items, tax, tip, and
    address details, the `Accept` and `Decline` buttons sit below y=2400 or
    behind the bottom navigation bar. `store/02-accept-order.sh` handles this
    by swiping up (`adb shell input swipe 540 1800 540 800`) whenever the
    button is not immediately on screen.

12. **Asynchronous Expo push notification alerts can appear mid-flow.**
    Expo frequently throws a native modal alert on emulator:
    `"Must use physical device for Push Notifications" [OK]`. If this pops up
    while a script is waiting for an element, the modal blocks all touches.
    `lib/adb-ui.sh` now has `dismiss_known_alerts` wired directly into the
    polling loops of `wait_for_id` and `wait_for_text`, automatically tapping
    "OK" and resuming the search without failing.

13. **All login flows are idempotent.**
    If an app is already logged in (e.g. from a previous test run without `pm clear`),
    the login input fields will never render. `customer/01-login.sh`,
    `store/01-login.sh`, and `rider/01-login.sh` all check for dashboard indicators
    (`Orders`, `Discovery`, `Delivery Orders`) first, passing cleanly if the
    session is already active.

## Expo dev-client connect: the single biggest time sink

Every app is running as an Expo **dev-client** build (not a production
build), which means every cold launch goes through: dev-launcher chooser
screen -> tap the right Metro URL -> manifest fetch -> bundle download ->
developer-menu overlay may or may not pop up -> app finally renders. Almost
every debugging detour this session traced back to some part of this
sequence. `ensure_dev_client_connected` + `dismiss_dev_menu` encode
everything learned about automating it, but it remains the least reliable
part of the whole pipeline.

**The real, permanent fix — not yet done — is to switch to a preview/
production EAS build for recording.** That embeds the JS bundle in the APK:
no Metro, no chooser screen, no connect handshake, no dev-menu overlay. App
opens straight to its real first screen every time, ~20 min build cost per
app. Strongly recommended before investing further in chooser-screen
automation robustness. (Detox was considered as an alternative to
Maestro/adb-shell entirely; estimated 4-8+ hrs to integrate across three
apps and would **not** fix the dev-client-menu race specifically — same
conclusion: the production build is the right fix, not a different driver
tool.)

**Unresolved as of this handoff**: the store app's dev-client connect to its
own Metro (port 8082) intermittently shows "Error loading app: timeout" even
after a successful-looking `ensure_dev_client_connected` tap. Investigation
so far: the manifest endpoint (`curl http://localhost:8082/`) took **7.1s**
to respond in one measurement — slow enough to plausibly race the
dev-client's internal timeout, especially under host CPU/memory contention
(two Metro bundlers + emulator + Gradle daemon running simultaneously). The
idle Gradle daemon (~1.66GB) has been stopped (`./gradlew --stop` in
`enatega-multivendor-store/android/`) to reduce contention. Retesting the
connect after that was in progress when this handoff was written — **check
whether it's now reliable before assuming it's still broken**. If it's still
flaky, the production-build fix above would sidestep it entirely.

## A real app bug was found and fixed this session

**File**: `enatega-multivendor-store/i18next.ts` and `app/_layout.tsx`.

**Symptom**: store app showed a real render crash (not just a warning) on
the Home/Orders screen — `prevDeps.join is not a function (it is
undefined)`, with a preceding "React has detected a change in the order of
Hooks called by HomeNewOrdersMain" console error.

**Root cause**: `i18next.ts` called `initializeLanguage()` (async, never
awaited) at module load. Any component using `useTranslation()` that
rendered before `i18next.init()` resolved, and stayed mounted across that
transition, took a different internal hook path in `react-i18next` before
vs. after — a genuine Rules-of-Hooks violation, not an issue in the app's
own component code (verified: `HomeNewOrdersMain`'s and `useOrders`'s own
hooks are all unconditional, fixed-order).

**Fix applied**: `i18next.ts` now exports `i18nextReady` (the init promise).
`app/_layout.tsx`'s existing `appReady` gate (which already blocked
rendering on fonts/mode/token readiness) now also waits on
`i18nextReady` via a new `isI18nReady` state, so no screen — and therefore
no `useTranslation()` call — mounts until i18next has actually finished
initializing. This was confirmed root-caused via the on-device error
overlay's "Previous render / Next render" hook diff (tap "See More" on the
Console Error log to expand it) rather than guessed from source alone —
recommended technique if a similar hook-order error shows up elsewhere.

This is a **legitimate bug fix**, not a demo-automation workaround — it
would have hit real users too, just for whatever render happens to land
right on the init-boundary at cold start.

## Standing constraints (do not violate)

- **Never `git commit` unless explicitly asked.**
- **Never modify client app code** except: (a) the narrow, pre-approved
  `testID` additions already made (see the flow scripts for which
  testIDs exist on which apps/screens — customer, store, and rider all
  have a matching set), and (b) genuine bug fixes discovered and approved
  during this work, like the i18n gate above — always explain the root
  cause and get explicit go-ahead before editing app code for anything
  beyond testIDs.
- **mock-api gaps get fixed in mock-api** (`mock-api/src/schema.js` /
  `resolvers.js` / `data.js`), never worked around in client code. See
  `mock-api/SCHEMA_BUGS.md` for the running log of these.
- **Run anything that takes more than a couple seconds in the background**,
  not in the foreground/"main window" — this was explicit, repeated user
  feedback this session. Use read-only checks (`uiautomator dump`,
  `screencap`) to monitor progress instead of blocking foreground calls.

## Environment reference

- Mock API: `http://localhost:4000/graphql` (also reachable from the
  emulator as `10.0.2.2:4000`). `resetDemo` mutation gives a clean
  deterministic starting state — call it before each full-lifecycle run.
- Emulator: `EnategaDemo_API34`, AVD RAM already trimmed to 1536MB
  (`~/.android/avd/EnategaDemo_API34.avd/config.ini`) to reduce host memory
  pressure. `10.0.2.2` is the emulator's fixed host-loopback alias — use it
  for all app<->host URLs (GRAPHQL_URL, Metro URLs), never a literal LAN IP
  (LAN IPs change and have caused nearly every "stuck screen" symptom this
  session historically).
- App IDs: customer `com.enatega.multivendor`, store
  `multivendor.enatega.restaurant`, rider `com.enatega.multirider`.
- Metro ports in use:
  - Customer: `8081` (`npx expo start -c --port 8081` from `enatega-multivendor-app/`)
  - Store: `8082` (`npx expo start -c --port 8082` from `enatega-multivendor-store/`)
  - Rider: `8083` (`npx expo start -c --port 8083` from `enatega-multivendor-rider/`)
- Demo credentials:
  - Customer: `demo@enatega.com` / `demo1234`
  - Store: `store-demo` / `demo1234`
  - Rider: `rider-demo` / `demo1234`
- Running the Full Story in One Go:
  ```bash
  cd demo-recorder/adb-flows
  bash run-all.sh
  ```
  This single command resets the demo state, executes customer order placement, store order acceptance, and rider delivery to completion without human intervention.

## Current status per flow

- **Customer**: `run-customer.sh` (01 through 05) — **all steps proven
  passing** end-to-end (login through place-order, ending on a real order —
  confirmed order #DB-1001 in "Placed" status). Updated with `launch_dev_client`
  shortcut.
- **Store**: `run-store.sh` (01 and 02) — **all steps proven passing**!
  The deep-link intent shortcut (`launch_dev_client` + `adb reverse tcp:8082 tcp:8082`)
  completely eliminated the dev-client connect timeout. `01-login.sh` logged in
  cleanly, and `02-accept-order.sh` accepted customer order #DB-1001 via the
  "Set Preparation Time" bottom sheet -> Done. Confirmed in mock-api:
  `orderStatus: "ACCEPTED"`.
- **Rider**: `run-rider.sh` (01 through 04) — **all steps proven passing**!
  Runs on Metro port 8083 (`launch_dev_client` with scheme `exp+food-delivery-rider-multivendor`
  and `adb reverse tcp:8083 tcp:8083`). `01-login.sh` logs in/verifies dashboard,
  `02-claim-order.sh` taps "Assign me", `03-pickup-order.sh` opens order details
  and marks order as picked up (`PICKED`), and `04-deliver-order.sh` taps
  "Mark as Delivered" + confirms native Alert dialog (`DELIVERED`).
- **Master Runner**: `run-all.sh` orchestrates the complete 3-app lifecycle
  sequentially (`run-customer.sh` -> `run-store.sh` -> `run-rider.sh`).
- **Narration/recording pipeline** (synthesis, orchestrator, video build
  stage): next up.

## Recommended next steps, in order

1. Rehearse the master end-to-end sequence via `run-all.sh` after a clean `resetDemo`
   to capture timing benchmarks for narration beats.
2. Build narration audio assets using edge-tts synced to the timing of each action beat.
3. Build the ffmpeg recording/mux pipeline to assemble the narrated demo video.
