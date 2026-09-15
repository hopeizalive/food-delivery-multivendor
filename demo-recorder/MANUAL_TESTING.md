# Manual testing guide — order lifecycle (physical device)

For a human driving the three apps by hand on a real Android device, instead
of the ADB automation in `adb-flows/`. Read this before you start; it saves
re-discovering things the automation work already found the hard way.

## 1. One-time setup

1. Plug the phone in via USB, enable USB debugging, accept the "Allow USB
   debugging?" prompt.
2. From the repo root, run:
   ```
   powershell -ExecutionPolicy Bypass -File .\scripts\build-setup\setup-device.ps1
   ```
   This verifies the device is connected, wires up `adb reverse` for all
   three Metro ports (8081/8082/8083), and starts any Metro bundler that
   isn't already running. Re-run it any time you reconnect the device —
   the reverse tunnels don't survive a USB replug.
3. Open each app on the phone. If an app was already installed and
   connected before, it reconnects to Metro automatically. If it shows a
   blank/dev-launcher screen, shake the device and pick "Change bundle
   location" → host `localhost`, the app's port.

## 2. Test accounts

| App | Username | Password |
|---|---|---|
| Customer | `demo@enatega.com` | `demo1234` |
| Store | `store-demo` | `demo1234` |
| Rider | `rider-demo` | `demo1234` |

## 3. Reset demo state before a test pass

All three apps point at the same shared backend
(`https://enatega-demo-mock-api.onrender.com/graphql`) — not localhost.
Resetting clears all in-memory orders/carts so you start from a clean slate:

```bash
curl -s -X POST https://enatega-demo-mock-api.onrender.com/graphql \
  -H "Content-Type: application/json" \
  -d '{"query":"mutation{ resetDemo }"}'
```

Run this before every test pass, since old orders otherwise pile up and can
make it harder to tell which order you're looking at.

## 4. The happy-path flow

Test in this order — each stage depends on the previous one having
happened:

### Customer app
1. Log in (`demo@enatega.com` / `demo1234`) — skip if already logged in,
   you'll land straight on Discovery.
2. Tap **Demo Bistro** (see the restaurant-scoping note below — only this
   restaurant is wired end-to-end).
3. Tap **Loaded Nachos** to add it to the cart.
4. Tap **VIEW YOUR CART** → **Checkout**.
5. Tap **Place Order**. You should land on **Track Order** showing the new
   order.

### Store app
1. Log in (`store-demo` / `demo1234`) — skip if already logged in, you'll
   land on the Orders screen.
2. The new order appears under **New Orders**. **The Accept/Decline
   buttons sit below the fold on a full order card — scroll down inside
   the card if you don't see them immediately.** There's also a live
   "Auto decline in" countdown on this screen; it's just a display timer,
   not an imminent auto-decline (the mock backend does not actually
   auto-decline orders).
3. Tap **Accept** → a "Set Preparation Time" sheet opens. Tap **Done**
   (not "Accept and Print" — that also fires the accept but additionally
   tries to print a receipt, which won't work without a real printer).

### Rider app
1. Log in (`rider-demo` / `demo1234`) — skip if already logged in.
2. Under **New Orders**, tap **Assign me** to claim the order.
3. A one-time in-app dialog may appear ("Allow background location for
   live delivery tracking") — tap **Not now**, it's not needed for testing.
4. Tap **View order details**, then scroll down past the map to find
   **Pick up** (it sits below the map, off the initial viewport).
5. Tap **Pick up** → the button changes to **Mark as Delivered**.
6. Tap **Mark as Delivered** → confirm the dialog that appears.

### Back on the customer app
Track Order should now show the order progressing through each status
live (no manual refresh needed) — Placed → Accepted → Picked up →
Delivered.

## 5. Known limitations

- **Only Demo Bistro is wired end-to-end.** Sushi Point and Pizza Palace
  are browsable and orderable in the customer app, but orders placed
  against them never appear in the store or rider apps — the mock
  backend's `restaurantOrders`/`riderOrders` resolvers are hardcoded to
  Demo Bistro's restaurant ID. This is a deliberate scoping decision from
  the mock-api build, not a bug. If you need a real multi-restaurant
  accept/deliver test, that resolver scoping needs to change first — flag
  it rather than assuming it's a client bug if orders from another
  restaurant seem to vanish after placing them.
- **Single delivery zone** — everything is seeded around Karachi. Don't
  expect other cities to show real data.
- **First app launch after any Metro cache-clear restart can take 30-60
  seconds** to fetch/build the JS bundle before the app renders anything —
  this is normal, not a hang.

## 6. If something looks wrong, verify against the backend directly

Rather than guessing from the UI alone, you can check real order state
with a direct query (swap in the actual order's `_id` if you need one
specific order, or omit filtering to see all current orders):

```bash
curl -s -X POST https://enatega-demo-mock-api.onrender.com/graphql \
  -H "Content-Type: application/json" \
  -d '{"query":"query{ restaurantOrders{ _id orderId orderStatus isPickedUp rider{_id} } }"}'
```

If the backend already shows the status you expect but the app's UI
doesn't reflect it, that's a real client-side bug worth reporting (screen,
exact text/error shown, and this query's output) rather than a test
mistake.
