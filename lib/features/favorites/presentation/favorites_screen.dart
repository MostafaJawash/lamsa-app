import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/core/widgets/app_messenger.dart';
import 'package:lamsa_app/core/widgets/connection_error_view.dart';
import 'package:lamsa_app/core/widgets/state_views.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/cart/data/cart_api.dart';
import 'package:lamsa_app/features/cart/data/guest_store.dart';
import 'package:lamsa_app/features/catalog/data/catalog_api.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';
import 'package:lamsa_app/features/catalog/presentation/categories_screen.dart'
    show ScrollableMessage;
import 'package:lamsa_app/features/catalog/presentation/widgets/product_card_view.dart';
import 'package:lamsa_app/features/favorites/cubit/favorites_cubit.dart';
import 'package:lamsa_app/features/favorites/cubit/favorites_list_cubit.dart';

/// Where the favorites tab gets its collaborators from. Provided at the app
/// root (and replaceable in tests).
class FavoritesDeps {
  const FavoritesDeps({required this.api, required this.store, required this.lookup});

  final CartApi api;
  final GuestStore store;
  final Future<List<ProductCard>> Function(List<int> ids) lookup;

  static FavoritesDeps of(CatalogApi catalog, CartApi api, GuestStore store) =>
      FavoritesDeps(api: api, store: store, lookup: catalog.productsByIds);
}

/// Favorites tab, for guests (ids on the device) and signed-in users
/// (`GET /favorites`). Product cards with "انقل إلى السلة" and remove under
/// each, like lamsa-web. Out-of-stock favorites stay listed.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = context.read<FavoritesDeps>();
    return BlocProvider(
      create: (context) => FavoritesListCubit(
        api: deps.api,
        store: deps.store,
        session: context.read<SessionCubit>(),
        favorites: context.read<FavoritesCubit>(),
        lookup: deps.lookup,
      )..load(),
      child: const _FavoritesView(),
    );
  }
}

class _FavoritesView extends StatefulWidget {
  const _FavoritesView();

  @override
  State<_FavoritesView> createState() => _FavoritesViewState();
}

class _FavoritesViewState extends State<_FavoritesView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final p = _scroll.position;
      if (_scroll.hasClients && p.pixels >= p.maxScrollExtent - 600) {
        unawaited(context.read<FavoritesListCubit>().loadMore());
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _move(ProductCard product) async {
    final result = await context.read<FavoritesListCubit>().moveToCart(product);
    if (result.ok) {
      showToast(Strings.toastMoved);
    } else if (result.error != null) {
      showToast(result.error!.text);
    }
  }

  Future<void> _remove(ProductCard product) async {
    final result = await context.read<FavoritesListCubit>().remove(product);
    if (!result.ok && result.error != null) showToast(result.error!.text);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FavoritesListCubit>();
    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.favorites),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: () => cubit.load(refresh: true),
        child: BlocBuilder<FavoritesListCubit, FavoritesListState>(
          builder: (context, state) {
            if (state.status == FavoritesLoad.failed && state.items.isEmpty) {
              return ScrollableMessage(
                child: state.connection
                    ? ConnectionErrorView(onRetry: cubit.load)
                    : ErrorView(
                        message: Strings.favoritesUnavailable,
                        onRetry: cubit.load,
                      ),
              );
            }
            if (state.status == FavoritesLoad.loading && state.items.isEmpty) {
              return const LoadingView(message: Strings.loading);
            }
            if (state.items.isEmpty) {
              return const ScrollableMessage(child: _EmptyFavorites());
            }
            return CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _Header(total: state.total)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.pageGutter),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      const gap = Spacing.md;
                      final cell = (constraints.crossAxisExtent - gap) / 2;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: gap,
                          crossAxisSpacing: gap,
                          // card + the action row
                          mainAxisExtent: cell + 140 + 52,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          childCount: state.items.length,
                          (context, i) => _FavoriteItem(
                            key: ValueKey('fav-${state.items[i].id}'),
                            product: state.items[i],
                            onMove: () => _move(state.items[i]),
                            onRemove: () => _remove(state.items[i]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (state.loadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(Spacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: Spacing.xl)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final muted = theme.bodyMedium!.copyWith(color: context.lamsa.muted);
    return Padding(
      padding: const EdgeInsets.all(Spacing.pageGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(Strings.products(total), style: muted),
          Text(Strings.favoritesSub, style: muted),
        ],
      ),
    );
  }
}

class _FavoriteItem extends StatelessWidget {
  const _FavoriteItem({
    required this.product,
    required this.onMove,
    required this.onRemove,
    super.key,
  });

  final ProductCard product;
  final VoidCallback onMove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ProductCardView(
            product: product,
            onTap: () => context.push(Routes.productPath(product.slug)),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: EdgeInsets.zero,
                ),
                // Out of stock is real state: the move is genuinely disabled.
                onPressed: product.inStock ? onMove : null,
                child: Text(
                  product.inStock ? Strings.favoritesMoveToCart : Strings.productOut,
                ),
              ),
            ),
            IconButton(
              tooltip: '${Strings.favoritesRemove}: ${product.name}',
              icon: const Icon(Icons.close),
              onPressed: onRemove,
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border, size: 56, color: context.lamsa.muted),
            const SizedBox(height: Spacing.lg),
            Text(
              Strings.favoritesEmptyTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              Strings.favoritesEmptyText,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(color: context.lamsa.muted),
            ),
            const SizedBox(height: Spacing.xl),
            FilledButton(
              onPressed: () => context.push(Routes.newArrivals),
              child: const Text(Strings.favoritesBrowseNew),
            ),
          ],
        ),
      ),
    );
  }
}
