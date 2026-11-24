import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/core/widgets/connection_error_view.dart';
import 'package:lamsa_app/core/widgets/state_views.dart';
import 'package:lamsa_app/features/catalog/cubit/product_list_cubit.dart';
import 'package:lamsa_app/features/catalog/data/filter_chips.dart';
import 'package:lamsa_app/features/catalog/data/list_filters.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';
import 'package:lamsa_app/features/catalog/presentation/categories_screen.dart'
    show ScrollableMessage;
import 'package:lamsa_app/features/catalog/presentation/widgets/catalog_art.dart';
import 'package:lamsa_app/features/catalog/presentation/widgets/filter_sheet.dart';
import 'package:lamsa_app/features/catalog/presentation/widgets/product_card_view.dart';

/// Body shared by every product list (category, brand, new, sale, search):
/// header, chips, sort/filter controls, grid with infinite scroll, and the
/// loading / error / empty states. Reads a [ProductListCubit] from context.
class ProductListBody extends StatefulWidget {
  const ProductListBody({
    required this.emptyMessage,
    this.subtitle,
    this.subtitleOf,
    this.idle,
    this.notFoundMessage,
    super.key,
  });

  /// Shown when the list has no products and no filter is active.
  final String emptyMessage;

  /// Optional line under the count (e.g. "أحدث المنتجات التي وصلت.").
  final String? subtitle;

  /// Subtitle derived from the list state (search: "نتائج «q»").
  final String? Function(ProductListState state)? subtitleOf;

  /// Shown before anything was searched (search only).
  final Widget? idle;

  /// Overrides the scope's own "not found" copy (e.g. the home gifts tab,
  /// where a missing category simply means "no gift boxes yet").
  final String? notFoundMessage;

  @override
  State<ProductListBody> createState() => _ProductListBodyState();
}

