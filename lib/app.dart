import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/network/api_client.dart';
import 'package:lamsa_app/core/router/app_router.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/storage/token_storage.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/app_theme.dart';
import 'package:lamsa_app/core/widgets/app_messenger.dart';
import 'package:lamsa_app/features/account/data/addresses_api.dart';
import 'package:lamsa_app/features/account/data/addresses_repository.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/auth/data/auth_api.dart';
import 'package:lamsa_app/features/auth/data/google_auth_service.dart';
import 'package:lamsa_app/features/cart/cubit/cart_cubit.dart';
import 'package:lamsa_app/features/cart/data/cart_api.dart';
import 'package:lamsa_app/features/cart/data/guest_merge.dart';
import 'package:lamsa_app/features/cart/data/guest_store.dart';
import 'package:lamsa_app/features/catalog/data/catalog_api.dart';
import 'package:lamsa_app/features/catalog/data/catalog_repository.dart';
import 'package:lamsa_app/features/favorites/cubit/favorites_cubit.dart';
import 'package:lamsa_app/features/favorites/presentation/favorites_screen.dart';
import 'package:lamsa_app/features/notifications/data/devices_api.dart';
import 'package:lamsa_app/features/notifications/data/push_service.dart';
import 'package:lamsa_app/features/orders/data/orders_api.dart';

/// Everything the widget tree needs, built once at startup (and replaceable
/// with fakes in tests).
final class AppDependencies {
  AppDependencies({
    required this.session,
    required this.authApi,
    required this.catalog,
    required this.devicesApi,
    required this.push,
    required this.google,
    required this.cart,
    required this.favorites,
    required this.favoritesDeps,
    required this.cartApi,
    required this.ordersApi,
    required this.addresses,
  }) : router = buildRouter(session);

  /// Production wiring. The Dio/session/auth-API cycle is broken with lazy
  /// closures: the interceptor refreshes via [AuthApi] and reports a dead
  /// session to [SessionCubit].
  factory AppDependencies.create() {
    final storage = SecureTokenStorage();
    late final SessionCubit session;
    late final AuthApi authApi;
    final dio = buildDio(
      storage: storage,
      refresh: (token) => authApi.refresh(token),
      onSessionExpired: () async => session.expire(),
      onPasswordChangeRequired: () => session.passwordChangeRequired(),
    );
    authApi = AuthApi(dio);
    final devicesApi = DevicesApi(dio);
    final push = PushService(devicesApi);
    final google = createGoogleAuthService();
    final catalogApi = CatalogApi(dio);
    final catalog = CatalogRepository(catalogApi);
    final cartApi = CartApi(dio);
    final store = SharedPrefsGuestStore();
    late final AppDependencies deps;
    final mergeService = GuestMergeService(cartApi, store);
    void mergeToast(MergeOutcome o) => showMergeToast(o, () => deps.router.go(Routes.cart));
    late final CartCubit cart;
    late final FavoritesCubit favorites;
    final ordersApi = OrdersApi(dio);
    final addresses = AddressesRepository(AddressesApi(dio));
    // The real guest-data merger (phase 3): merges, tells the shopper, then
    // switches the cart and favorites to the backend.
    final merger = CommerceMerger(
      mergeService,
      onMerged: mergeToast,
      onSignedIn: (outcome) async {
        final merged = outcome?.cart;
        if (merged != null) {
          cart.setServerCart(merged);
        } else {
          await cart.load(refresh: true);
        }
        await favorites.load();
      },
    );
    session = SessionCubit(
      api: authApi,
      storage: storage,
      push: push,
      merger: merger,
      // After a sign-out: forget the Google account and any cached catalog data.
      onSignedOut: () async {
        await google.signOut();
        catalog.clear();
        addresses.clear();
      },
    );
    cart = CartCubit(
      api: cartApi,
      store: store,
      session: session,
      merge: mergeService,
      onMerged: mergeToast,
    );
    favorites = FavoritesCubit(
      api: cartApi,
      store: store,
      session: session,
      cart: cart,
      lookup: catalogApi.productsByIds,
      detail: catalogApi.product,
    );
    deps = AppDependencies(
      session: session,
      authApi: authApi,
      catalog: catalog,
      devicesApi: devicesApi,
      push: push,
      google: google,
      cart: cart,
      favorites: favorites,
      favoritesDeps: FavoritesDeps.of(catalogApi, cartApi, store),
      cartApi: cartApi,
      ordersApi: ordersApi,
      addresses: addresses,
    );
    return deps;
  }

  final SessionCubit session;
  final AuthApi authApi;
  final CatalogRepository catalog;
  final DevicesApi devicesApi;
  final PushService push;
  final GoogleAuthService google;
  final CartCubit cart;
  final FavoritesCubit favorites;
  final FavoritesDeps favoritesDeps;
  final CartApi cartApi;
  final OrdersApi ordersApi;
  final AddressesRepository addresses;
  final GoRouter router;
}

class LamsaApp extends StatelessWidget {
  const LamsaApp({required this.deps, super.key});

  final AppDependencies deps;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: deps.authApi),
        RepositoryProvider.value(value: deps.catalog),
        RepositoryProvider.value(value: deps.devicesApi),
        RepositoryProvider.value(value: deps.push),
        RepositoryProvider.value(value: deps.google),
        RepositoryProvider.value(value: deps.favoritesDeps),
        RepositoryProvider.value(value: deps.cartApi),
        RepositoryProvider.value(value: deps.ordersApi),
        RepositoryProvider.value(value: deps.addresses),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: deps.session),
          BlocProvider.value(value: deps.cart),
          BlocProvider.value(value: deps.favorites),
        ],
        child: MaterialApp.router(
          scaffoldMessengerKey: rootMessengerKey,
          title: Strings.appName,
          routerConfig: deps.router,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          // Arabic only: fixed locale, RTL forced everywhere. The delegates
          // exist solely so built-in widgets render correct Arabic text.
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// The toast after a guest-data merge (same wording as lamsa-web): how many
/// products came back, and whether anything had to be adjusted. Nothing for an
/// empty merge.
void showMergeToast(MergeOutcome o, VoidCallback openCart) {
  if (o.restored == 0 && !o.adjusted) return;
  showToast(
    o.restored > 0 ? Strings.toastMerged(o.restored) : Strings.toastMergedAdjusted,
    sub: o.restored > 0 && o.adjusted ? Strings.toastMergedAdjusted : null,
    actionLabel: Strings.toastCartAction,
    onAction: openCart,
  );
}
