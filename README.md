# لمسة (lamsa_app)

Customer mobile app for the Lamsa beauty store (Flutter, Android and iOS). Arabic only, RTL, light/dark following the system. Customer-facing only: nothing admin.

Status: project structure and plumbing, plus **phase 1: catalog browsing** (home, categories, brands, new, sale, search, product detail) reading real data from the backend, all public/guest. Cart, favorites, account, auth screens, orders and notifications are still placeholders.

## Stack

| Concern | Choice |
|---|---|
| State | `flutter_bloc` (Cubit for screen state, Bloc only where event logic earns it) |
| Routing | `go_router` with an auth guard (`lib/core/router/auth_guard.dart`) |
| Networking | `dio`, hand-written typed API classes, `json_serializable` models |
| Session | `flutter_secure_storage` plus a refresh-rotation interceptor |
| Images | `cached_network_image` plus a size picker for the backend's WebP sizes |
| Push | `firebase_core`, `firebase_messaging` (Firebase project `lamsa-c3e53`) |
| Google sign-in | `google_sign_in` 7.x, drop-in once OAuth clients exist |
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
    auth/                session cubit, auth API, Google service, empty form cubits, placeholder screens
    shell/               bottom-nav frame (MainShell) and the "coming soon" tab body
    catalog/             data/ (models, API, repository cache, filters, variant rules), cubit/, presentation/
    cart/ favorites/ orders/ account/   placeholder screens (cart/favorites/account show "coming soon" in the shell)
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
- Heart and add-to-cart are visible and show a "قريبًا" snackbar (add-to-cart is genuinely disabled for sold-out products).
- Favorites, Cart and Account tabs show "قريبًا" inside the shell, and `Routes.protectedPrefixes` temporarily excludes them from the auth guard so guests are not bounced to login. Both are marked `TODO(catalog phase 1)`; restore the guard when those features are built.
- Banner links of type `url` are not tappable (needs `url_launcher`); in-app link types work.
- The web's shipping/pickup/cash "perks" block is checkout-related and left out.
- No search history, live (as-you-type) search, or full-screen image zoom.

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
| `GOOGLE_SERVER_CLIENT_ID` | web OAuth client ID used as `serverClientId` (empty disables Google sign-in) |

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