class _ProductListBodyState extends State<ProductListBody> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.pixels >= p.maxScrollExtent - 600) {
      context.read<ProductListCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProductListCubit>();
    return BlocBuilder<ProductListCubit, ProductListState>(
      builder: (context, state) {
        switch (state.status) {
          case ListStatus.idle:
            return widget.idle ?? const SizedBox.shrink();
          case ListStatus.notFound:
            return EmptyView(
              message: widget.notFoundMessage ?? _notFoundMessage(cubit.scope),
            );
          case ListStatus.failed:
            return RefreshIndicator(
              onRefresh: () => cubit.load(refresh: true),
              child: ScrollableMessage(
                child: state.connectionFailure
                    ? ConnectionErrorView(
                        onRetry: () => cubit.load(refresh: true),
                      )
                    : ErrorView(
                        message: state.error ?? Strings.errorGeneric,
                        onRetry: () => cubit.load(refresh: true),
                      ),
              ),
            );
          case ListStatus.loading when state.items.isEmpty:
            return const LoadingView(message: Strings.loading);
          case ListStatus.loading:
          case ListStatus.loaded:
            return RefreshIndicator(
              onRefresh: () => cubit.load(refresh: true),
              child: _content(context, state, cubit),
            );
        }
      },
    );
  }

  String _notFoundMessage(ListScope scope) => switch (scope) {
    CategoryScope() => Strings.categoryNotFound,
    BrandScope() => Strings.brandNotFound,
    _ => Strings.errorGeneric,
  };

  Widget _content(
    BuildContext context,
    ProductListState state,
    ProductListCubit cubit,
  ) {
    final scope = cubit.scope;
    final chips = filterChips(state.filters, state.facets);
    final reloading = state.status == ListStatus.loading;
    return CustomScrollView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (reloading)
          const SliverToBoxAdapter(
            child: LinearProgressIndicator(minHeight: 2),
          ),
        SliverToBoxAdapter(
          child: _Header(
            state: state,
            subtitle: widget.subtitleOf?.call(state) ?? widget.subtitle,
          ),
        ),
        SliverToBoxAdapter(
          child: _ChipsRow(state: state, cubit: cubit),
        ),
        SliverToBoxAdapter(
          child: _Controls(state: state, cubit: cubit),
        ),
        if (chips.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.pageGutter,
              ),
              child: Wrap(
                spacing: Spacing.sm,
                children: [
                  for (final chip in chips)
                    InputChip(
                      label: Text(chip.label),
                      tooltip: Strings.removeFilter(chip.label),
                      onDeleted: () => cubit.setFilters(
                        state.filters.without(chip.remove, scope),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (state.ignored.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.pageGutter),
              child: Text(
                Strings.invalidFilters,
                style: Theme.of(context).textTheme.bodySmall!
                    .copyWith(color: context.lamsa.warn),
              ),
            ),
          ),
        if (state.items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _Empty(
              state: state,
              scope: scope,
              emptyMessage: widget.emptyMessage,
              onClear: () => cubit.setFilters(state.filters.cleared(scope)),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(Spacing.pageGutter),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                const gap = Spacing.md;
                final cell = (constraints.crossAxisExtent - gap) / 2;
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: gap,
                    crossAxisSpacing: gap,
                    mainAxisExtent: cell + 140,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    childCount: state.items.length,
                    (context, i) => ProductCardView(
                      product: state.items[i],
                      onTap: () =>
                          context.push(Routes.productPath(state.items[i].slug)),
                    ),
                  ),
                );
              },
            ),
          ),
        SliverToBoxAdapter(
          child: _Footer(state: state, cubit: cubit),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: Spacing.xl)),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.subtitle});

  final ProductListState state;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    final theme = Theme.of(context).textTheme;
    final brand = state.brand;
    final count = Text(
      Strings.products(state.total),
      style: theme.bodyMedium!.copyWith(color: c.muted),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.pageGutter,
        Spacing.lg,
        Spacing.pageGutter,
        Spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (brand != null)
            Row(
              children: [
                BrandLogo(
                  id: brand.id,
                  name: brand.name,
                  logo: brand.logo,
                  size: 64,
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(brand.name, style: theme.titleLarge),
                      if (brand.isOwnBrand)
                        Text(
                          Strings.brandOwn,
                          style: theme.labelMedium!.copyWith(color: c.accent),
                        ),
                      count,
                    ],
                  ),
                ),
              ],
            )
          else
            count,
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                style: theme.bodyMedium!.copyWith(color: c.muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// The category's first select attribute (the web's "types" chips) and its
/// child categories, on one scrolling row.
class _ChipsRow extends StatelessWidget {
  const _ChipsRow({required this.state, required this.cubit});

  final ProductListState state;
  final ProductListCubit cubit;

  @override
  Widget build(BuildContext context) {
    final category = state.category;
    if (category == null) return const SizedBox.shrink();
    final def = category.attributes
        .where(
          (a) =>
              a.type == AttributeType.select ||
              a.type == AttributeType.multiselect,
        )
        .firstOrNull;
    var options = const <String>[];
    if (def != null) {
      final facet = state.facets?.attributes
          .where((a) => a.key == def.key)
          .firstOrNull;
      options =
          facet?.values?.map((v) => v.value).toList() ??
          def.options ??
          const [];
    }
    final name = def == null ? null : 'attr.${def.key}';
    final selected = name == null ? null : state.filters.value(name);
    if (options.isEmpty && category.children.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.pageGutter),
        children: [
          if (options.isNotEmpty && name != null) ...[
            ChoiceChip(
              label: const Text(Strings.listAll),
              selected: selected == null,
              onSelected: (_) => cubit.setFilters(
                state.filters.setValue(name, null, cubit.scope),
              ),
            ),
            for (final o in options) ...[
              const SizedBox(width: Spacing.sm),
              ChoiceChip(
                label: Text(o),
                selected: selected == o,
                onSelected: (_) => cubit.setFilters(
                  state.filters.setValue(name, o, cubit.scope),
                ),
              ),
            ],
          ],
          for (final child in category.children) ...[
            const SizedBox(width: Spacing.sm),
            ActionChip(
              label: Text(child.name),
              onPressed: () => context.push(Routes.categoryPath(child.slug)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.state, required this.cubit});

  final ProductListState state;
  final ProductListCubit cubit;

  @override
  Widget build(BuildContext context) {
    final activeCount = state.filters.active.length;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.pageGutter,
        vertical: Spacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.swap_vert, size: 20),
              label: Text(
                sortLabel(state.filters.effectiveSort),
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: () => showSortSheet(context, cubit),
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.tune, size: 20),
              label: Text(
                activeCount > 0
                    ? '${Strings.filtersButton} ($activeCount)'
                    : Strings.filtersButton,
              ),
              onPressed: () => showFilterSheet(context, cubit),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.state,
    required this.scope,
    required this.emptyMessage,
    required this.onClear,
  });

  final ProductListState state;
  final ListScope scope;
  final String emptyMessage;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (state.filters.active.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Strings.emptyFiltered,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                Strings.emptyFilteredText,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium!
                    .copyWith(color: context.lamsa.muted),
              ),
              const SizedBox(height: Spacing.lg),
              OutlinedButton(
                onPressed: onClear,
                child: const Text(Strings.clearFilters),
              ),
            ],
          ),
        ),
      );
    }
    if (scope is SearchScope) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Strings.searchEmptyTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                Strings.searchEmptyText,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium!
                    .copyWith(color: context.lamsa.muted),
              ),
            ],
          ),
        ),
      );
    }
    return EmptyView(message: emptyMessage);
  }
}

/// Infinite-scroll footer: spinner while loading, retry when it failed.
class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.cubit});

  final ProductListState state;
  final ProductListCubit cubit;

  @override
  Widget build(BuildContext context) {
    if (state.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(Spacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.loadMoreFailed) {
      return Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          children: [
            const Text(Strings.loadMoreFailed),
            TextButton(
              onPressed: cubit.loadMore,
              child: const Text(Strings.retry),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
