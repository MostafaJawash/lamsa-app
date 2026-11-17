# لمسة (lamsa_app)

Customer mobile app for the Lamsa beauty store (Flutter, Android and iOS). Arabic only, RTL, light/dark following the system. Customer-facing only: nothing admin.

Status: project structure and plumbing, plus **phase 1: catalog browsing** (home, categories, brands, new, sale, search, product detail) reading real data from the backend, all public/guest. **Phase 2: authentication** (phone + password, Google, session, forced password change, account tab) and **phase 3: cart and favorites** for guests and signed-in users, with the guest-data merge on sign-in. **Phase 4: checkout, orders and account management** (addresses with an OpenStreetMap pin, real order placement, order history/detail with cancel and reorder, profile / phone / password / logout-everywhere). Only the notifications screen is still a placeholder.

## Stack

| Concern | Choice |
|---|---|
| State | `flutter_bloc` (Cubit for screen state, Bloc only where event logic earns it) |
| Routing | `go_router` with an auth guard (`lib/core/router/auth_guard.dart`) |
| Networking | `dio`, hand-written typed API classes, `json_serializable` models |
| Session | `flutter_secure_storage` plus a refresh-rotation interceptor |
| Images | `cached_network_image` plus a size picker for the backend's WebP sizes |
| Push | `firebase_core`, `firebase_messaging` (Firebase project `lamsa-c3e53`) |
| Google sign-in | `google_sign_in` 7.x, drop-in once OAuth clients exist (dev-mode fake until then) |
| Links | `url_launcher` (https banner links, support phone/WhatsApp) |
| Guest data | `shared_preferences` (guest cart and favorites, two small JSON blobs) |
| Formatting | `intl`, number formatting only |
| Fonts | IBM Plex Sans Arabic and Reem Kufi, bundled (same as the website) |
| Tests | `flutter_test`, `mocktail`, `bloc_test` |

Exact versions are pinned in `pubspec.yaml` (no `^`). Rule: published at least 2 weeks before pinning, unless a patch fixes a published security advisory. Pins that deviate from "latest eligible", and why:

- `build_runner 2.16.1`: 2.16.2 and newer require an analyzer that conflicts with `bloc_test`'s `test` requirement.
- `json_serializable 6.14.1` + `source_helper 1.3.13`: 6.15.0 and `source_helper` 1.4.0 clash on extension members and the build script fails to compile.

## Language and RTL

Arabic only (Modern Standard Arabic, same register as the backend and web). Text lives in `lib/core/strings.dart`; there are no ARB files and no locale switching. `MaterialApp` has `locale: ar` and a forced RTL `Directionality`. `flutter_localizations` is included for its delegates only: without them Material widgets crash under a fixed `ar` locale, and with them built-in widgets (date pickers, dialogs, tooltips) show correct Arabic. The backend has no bilingual content fields; everything it returns is already Arabic.

## Folder structure

```
lib/
  main.dart              bootstraps dependencies and runs the app
  app.dart               AppDependencies (wiring) and MaterialApp.router (theme, ar/RTL)
  core/
    theme/               brand tokens ported from lamsa-web (colors, text styles, spacing, ThemeData)
    router/              go_router config, route constants, pure auth redirect rules
    network/             dio setup, auth/refresh interceptor, error mapping, debug-only logging, env
    storage/             secure token storage wrapper
    errors/              ApiError ({error:{code,message,details}}) and Arabic fallback map for every backend code
    money/               currency-aware Money type and formatter (never sums across currencies)
    images/              thumb/medium/large picker and LamsaImage widget
    strings.dart         central Arabic text
    widgets/             buttons, input, loading/empty/error views, placeholder screen
  features/
    auth/                session cubit, auth API, validation, error mapping, Google services, form cubits, screens, SessionGate
    shell/               bottom-nav frame (MainShell) and the "coming soon" tab body
    catalog/             data/ (models, API, repository cache, filters, variant rules), cubit/, presentation/
    cart/                cart + favorites data layer (API, guest codec/store, merge), CartCubit, cart screen
    favorites/           FavoritesCubit, favorites list cubit, heart button, favorites screen
    orders/              OrdersApi, idempotency (checkout_attempt), CheckoutCubit, orders/detail cubits, checkout/orders screens
    account/             addresses (API, repository, rules, cubits, screens, map picker), settings cubits/screens, account menu
    notifications/       device registration API, push service, push deep-link parsing, placeholder
test/                    widget test (boots to RTL home, guard redirect) plus unit tests
tool/                    check_openapi.dart and its snapshot
env/                     dev.example.json (committed); real env/*.json files are git-ignored
assets/fonts/            bundled OFL fonts with licenses
```

