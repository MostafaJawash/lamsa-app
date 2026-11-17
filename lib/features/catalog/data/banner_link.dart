import 'package:lamsa_app/core/platform/external_links.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';

/// In-app route a banner leads to, or null when it has none (see [bannerUrl]
/// for external links). Mirrors lamsa-web's `linkTarget`; unknown or
/// incomplete links are not tappable.
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

/// External `https` link of a `url` banner, opened outside the app. Anything
/// that is not https is ignored (same rule as lamsa-web).
Uri? bannerUrl(BannerLink link) {
  if (link.type != 'url' || !ExternalLinks.isSafeWebLink(link.value)) {
    return null;
  }
  return Uri.parse(link.value!.trim());
}

/// CTA pill text key: sale, new, or the default.
enum BannerCta { sale, newArrivals, discover }

BannerCta bannerCta(BannerLink link) => switch (link.type) {
  'sale' => BannerCta.sale,
  'new' => BannerCta.newArrivals,
  _ => BannerCta.discover,
};
