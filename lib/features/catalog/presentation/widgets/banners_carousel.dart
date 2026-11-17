import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/images/image_urls.dart';
import 'package:lamsa_app/core/platform/external_links.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/features/catalog/data/banner_link.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';
import 'package:lamsa_app/features/catalog/presentation/widgets/catalog_art.dart';

const _saleTone = Color(0xFFB8174E);
const _newTone = Color(0xFF2D1B2E);

String _ctaLabel(BannerCta cta) => switch (cta) {
  BannerCta.sale => Strings.bannerCtaSale,
  BannerCta.newArrivals => Strings.bannerCtaNew,
  BannerCta.discover => Strings.bannerCtaDefault,
};

class _BannerTile extends StatelessWidget {
  const _BannerTile({
    required this.title,
    required this.background,
    this.subtitle,
    this.cta,
    this.image,
    this.icon,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? cta;
  final ImageUrls? image;

  /// Drawn in place of an image (the built-in fallback banners).
  final IconData? icon;
  final Color background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(Radii.xl),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.titleLarge!.copyWith(color: Colors.white),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodySmall!.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                      if (cta != null) ...[
                        const SizedBox(height: Spacing.md),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.md,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            cta!,
                            style: theme.labelMedium!.copyWith(
                              color: background,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.md),
                SizedBox(
                  width: 110,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.lg),
                    child: icon != null
                        ? Center(
                            child: Icon(icon, size: 64, color: Colors.white54),
                          )
                        : CatalogImage(
                            urls: image,
                            fit: BoxFit.contain,
                            fallback: const Center(
                              child: Icon(
                                Icons.spa_outlined,
                                size: 56,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Home banners: the backend's (swipeable), or the two built-in sale/new
/// banners when there are none or they could not be loaded.
class BannersCarousel extends StatefulWidget {
  const BannersCarousel({required this.banners, super.key});

  /// `null` or empty: show the built-in fallback pair.
  final List<HomeBanner>? banners;

  static const height = 168.0;

  @override
  State<BannersCarousel> createState() => _BannersCarouselState();
}

class _BannersCarouselState extends State<BannersCarousel> {
  final _controller = PageController(viewportFraction: .92);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Widget> _tiles(BuildContext context) {
    final banners = widget.banners;
    if (banners == null || banners.isEmpty) {
      return [
        _BannerTile(
          title: Strings.bannerSaleTitle,
          subtitle: Strings.bannerSaleSubtitle,
          cta: Strings.bannerCtaSale,
          background: _saleTone,
          icon: Icons.local_offer_outlined,
          onTap: () => context.push(Routes.sale),
        ),
        _BannerTile(
          title: Strings.bannerNewTitle,
          subtitle: Strings.bannerNewSubtitle,
          cta: Strings.bannerCtaNew,
          background: _newTone,
          icon: Icons.auto_awesome_outlined,
          onTap: () => context.push(Routes.newArrivals),
        ),
      ];
    }
    return [
      for (final (i, b) in banners.indexed)
        () {
          final route = bannerRoute(b.link);
          final url = bannerUrl(b.link);
          return _BannerTile(
            title: b.title,
            subtitle: b.subtitle,
            image: b.image,
            cta: route == null && url == null
                ? null
                : _ctaLabel(bannerCta(b.link)),
            background: i.isEven ? _saleTone : _newTone,
            onTap: route != null
                ? () => context.push(route)
                : url != null
                ? () => ExternalLinks.open(url)
                : null,
          );
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tiles = _tiles(context);
    return Column(
      children: [
        SizedBox(
          height: BannersCarousel.height,
          child: PageView(
            controller: _controller,
            onPageChanged: (p) => setState(() => _page = p),
            children: tiles,
          ),
        ),
        if (tiles.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < tiles.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
