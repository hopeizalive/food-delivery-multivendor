# Admin E2E Testing Status

Single source of truth for Playwright coverage of `multivendor-admin` screens and
known open issues against `mock-api`. Update this file as screens are covered or
issues are resolved — do not scatter status notes elsewhere.

Run all specs: `npx playwright test --reporter=list` (from `multivendor-admin/`).
Requires mock-api on `:4000` and admin dev server (`next dev -p 3001`) already running.

## ⚠️ Current environment: admin is pointed at the HOSTED production demo API, not local mock-api

`multivendor-admin/.env.local` (`NEXT_PUBLIC_SERVER_URL` /
`NEXT_PUBLIC_WS_SERVER_URL`) was repointed from `http://localhost:4000/` to
`https://enatega-demo-mock-api.onrender.com/` during this session, to get the
Orders grid showing the real orders placed by the customer/store/rider apps
during demo rehearsal (those apps talk to the hosted instance, not local
mock-api — the admin was the only piece still pointed at localhost).

**This has NOT been reverted back to localhost.** Consequences:
- Running any Playwright spec right now (including the ones in this repo)
  hits the **live hosted demo backend**, not disposable local mock-api data.
  CRUD specs create/edit/delete real-looking records there — don't run the
  full suite against this env without reverting first, or you'll pollute the
  shared demo backend other people/apps are pointed at.
- The hosted instance was reset via the `resetDemo` mutation this session
  (clean, 0 orders) specifically for a live demo rehearsal — running specs
  against it now would immediately undo that clean state.
- The mock-api schema/resolver/data changes made this session (cuisines,
  banners, coupons, tipping, commission-rate contracts + the two bug fixes
  below) have now been **pushed** to `github.com/hopeizalive/enatega-demo-mock-api`
  (its own separate repo). Render redeploys from that push automatically but
  takes a minute or two to build - confirmed live once `{ coupons { _id } }`
  resolves against the hosted URL instead of erroring
  `Cannot query field "coupons" on type "Query"`.

**Before resuming any spec-writing/running work**, revert `.env.local` to
`http://localhost:4000/` / `ws://localhost:4000/`, restart the admin dev
server (`next dev -p 3001`), and confirm local mock-api is running.

## Coverage checklist

