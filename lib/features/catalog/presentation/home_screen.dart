import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/core/theme/theme_cubit.dart';
import 'package:lamsa_app/core/widgets/connection_error_view.dart';
import 'package:lamsa_app/features/catalog/cubit/home_cubit.dart';
import 'package:lamsa_app/features/catalog/cubit/load_status.dart';
import 'package:lamsa_app/features/catalog/cubit/product_list_cubit.dart';
import 'package:lamsa_app/features/catalog/data/catalog_repository.dart';
import 'package:lamsa_app/features/catalog/data/list_filters.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';
import 'package:lamsa_app/features/catalog/presentation/widgets/banners_carousel.dart';
import 'package:lamsa_app/features/catalog/presentation/widgets/catalog_art.dart';
import 'package:lamsa_app/features/catalog/presentation/widgets/catalog_bits.dart';
import 'package:lamsa_app/features/catalog/presentation/widgets/product_list_body.dart';
import 'package:lamsa_app/features/catalog/presentation/widgets/sections.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              HomeCubit(context.read<CatalogRepository>())..load(),
        ),
        BlocProvider(
          create: (context) =>
              GiftsLabelCubit(context.read<CatalogRepository>())..load(),
        ),
      ],
      child: const HomeView(),
    );
  }
}

/// Home: a top tab bar (not the bottom nav) with three independent tabs —
/// the classic home, the gift-boxes category and every product. Each tab owns
/// its cubit, created when the tab is first shown, so one failing never
/// affects the others.
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: Spacing.pageGutter,
          title: const SearchPill(),
          actions: [
            BlocBuilder<ThemeCubit, ThemeMode>(
              builder: (context, mode) => IconButton(
                tooltip: Strings.darkMode,
                icon: Icon(
                  mode == ThemeMode.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
                onPressed: () =>
                    context.read<ThemeCubit>().setDark(mode != ThemeMode.dark),
              ),
            ),
          ],
          bottom: TabBar(
            tabs: [
              const Tab(text: Strings.homeTabMain),
              BlocBuilder<GiftsLabelCubit, String?>(
                builder: (context, name) =>
                    Tab(text: name ?? Strings.homeTabGifts),
              ),
              const Tab(text: Strings.homeTabAll),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _KeepAlive(child: _MainTab()),
            _KeepAlive(child: _GiftsTab()),
            _KeepAlive(child: _AllProductsTab()),
          ],
        ),
      ),
    );
  }
}

class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _GiftsTab extends StatelessWidget {
  const _GiftsTab();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProductListCubit(
        context.read<CatalogRepository>(),
        const CategoryScope(giftsCategorySlug),
      )..load(),
      child: const ProductListBody(
        emptyMessage: Strings.giftsUnavailable,
        notFoundMessage: Strings.giftsUnavailable,
      ),
    );
  }
}

class _AllProductsTab extends StatelessWidget {
  const _AllProductsTab();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProductListCubit(
        context.read<CatalogRepository>(),
        const AllProductsScope(),
      )..load(),
      child: const ProductListBody(emptyMessage: Strings.emptyAllProducts),
    );
  }
}

/// Today's home: banners, new rail, category tiles, sale rail, brands. Same
/// sections and order as lamsa-web. Each section degrades on its own.
class _MainTab extends StatelessWidget {
  const _MainTab();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context.read<HomeCubit>().load(refresh: true),
      child: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          if (state.allConnectionFailed) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: 420,
                  child: ConnectionErrorView(
                    onRetry: () => context.read<HomeCubit>().load(),
                  ),
                ),
              ],
            );
          }
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(
              top: Spacing.md,
              bottom: Spacing.xxl,
            ),
            children: [
              _Banners(state.banners),
              _NewRail(state.newArrivals),
              _Categories(state.categories),
              _SaleRail(state.onSale),
              _BrandsRow(state.brands),
            ],
          );
        },
      ),
    );
  }
}

class _Banners extends StatelessWidget {
  const _Banners(this.section);

  final Section<List<HomeBanner>> section;

  @override
  Widget build(BuildContext context) {
    if (section.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: Spacing.pageGutter),
        child: SkeletonBox(height: BannersCarousel.height, radius: Radii.xl),
      );
    }
    // Failed or empty: the two built-in banners, like lamsa-web.
    return BannersCarousel(banners: section.data);
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.section,
    required this.title,
    required this.emptyMessage,
    required this.seeAllRoute,
  });

  final Section<List<ProductCard>> section;
  final String title;
  final String emptyMessage;
  final String seeAllRoute;

  @override
  Widget build(BuildContext context) {
    final items = section.data ?? const <ProductCard>[];
    final hasItems = section.status == LoadStatus.loaded && items.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          moreLabel: Strings.seeAll,
          onMore: hasItems ? () => context.push(seeAllRoute) : null,
        ),
        if (section.isLoading)
          const RailSkeleton()
        else if (hasItems)
          ProductRail(products: items)
        else
          SectionMessage(emptyMessage),
      ],
    );
  }
}

class _NewRail extends StatelessWidget {
  const _NewRail(this.section);

  final Section<List<ProductCard>> section;

  @override
  Widget build(BuildContext context) => _Rail(
    section: section,
    title: Strings.homeNewArrivals,
    emptyMessage: Strings.homeEmptyNew,
    seeAllRoute: Routes.newArrivals,
  );
}

class _SaleRail extends StatelessWidget {
  const _SaleRail(this.section);

  final Section<List<ProductCard>> section;

  @override
  Widget build(BuildContext context) => _Rail(
    section: section,
    title: Strings.homeOnSale,
    emptyMessage: Strings.homeEmptySale,
    seeAllRoute: Routes.sale,
  );
}

class _Categories extends StatelessWidget {
  const _Categories(this.section);

  final Section<List<CategoryTile>> section;

  @override
  Widget build(BuildContext context) {
    final tiles = section.data ?? const <CategoryTile>[];
    // Hidden when empty or failed, like lamsa-web.
    if (!section.isLoading && tiles.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: Strings.homeByCategory),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.pageGutter),
          child: section.isLoading
              ? const SkeletonBox(height: 160)
              : GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: Spacing.md,
                  crossAxisSpacing: Spacing.md,
                  childAspectRatio: .95,
                  children: [for (final t in tiles) CategoryTileView(tile: t)],
                ),
        ),
      ],
    );
  }
}

class _BrandsRow extends StatelessWidget {
  const _BrandsRow(this.section);

  final Section<List<Brand>> section;

  @override
  Widget build(BuildContext context) {
    final brands = section.data ?? const <Brand>[];
    if (!section.isLoading && brands.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: Strings.homeBrands,
          moreLabel: Strings.allBrands,
          onMore: () => context.push(Routes.brands),
        ),
        SizedBox(
          height: 96,
          child: section.isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: Spacing.pageGutter),
                  child: SkeletonBox(),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.pageGutter,
                  ),
                  itemCount: brands.length,
                  separatorBuilder: (_, _) => const SizedBox(width: Spacing.lg),
                  itemBuilder: (context, i) {
                    final b = brands[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(Radii.lg),
                      onTap: () => context.push(Routes.brandPath(b.slug)),
                      child: SizedBox(
                        width: 72,
                        child: Column(
                          children: [
                            BrandLogo(id: b.id, name: b.name, logo: b.logo),
                            const SizedBox(height: Spacing.xs),
                            Text(
                              b.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
