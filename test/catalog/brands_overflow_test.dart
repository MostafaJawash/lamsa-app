import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/features/catalog/data/catalog_repository.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';
import 'package:lamsa_app/features/catalog/presentation/categories_screen.dart';

import 'catalog_fakes.dart';

/// Brand names from the demo seed (lamsa-backend/scripts/seed_demo_catalog.py)
/// plus a long real-world style Arabic name and the store's own brand, which
/// carries an extra "علامتنا" line.
const _brands = [
  Brand(id: 1, name: 'لُمى', slug: 'luma', productCount: 12),
  Brand(id: 2, name: 'مِسك', slug: 'misk', productCount: 5),
  Brand(
    id: 3,
    name: 'مستحضرات الورد الدمشقي الفاخرة للعناية بالبشرة والجمال',
    slug: 'long',
    productCount: 128,
  ),
  Brand(id: 7, name: 'بيتي', slug: 'baity', productCount: 9, isOwnBrand: true),
  Brand(
    id: 8,
    name: 'مستحضرات التجميل العضوية الطبيعية الراقية',
    slug: 'long-own',
    productCount: 2,
    isOwnBrand: true,
  ),
];

void main() {
  for (final (width, scale) in [(360.0, 1.0), (360.0, 1.5), (420.0, 2.0)]) {
    testWidgets('brands grid does not overflow at ${width}px x$scale',
        (tester) async {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = FakeCatalogApi()..brandsData = _brands;
      await pumpCatalog(
        tester,
        MediaQuery(
          data: MediaQueryData(
            size: Size(width, 1600),
            textScaler: TextScaler.linear(scale),
          ),
          child: const BrandsScreen(),
        ),
        CatalogRepository(api),
      );
      await tester.pumpAndSettle();

      expect(find.text('لُمى'), findsOneWidget);
      // A RenderFlex overflow is reported as a framework exception.
      expect(tester.takeException(), isNull);
    });
  }
}
