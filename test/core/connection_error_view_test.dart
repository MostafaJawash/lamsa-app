import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/app_theme.dart';
import 'package:lamsa_app/core/widgets/connection_error_view.dart';
import 'package:lamsa_app/features/catalog/data/catalog_repository.dart';
import 'package:lamsa_app/features/catalog/data/list_filters.dart';
import 'package:lamsa_app/features/catalog/presentation/categories_screen.dart';
import 'package:lamsa_app/features/catalog/presentation/product_list_screen.dart';

import '../catalog/catalog_fakes.dart';

const _offline = ApiError(code: ApiError.networkCode, backendMessage: null);
const _serverDown =
    ApiError(code: 'INTERNAL_ERROR', backendMessage: null, status: 500);

Future<void> _pumpView(
  WidgetTester tester, {
  required bool online,
  required VoidCallback onRetry,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      builder: (context, c) =>
          Directionality(textDirection: TextDirection.rtl, child: c!),
      home: Scaffold(
        body: ConnectionErrorView(probe: () async => online, onRetry: onRetry),
      ),
    ),
  );
}

void main() {
  late ConnectivityProbe saved;
  setUp(() => saved = connectivityProbe);
  tearDown(() => connectivityProbe = saved);

  group('ConnectionErrorView', () {
    testWidgets('no network at all says so', (tester) async {
      await _pumpView(tester, online: false, onRetry: () {});
      await tester.pumpAndSettle();
      expect(find.text(Strings.noInternetTitle), findsOneWidget);
      expect(find.text(Strings.serverUnreachableTitle), findsNothing);
    });

    testWidgets('online but backend unreachable says that instead',
        (tester) async {
      await _pumpView(tester, online: true, onRetry: () {});
      await tester.pumpAndSettle();
      expect(find.text(Strings.serverUnreachableTitle), findsOneWidget);
      expect(find.text(Strings.noInternetTitle), findsNothing);
    });

    testWidgets('retry calls back', (tester) async {
      var retries = 0;
      await _pumpView(tester, online: false, onRetry: () => retries++);
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.retry));
      await tester.pumpAndSettle();
      expect(retries, 1);
    });
  });

  group('connection failure classification', () {
    test('only unreachable-backend codes count', () {
      expect(isConnectionFailure(_offline), isTrue);
      expect(
        isConnectionFailure(
          const ApiError(code: ApiError.timeoutCode, backendMessage: null),
        ),
        isTrue,
      );
      expect(isConnectionFailure(_serverDown), isFalse);
      expect(isConnectionFailure(StateError('x')), isFalse);
    });
  });

  group('reused by screens', () {
    late FakeCatalogApi api;
    late CatalogRepository repo;
    setUp(() {
      api = FakeCatalogApi();
      repo = CatalogRepository(api);
      connectivityProbe = () async => false;
    });

    testWidgets('product list: connection failure shows it, retry reloads',
        (tester) async {
      api.errorFor = (name, _) => name == 'products' ? _offline : null;
      await pumpCatalog(
        tester,
        const ProductListScreen(scope: CategoryScope('care')),
        repo,
      );
      await tester.pumpAndSettle();
      expect(find.text(Strings.noInternetTitle), findsOneWidget);

      api.errorFor = null;
      api.productsHandler = (_) => page([card(1, name: 'عاد المنتج')]);
      await tester.tap(find.text(Strings.retry));
      await tester.pumpAndSettle();
      expect(find.text('عاد المنتج'), findsOneWidget);
      expect(find.text(Strings.noInternetTitle), findsNothing);
    });

    testWidgets('product list: a 500 stays the generic error', (tester) async {
      api.errorFor = (name, _) => name == 'products' ? _serverDown : null;
      await pumpCatalog(
        tester,
        const ProductListScreen(scope: CategoryScope('care')),
        repo,
      );
      await tester.pumpAndSettle();
      expect(find.text(Strings.noInternetTitle), findsNothing);
      expect(find.text(Strings.serverUnreachableTitle), findsNothing);
      expect(find.text(Strings.retry), findsOneWidget);
    });

    testWidgets('categories screen shows it too', (tester) async {
      api.errorFor = (name, _) => name == 'categories' ? _offline : null;
      await pumpCatalog(tester, const CategoriesScreen(), repo);
      await tester.pumpAndSettle();
      expect(find.text(Strings.noInternetTitle), findsOneWidget);
    });
  });
}
