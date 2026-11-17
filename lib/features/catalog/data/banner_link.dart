import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';

/// In-app route a banner leads to, or null when it is not tappable.
///
/// Mirrors lamsa-web's `linkTarget`. `url` links (and unknown or incomplete
/// ones) are not tappable yet: opening external links needs a url_launcher
/// dependency that is deferred.
String? bannerRoute(BannerLink link) {
  final value = link.value?.trim();
  final hasValue = value != null && value.isNotEmpty;
  return switch (link.type) {
    'category' when hasValue => Routes.categoryPath(value),
    'product' when hasValue => Routes.productPath(value),
    'brand' when hasValue => Routes.brandPath(value),
    'new' => Routes.newArrivals,
    'sale' => Routes.sale,
    _ => null,
  };
}

/// CTA pill text key: sale, new, or the default.
enum BannerCta { sale, newArrivals, discover }

BannerCta bannerCta(BannerLink link) => switch (link.type) {
      'sale' => BannerCta.sale,
      'new' => BannerCta.newArrivals,
      _ => BannerCta.discover,
    };
