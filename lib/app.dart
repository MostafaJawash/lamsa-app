import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/network/api_client.dart';
import 'package:lamsa_app/core/router/app_router.dart';
import 'package:lamsa_app/core/storage/token_storage.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/app_theme.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/auth/data/auth_api.dart';
import 'package:lamsa_app/features/auth/data/google_auth_service.dart';
import 'package:lamsa_app/features/catalog/data/catalog_api.dart';
import 'package:lamsa_app/features/notifications/data/devices_api.dart';
import 'package:lamsa_app/features/notifications/data/push_service.dart';

/// Everything the widget tree needs, built once at startup (and replaceable
/// with fakes in tests).
final class AppDependencies {
  AppDependencies({
    required this.session,
    required this.authApi,
    required this.catalogApi,
    required this.devicesApi,
    required this.push,
    required this.google,
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
    );
    authApi = AuthApi(dio);
    final devicesApi = DevicesApi(dio);
    final push = PushService(devicesApi);
    session = SessionCubit(api: authApi, storage: storage, push: push);
    return AppDependencies(
      session: session,
      authApi: authApi,
      catalogApi: CatalogApi(dio),
      devicesApi: devicesApi,
      push: push,
      google: GoogleSignInAuthService(),
    );
  }

  final SessionCubit session;
  final AuthApi authApi;
  final CatalogApi catalogApi;
  final DevicesApi devicesApi;
  final PushService push;
  final GoogleAuthService google;
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
        RepositoryProvider.value(value: deps.catalogApi),
        RepositoryProvider.value(value: deps.devicesApi),
        RepositoryProvider.value(value: deps.push),
        RepositoryProvider.value(value: deps.google),
      ],
      child: BlocProvider.value(
        value: deps.session,
        child: MaterialApp.router(
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