## Catalog (phase 1)

Ports lamsa-web's catalog rules to native widgets; same backend, same business decisions.

**Navigation.** Bottom bar with 5 tabs (`StatefulShellRoute`, each tab keeps its own stack and scroll): الرئيسية، الأقسام، المفضلة، السلة، حسابي. Search is the pill in the app bar of Home and Categories. جديد / التخفيضات / الماركات are reached from the chip row (Home and Categories), rails' "عرض الكل" and banners. Category, brand, product, search, new, sale and brands screens are full-screen routes pushed above the tabs.

**Screens.** Home (banners carousel, new rail, category tiles, sale rail, brands; pull-to-refresh; each section loads and fails on its own with lamsa-web's fallbacks: built-in sale/new banners, rail empty messages, categories/brands hidden when empty). Categories tab. Category / brand / new / sale are one `ProductListScreen` with a scope. Search sends the raw query on submit (the backend normalizes Arabic). Product detail: swipeable gallery, brand link, price/sale/savings, color swatches and size chips with live price/stock/images (pure port of lamsa-web's `variants.ts` in `catalog/data/variants.dart`), stock line (exact stock only for the backend's `low` status), description/details, bundle contents, related rail.

**Filters.** Bottom sheets: sort, and a filter sheet built from `/products/facets` (brand, price with SYP/USD choice, attributes, color/size options, "عليه خصم"). No "in stock" filter: the backend hides out-of-stock products (`catalog_hide_out_of_stock`). Active filters show as removable chips; the category's first select attribute and child categories are chips above the grid. A param the backend rejects (`INVALID_FILTER`) is dropped and retried, with a notice.

**Pagination.** Infinite scroll, 24 per page (`page`/`page_size`), spinner footer and a retry row if a page fails. Pull-to-refresh restarts from page 1. Superseded responses are ignored so fast filter changes cannot show stale results.

**Caching.** `CatalogRepository` is an in-memory read-through cache for the app session: products/facets 45 s, product detail 120 s, categories/brands 300 s (the backend's own cache lifetimes), identical in-flight requests are shared, failures are never cached, pull-to-refresh and retry bypass it. Cubits are per screen. No disk persistence and no ETag revalidation yet. Requests are sent without a token (guest), so `is_favorite` is always false for now.

**Images.** `LamsaImage` + `ImageUrls.pick` choose thumb/medium/large by on-screen size. A missing or broken image shows a drawn bottle silhouette (products) or a monogram on a deterministic brand color (brands), like the web.

**Money.** Backend decimal strings are shown in their own currency (`formatAmount`); nothing is converted or summed across SYP/USD.

**Temporary / deferred.**
- The web's shipping/pickup/cash "perks" block is checkout-related and left out.
- No search history, live (as-you-type) search, or full-screen image zoom.

## Authentication (phase 2)

Mirrors lamsa-web's real auth rules with native screens.

**Screens.** Login, register, complete-profile (Google), forced/voluntary change-password, and a real Account tab (name, phone, email, how you signed in, logout). The phone field is a country-code select (+963 default) plus the number; it is combined exactly like the web (`combinePhone`: Syrian trunk zero dropped, international `+`/`00` numbers sent as typed) and the backend normalizes to E.164. Arabic-Indic digits are read as Latin digits (small addition over the web). New passwords show the backend rules as live hints: 8-128 characters, not digits only, not your phone.

**Errors.** `mapAuthError` (port of the web's) puts phone errors under the phone, password errors under the password, `VALIDATION_ERROR` details on their fields, shows a countdown that disables submit for `TOO_MANY_ATTEMPTS` (`Retry-After`), links to login for `ALREADY_REGISTERED`, offers the store phone for `ACCOUNT_DISABLED`, and tells the user to start Google again when the 10-minute signup token expires. `SERVICE_BUSY` is retried once. The backend's Arabic message always wins; the local map is the fallback.

**Session.** `SessionCubit` restores the stored session at launch (auto-login straight to the shell). `SessionState.end` records why a session is not active: a **first launch / guest** browses home; a **dead stored session** (refresh rejected, `TOKEN_REUSED`, `TOKEN_INVALID`) lands on login with an "انتهت الجلسة" notice; a **deliberate logout** lands on login without one. Logout unregisters push, calls `/auth/logout`, clears secure storage, signs out of Google and clears the catalog cache.

**Forced password change.** A login with a temporary password (`must_change_password`) or any `403 PASSWORD_CHANGE_REQUIRED` (reported by `AuthInterceptor` to the session, which re-reads `/users/me`) sends the user to the change-password screen, and the router guard redirects every other route there until the password is changed. The screen has no back button and has its own logout link.

**Gating the tabs.** Favorites, Cart and Account are gated inline by `SessionGate`: a guest sees "سجّل الدخول لمتابعة التسوق" with login/register buttons inside the tab (the bottom bar stays) and the tab swaps to the real content after login. `/orders` and `/notifications` still redirect to `/login?from=...`. Return paths are sanitized (`safeReturnPath`, like the web's `safeNext`).

**Google sign-in today (dev only).** There are no OAuth client IDs yet. With `GOOGLE_SERVER_CLIENT_ID` empty, non-release builds use `DevGoogleAuthService`, which sends the backend's dev token `dev-google|<sub>|dev-<sub>@example.test|مستخدم تجريبي` (the backend must run with `GOOGLE_DEV_MODE=true`, development only). The random `sub` is created once and kept in secure storage, so every tap is the same fake user, as in the web. The button is labelled "دخول تجريبي بـ Google". A **release build without a client ID shows no Google button at all**. Once real IDs exist, set `GOOGLE_SERVER_CLIENT_ID` (see the manual steps below) and the app switches to the real `google_sign_in` flow automatically; the dev service is never selected then. New Google users go through complete-profile (name prefilled + phone).

**Guest-data merge.** `GuestDataMerger` runs after every sign-in (skipped while a password change is pending, then run after it). It is a no-op until the cart/favorites phase adds device-held guest data and the real `/favorites/merge` + `/cart/merge` calls.

**Other.** `SUPPORT_PHONE` / `SUPPORT_WHATSAPP` (optional defines) add call/WhatsApp buttons to the "forgot password" dialog and the disabled-account message; empty hides them. Banner links of type `url` now open in the browser (https only).

## Cart and favorites (phase 3)

Mirrors lamsa-web: the same backend rules, as a native client. **Cart and Favorites are usable by guests**; only Account is gated.

**Guests (on the device).** The cart is only "what's in it": `(product_id, variant_id|0, quantity, slug)` lines, and favorites are product ids, in two small versioned JSON blobs in `shared_preferences` (same compact shape and limits as the web: 50 cart lines, quantity 1..99, 200 favorites; unreadable data decodes to empty). **Nothing about price, stock or availability is trusted on the device.** Every cart view and change goes through the public `POST /cart/preview`, which returns the cart as `GET /cart` would (live prices, per-line issues, per-currency totals). An add or quantity increase is saved only if the preview of the cart *with* the change has no issue on that line (`INSUFFICIENT_STOCK` with `available`, `OUT_OF_STOCK`, `QUANTITY_LIMIT_EXCEEDED` with `max`, `PRODUCT_NOT_FOUND`, `VARIANT_REQUIRED`...); decreasing and removing are always allowed. "تحديث السلة" applies the same fixes the backend applies to a stored cart (remove unavailable/out-of-stock lines, cap the others), read from the preview's issues. A guest heart-add checks the product is visible with one `GET /products?ids=` call.

**Signed in.** The real endpoints: `GET /cart`, `POST/PATCH/DELETE /cart/items`, `DELETE /cart`, `POST /cart/resolve-issues`; `GET /favorites`, `GET /favorites/ids`, `PUT/DELETE /favorites/{id}`, `POST /favorites/{id}/move-to-cart`. Every cart call returns the whole cart. `CartCubit` and `FavoritesCubit` switch mode with the session; changes are serialized so the last answer is the newest state.

**Merge on sign-in.** `CommerceMerger` (the real `GuestDataMerger`) runs after login, register, Google and complete-profile, and is skipped while a temporary password is pending (it runs after the password change). Favorites are merged first (`POST /favorites/merge`), then the cart (`POST /cart/merge`). The cart merge never fails because of one bad item: every line is reported `added`, `merged`, `capped` (stock or per-line limit) or `skipped` (not found, out of stock...), and the response is the whole cart. Local data is cleared only after both calls succeed. The shopper sees "أعدنا N منتجات إلى سلتك" (+ "عُدّلت بعض المنتجات وفقًا للمخزون المتوفر" if anything was capped or skipped); an empty merge shows nothing. A failed merge never blocks the sign-in: the local data stays and the merge is retried the next time the cart loads (opening the tab, next launch, next sign-in). Calls are single-flight.

**Cart screen.** Lines (image, name linking to the product, brand and variant label, unit price with the struck regular price, quantity stepper debounced 300 ms with optimistic update and rollback, per-line total in the line's own currency, remove), the backend's issue under a line, an "update my cart" banner, a summary with subtotal / savings / total as **one row per currency (SYP and USD are never added)**, clear-cart with confirmation, empty and error states. There is no stored price in the cart (prices are always live), so the only conflicts are the issues and notices the backend returns. The summary ends with the real "إتمام الطلب" button (enabled when the backend says `can_checkout`); a guest is sent to login and returns to checkout.

**Favorites screen.** Newest first, product cards with "انقل إلى السلة" (disabled "نفدت الكمية" for out-of-stock favorites, which stay listed) and remove. Signed in: 24 per page with infinite scroll; guests: all at once. It follows the hearts (a favorite added elsewhere refreshes it).

**Hearts and add-to-cart.** Hearts everywhere read the one favorites store (not the cards' `is_favorite`, so catalog calls stay anonymous and cacheable): every heart of a product agrees, taps are optimistic and roll back with the reason on failure. Add-to-cart on the product page has a quantity stepper (1..10, bounded by the backend's low-stock count), clamps on `INSUFFICIENT_STOCK`, and is genuinely disabled for sold-out items. The Cart and Favorites tab icons carry live count badges (99+ above 99), for guests (local data) and signed-in users (backend).

**Dev note.** The backend puts its own port in media URLs; `resolveMediaUrl` now rewrites loopback media URLs to the configured host *and port*.

## Checkout, orders and account (phase 4)

Everything below mirrors what lamsa-web does against the same backend; the backend decides, the app does not compute.

**Addresses** (Account > عناويني, and inline at checkout). `GET /governorates` (the 14 governorates, Arabic names from the backend) and `/users/me/addresses` (at most 10, the first one is the default; deleting the default hands it to the newest). The form has the web's limits (label 50, area 100, details 10..500, notes 500), a governorate select, "make default", and an **optional** map pin. The map is `flutter_map` over OpenStreetMap tiles (like the web; no Google Maps, no API key) with the required credit, tap to place or move the pin, "استخدم موقعي الحالي" (`geolocator`), "إزالة الموقع", points outside Syria refused (the backend checks the same box); it opens on the chosen governorate. Blank fields are sent as `null` so they clear a stored value. The backend's Arabic message wins for anything it rejects (`INVALID_LOCATION`, `ADDRESS_LIMIT_REACHED`...).

**Delivery methods and governorates.** There is no client-side Damascus-vs-provinces rule: `GET /cart?governorate=<code>` returns `delivery_quotes` valid for that governorate (today: Damascus gets the courier with a fee in SYP; every other governorate gets province shipping, whose fee is **paid to the carrier** on receipt, shown with that note and without a fee in the totals). Each quote carries its own per-currency `totals`. Picking another address asks the backend again. One valid method is preselected; with none, nothing can be confirmed. Payment is cash on delivery only.

**Placing the order.** `POST /orders` with `delivery_method_code`, `address_id`, notes, gift message and `expected_totals`, which is exactly the selected quote's totals map (`{SYP: "...", USD: "..."}`), never a sum. `201` = created, `200` = the same Idempotency-Key replayed (same order, nothing new). Failures: `CART_EMPTY` / `CART_HAS_ISSUES` back to the cart; `INSUFFICIENT_STOCK` back to the cart with "لم يتبقَّ سوى N"; `PRICE_CHANGED` stay, reload the totals, show a notice and require a new confirmation; `DELIVERY_METHOD_NOT_AVAILABLE/NOT_FOUND` reload the methods and clear the choice; `ADDRESS_*` / `INVALID_LOCATION` a notice with the address form right there; anything else shows the backend's message under the form (notes are kept).

**Idempotency, end to end.** Every checkout load starts an attempt (random UUID v4). The Idempotency-Key is the base64url SHA-256 (43 chars, the backend accepts 1..64 of `[A-Za-z0-9_-]`) of the attempt id plus the confirmed inputs: address, method, trimmed notes, gift message and the exact totals. So: a double tap or a second tap after an error is the same attempt with the same inputs and the same key (the backend replays); changing any input, or a refresh (new address, `PRICE_CHANGED`...), gives a new key. After `SERVICE_BUSY` (waiting `Retry-After`, at most 5 s), a timeout or a network error the request is retried **once with the same key**; if the first try did reach the server the backend answers `200` with that order and the customer never gets two. Placing is guarded against re-entry in the cubit.

**Orders** (Account > طلباتي, not a sixth tab: the bottom bar stays the five shopping tabs). History is newest first with the backend's `status_group` filter (الكل / قيد التنفيذ / مكتملة / ملغاة), infinite scroll, per-currency totals. Detail: timeline with times (Damascus time, fixed UTC+3), items (linked while the product is still visible), delivery method, the address snapshot (new and legacy shapes, "عرض على الخريطة" opens OpenStreetMap through url_launcher), notes, gift message, per-currency totals. **Cancel** is offered only when the backend says `can_cancel` (only while the order is pending), with a confirm dialog and an optional reason; if the store moved it on meanwhile, the backend's message is shown and the order refreshes. **Reorder** is the backend's `POST /orders/{id}/reorder` (available for any order): it merges into the cart with the cart rules and the app reports how many lines came back and whether anything was adjusted or skipped.

**Account.** The profile card stays; below it a menu: orders, addresses, profile (name, email: only changed fields are sent, a blank email clears it), phone (phone accounts confirm with their current password, Google accounts do not; **no SMS or code**, other sessions stay), password (voluntary change reuses the forced-change form; Google accounts have no store password), and "تسجيل الخروج من كل الأجهزة" with a confirm dialog (revokes every refresh token; the current access token, being stateless, lives until it expires, but the app drops it at once).

**Platform.** Android now declares `INTERNET` (a release build had no network at all before) plus location permissions; iOS has `NSLocationWhenInUseUsageDescription`. Neither the map nor geolocator has been run on a device.

**Deferred.** Notification preferences UI and the notifications screen, account deletion, admin features. Multi-address delivery splitting is not a backend feature.

## Auth and token storage (differs from the other two clients)

| Client | Where tokens live | Why |
|---|---|---|
| lamsa-web | Never in the browser: BFF with httpOnly `__Host-` cookies | XSS must not read tokens |
| lamsa-admin | JS memory only, re-login every launch | admin sessions should die with the tab |
| lamsa_app | OS secure storage (Keychain / Keystore) | consumers expect to stay logged in |

Backend contract: access token = 15 min JWT; refresh token = opaque, 60 days, single-use, rotated on every refresh; reusing a spent token returns `TOKEN_REUSED` and ends all sessions of that login. The interceptor (`lib/core/network/auth_interceptor.dart`):

- refreshes proactively 60 s before expiry and reactively on `401 TOKEN_EXPIRED`, then retries once;
- is single-flight: concurrent requests share one in-flight refresh (a second refresh with the same token would trigger reuse detection);
- persists the rotated pair before anything else can use the old one;
- on an unrecoverable failure (4xx on refresh, `TOKEN_REUSED`, `TOKEN_INVALID`) clears storage and tells `SessionCubit`, and the router sends the user to login;
- keeps the stored session on network or 5xx failures so offline launches stay signed in.

`must_change_password` (temporary password after an admin reset) routes to a forced change-password screen.

## Run the backend and the app together

1. Backend (`../lamsa-backend`, README there for first-time setup): `.\venv\Scripts\python.exe -m uvicorn app.main:app --no-proxy-headers --host 127.0.0.1 --port 8000`. Check `http://127.0.0.1:8000/health`.
2. App: `cp env/dev.example.json env/dev.json`, then `flutter pub get` and `flutter run --dart-define-from-file=env/dev.json`.

`API_BASE_URL` is the server origin without `/api/v1`. If it is empty the app uses `http://10.0.2.2:8000` on Android (emulator to host machine) and `http://127.0.0.1:8000` elsewhere. On a physical phone set it to your computer's LAN address (and start uvicorn with `--host 0.0.0.0`). In dev the backend may return media URLs on `localhost`; the app rewrites those to the configured host.

## Config

Compile-time via `--dart-define-from-file` (no runtime dotenv package, no secrets in app assets). `env/*.json` is git-ignored; `env/dev.example.json` is committed.

| Variable | Meaning |
|---|---|
| `API_BASE_URL` | backend origin, e.g. `http://127.0.0.1:8000` |
| `GOOGLE_SERVER_CLIENT_ID` | web OAuth client ID used as `serverClientId`. Empty: dev-mode fake Google in non-release builds, no Google in release |
| `SUPPORT_PHONE`, `SUPPORT_WHATSAPP` | optional store contact for "forgot password" (empty hides the buttons) |

Firebase settings come from `google-services.json` / `GoogleService-Info.plist`, not from env.

## API types and drift

The backend publishes no schema file, only a live `/openapi.json`. Instead of a generator (retrofit, openapi-generator which needs Java), models are hand-written with `json_serializable` and each feature has a small typed API class. Money stays a string plus currency, the refresh flow is custom, and only part of the API is used, so generated code would need hand-tuning anyway. Drift is caught by `dart run tool/check_openapi.dart [origin]`: it diffs the live schema against `tool/openapi.snapshot.json` and exits 1 on any added, removed or changed path or schema. After reviewing and updating models, run it with `--update`. Regenerate model code with `dart run build_runner build --delete-conflicting-outputs`.

## Checks

```
flutter analyze
flutter test
```

## Manual steps still required

Push and Google sign-in are inert until these are done. The app boots and works without them. No placeholder config files are committed on purpose.

Firebase console (project `lamsa-c3e53`):
- [ ] Add an Android app with package `com.lamsa.app`; add your debug and release SHA-1/SHA-256; download `google-services.json` into `android/app/`.
- [ ] Add an iOS app with bundle ID `com.lamsa.app`; download `GoogleService-Info.plist` into `ios/Runner/` (needs Xcode on a Mac).
- [ ] iOS: upload an APNs auth key in Project settings, Cloud Messaging; enable the Push Notifications and Background Modes (remote notifications) capabilities in Xcode.
- [ ] Android: apply the Google services Gradle plugin (`com.google.gms.google-services`) in `android/settings.gradle.kts` and `android/app/build.gradle.kts` once `google-services.json` exists. Not added yet because the build fails without the file. Android 13+ also needs the `POST_NOTIFICATIONS` permission in the manifest, and the `orders` (high importance) and `marketing` notification channels still have to be created.
- [ ] Optional later: a top-level background message handler, and moving to Firebase Installation IDs together with the backend's `token=` to `fid=` change (the app registers classic FCM tokens today).

Google OAuth (Google Cloud console, same project):
- [ ] Create an Android OAuth client (package `com.lamsa.app` plus SHA-1) and an iOS OAuth client (bundle ID `com.lamsa.app`).
- [ ] Use or create a Web OAuth client; put its ID in `env/dev.json` as `GOOGLE_SERVER_CLIENT_ID`.
- [ ] iOS: add the iOS client ID and reversed client ID URL scheme to `Info.plist`.
- [ ] Add every client ID (web, Android, iOS) to the backend's `GOOGLE_CLIENT_IDS`. For local testing the backend's `GOOGLE_DEV_MODE=true` accepts fake tokens.

Other:
- [ ] Release signing for Android (`key.properties`, keystore; both are git-ignored). The release build type still signs with the debug key.
- [ ] Nothing has been run on a device or emulator yet; do a first run on your phone.