| Module          | Smoke test              | Full CRUD spec              | Status |
|------------------|--------------------------|------------------------------|--------|
| Login            | `login.spec.ts`          | n/a                           | ✅ Done |
| Dashboard        | `admin-screens.spec.ts`  | n/a                           | ✅ Done |
| Restaurants/Stores | `admin-screens.spec.ts` | `restaurants-crud.spec.ts`   | ⚠️ 80% — create/duplicate/hard-delete pass; status-toggle step fails (see Known Issues #1) |
| Riders           | `admin-screens.spec.ts`  | `riders-crud.spec.ts`        | ✅ Done |
| Users            | `admin-screens.spec.ts`  | `users-crud.spec.ts`         | ✅ Done |
| Vendors          | `admin-screens.spec.ts`  | `vendors-crud.spec.ts`       | ✅ Done |
| Orders           | `admin-screens.spec.ts` (list loads only) | — | ⚠️ Grid itself works correctly (see Known Issue #-1, fixed) but no CRUD spec yet |
| Zones            | — | — | ❌ Not started |
| Shop Types       | — | — | 🔧 mock-api contract complete (pre-existing). Spec not yet written. |
| Cuisines         | — | — | 🔧 mock-api contract fixed this session (mutations + resolvers added). Spec not yet written. |
| Banners          | — | — | 🔧 mock-api contract fixed this session (mutations + seed data added). Spec not yet written. |
| Coupons          | — | — | 🔧 mock-api contract fixed this session (admin list queries + mutations + seed data added). Spec not yet written. |
| Tipping          | — | — | 🔧 mock-api contract fixed this session (mutations added). Spec not yet written. |
| Commission Rate  | — | — | 🔧 mock-api contract fixed this session (`commissionRate` paginated query + `updateCommission` mutation added). Spec not yet written. |
| Wizard steps 3-4 | — | — | ❌ Not covered (only steps used incidentally by restaurants-crud) |

Modules at "80%+ / core CRUD operations pass" are considered covered for now; the
gap is logged below rather than blocking forward progress on the remaining modules.

## Pending task (in progress)

Working through the 6 "configuration screens" (Shop Types, Cuisines, Banners,
Coupons, Tipping, Commission Rate) end-to-end today, per explicit instruction to
prioritize breadth (cover all modules) over depth (perfecting every bug) — open
bugs get logged in this file rather than blocking forward progress.

**Done:**
- Full mock-api contract gap inventory for all 6 screens (schema.js/resolvers.js/
  data.js cross-referenced against client's GraphQL documents).
- All missing schema types/inputs/enums, resolvers, and seed data added to
  `mock-api/src/{schema.js,resolvers.js,data.js}` for Cuisines, Banners, Tipping,
  Commission Rate, and Coupons (Shop Types needed no changes — already complete).
  Verified via direct GraphQL calls against a clean mock-api restart: queries,
  paginated queries, and create mutations all confirmed working for every screen.
- UI structure investigated for all 6 screens (add-button text, form field
  placeholders/types, required-vs-optional validation, dropdown dependency chains,
  table columns, row-action patterns, delete-confirm dialogs) — see notes below,
  used directly to write specs without re-reading source files.

**Not yet done:**
- Spec files not yet written for any of the 6 screens.
- Two screens (Cuisines, Banners) require a **real image/file upload** to pass
  client-side Yup validation (`image`/`file` marked `.required()`), unlike
  Restaurants where the field silently defaults to a placeholder URL. The
  existing pattern from `vendors-crud.spec.ts` handles this already: fill
  `input[type="file"]` with `e2e/fixtures/test-image.png`, wait for the
  "has been uploaded successfully" toast, then continue — mock-api's
  `uploadImageToS3` resolver (`mock-api/src/resolvers.js:1588`) returns a fake
  picsum.photos URL without needing a real S3 bucket, so this works offline.
- Tipping and Commission Rate are **not** create+list-table screens like the
  other four — see UI notes below; their specs need a different shape (a
  singleton inline-edit form, and a per-row inline-editable table with no
  create/delete, respectively).

### UI notes per screen (from investigation, for writing specs)

- **Shop Types** (`/management/shop-types`): Add button "Add Shop Type" (a
  `<div>`, not a `<button>` — must click via `getByText`, not `getByRole`).
  Form: optional image (defaults to placeholder if skipped), required "Title"
  text field, Enabled/Disabled toggle (defaults true). Submit "Add"/"Update".
  Table: inline status switch (toggles via `UPDATE_SHOP_TYPE`, no confirm) +
  ⋮ ActionMenu (Edit/Delete, `aria-haspopup="true"` — use existing `openRowMenu`
  helper). Delete has a confirm dialog.
- **Cuisines** (`/management/cuisines`): Add button text is **"Add Cuisines"**
  (plural). Form title "Add Cuisine". Required fields: "Name", "Description"
  (textarea), "Shop Category" dropdown (via `selectDropdownOption`, has a 5s
  debounce before options populate — same caveat as the restaurant wizard),
  and a **required** image upload. Submit "Add"/"Update". Table: ⋮ ActionMenu
  only, no inline toggle (cuisines have no `isActive` field).
- **Banners** (`/management/banners`): Add button "Add Banner". Required
  fields: "Title", "Description", "Actions" dropdown (options: "Navigate To
  Specific Restaurant" / "Navigate To Specific Page"), "Screen" dropdown
  (options depend on Actions choice — picking "Navigate To Specific Page"
  gives static options "Near By Restaurants"/"Grocery List"/"Top Brands",
  simpler than the restaurant-dependent branch), and a **required** file
  upload (image or video). Table: ⋮ ActionMenu only, no inline toggle.
- **Coupons** (`/management/coupons`): Add button "Add Coupon". Fields:
  Enabled/Disabled toggle (defaults true), required "Title" (this is the
  coupon code), required "Discount" number field (1-100), "Lifetime Active"
  switch (toggling it on hides the otherwise-required Start/End Date fields —
  simplest path for a spec is to turn it on and skip dates entirely). Table:
  inline status switch (toggles `enabled` via `EDIT_COUPON`) + ⋮ ActionMenu.
- **Tipping** (`/management/tippings`) — ⚠️ not a table screen: a single
  global record edited inline on the page, no Add button, no modal. Three
  number fields ("Tip 1 eg 10" / "Tip 2 eg 20" / "Tip 3 eg 30", must be 3
  distinct values 1-100) plus one submit button, labelled "Add" if no record
  exists yet or "Update" if one does (mock-api's seed already has a `tips`
  record, so it will always read "Update" against this mock-api).
- **Commission Rate** (`/management/commission-rates`) — ⚠️ not a
  create/delete screen: a paginated table of existing restaurants, each row
  has its own inline number input (no label, target via the row locator) and
  its own "Save" button (disabled until that row's value changes). No Add,
  no Edit modal, no Delete. A spec has to operate against a seeded restaurant
  row rather than spinning up a fresh record.

## Known issues

### -1. Orders grid showed no orders (FIXED — not a code bug, an env misconfiguration)

**Symptom:** `/management/orders` never showed the real orders placed via the
customer/store/rider apps during demo rehearsal.
**Root cause:** the customer/store/rider apps are configured against the
**hosted** demo backend (`https://enatega-demo-mock-api.onrender.com`), but
`multivendor-admin/.env.local` was still pointing at local `mock-api`
(`http://localhost:4000/`) — two completely disconnected backends. The
`allOrdersPaginated` query, resolver, and UI component were all working
correctly the whole time; the admin was just looking at the wrong (empty)
backend. Confirmed via direct GraphQL calls to both backends before fixing.
**Fix:** repointed `.env.local`'s `NEXT_PUBLIC_SERVER_URL` /
`NEXT_PUBLIC_WS_SERVER_URL` at the hosted instance and restarted the admin
dev server — grid now shows the real orders. **See the environment warning
at the top of this file** — this is *why* the admin currently points at
production instead of local mock-api, and needs reverting before resuming
local spec work.

### 0. Coupon creation with "Lifetime Active" silently did nothing (FIXED)

**File:** `lib/utils/schema/coupon.ts` — `CouponFormSchema`.
**Bug:** `endDate: Yup.date().when('lifeTimeActive', {is: false, then: required, otherwise: notRequired()})`.
`.notRequired()` only skips the *presence* check, not type casting. The actual
field is a native `<input type="date">`, which yields `''` when empty, and
Yup's `date()` type tries to cast `''` to a `Date` regardless of whether it's
required, producing an invalid-type validation error - blocking submission
even when `lifeTimeActive` was true (so Start/End Date aren't even shown).
The form has no `<ErrorMessage>` wired for `endDate`, so this failed
completely silently: clicking "Add"/"Update" just closed nothing, and no
`CreateCoupon`/`EditCoupon` mutation ever fired - found via network-traffic
logging in a debug spec, not from any visible error.
**Fix:** added `.transform((value, originalValue) => originalValue === '' ? undefined : value)` to the `endDate` schema so an empty string is treated as
absent (skipped by `.notRequired()`) rather than cast to an invalid `Date`.
This means every "lifetime" coupon create/edit was broken before this fix -
a genuine pre-existing client bug, not something introduced this session.

### 1. Restaurant status-toggle checkbox does not flip (OPEN)

**Spec:** `restaurants-crud.spec.ts` — "create a restaurant, toggle status, duplicate, then hard delete"
**Symptom:** After clicking the status checkbox for a freshly created restaurant, the
checkbox remains `checked` — `expect(row.getByRole('checkbox')).not.toBeChecked()` times
out after 10s.

**Investigated and ruled out:**
- mock-api `deleteRestaurant` resolver itself — verified correct via direct curl
  (toggles `isActive` and returns the updated record).
- Pagination pollution (newly-created restaurant landing on page 2+ because
  `restaurantsPaginated` has no sort/order-by and orphaned test restaurants
  accumulate in the array) — ruled out by restarting mock-api for a clean seed
  and re-running; failure still reproduces on a restaurant that is confirmed
  visible on page 1.
- Missing `refetchQueries` on the client mutation — added
  `refetchQueries: ['restaurantsPaginated', 'getClonedRestaurantsPaginated']` to
  `deleteRestaurant` in
  `lib/ui/useable-components/table/columns/restaurant-column.tsx` (modeled on the
  working rider-toggle pattern in `rider-columns.tsx`, which uses
  `refetchQueries: 'active', awaitRefetchQueries: true`). Did **not** fix it —
  confirmed via clean re-run above.
- A standalone debug script toggling the *seeded* "Demo Bistro" row (not a
  freshly created one) worked correctly and the mutation/network traffic looked
  correct (deleteRestaurant fires, returns `isActive: false`). This suggests the
  bug is specific to a restaurant created earlier in the *same test/browser
  session*, not the toggle mechanism in general — not yet confirmed why.

**Next things to try (not yet attempted):**
- Add `awaitRefetchQueries: true` to the restaurant mutation (rider's working
  version has this; the current restaurant fix doesn't).
- Check whether the newly-created restaurant's cache entry has a different
  normalized key/shape than seeded ones right after the create-restaurant
  mutation (e.g. missing `__typename` or `_id` vs `id` mismatch) that would break
  Apollo's cache merge/refetch write-back specifically for session-created rows.
- Inspect network traffic for the toggle click on a *freshly created* restaurant
  specifically (the earlier debug script only tested a seeded row) to see if the
  mutation fires at all / returns the expected payload in that scenario.

**Workaround for now:** none applied; the CRUD spec's toggle assertion step is the
only failing step, create/duplicate/hard-delete steps in the same spec all pass.

## Mock-api contract gaps (configuration screens)

Full inventory, cross-referenced against client mutation/query documents in
`lib/api/graphql/{queries,mutations}/<entity>/`:

- **Shop Types** — contract complete, no gaps.
- **Cuisines** — `cuisinesPaginated`/`cuisines` queries exist; `createCuisine`,
  `editCuisine`, `deleteCuisine` mutations missing from `schema.js`/`resolvers.js`.
- **Banners** — `banners` query exists; `createBanner`, `editBanner`,
  `deleteBanner` mutations missing; no `banners` seed array in `data.js`.
- **Tipping** — `tips` query exists (singleton); `createTipping`, `editTipping`
  mutations missing.
- **Commission Rate** — `updateCommission` mutation missing.
- **Coupons** — largest gap: admin `coupons`/`couponsPaginated` list queries
  missing entirely (only storefront-facing `couponsbyRestaurant`/`coupon` exist),
  plus `createCoupon`/`editCoupon`/`deleteCoupon` mutations and a `coupons` seed
  array are all missing.
