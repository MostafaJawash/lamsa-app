import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/images/image_urls.dart';
import 'package:lamsa_app/core/money/money_format.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/core/widgets/app_messenger.dart';
import 'package:lamsa_app/core/widgets/connection_error_view.dart';
import 'package:lamsa_app/core/widgets/state_views.dart';
import 'package:lamsa_app/features/cart/cubit/cart_cubit.dart';
import 'package:lamsa_app/features/catalog/cubit/load_status.dart';
import 'package:lamsa_app/features/catalog/cubit/product_detail_cubit.dart';
import 'package:lamsa_app/features/catalog/data/catalog_repository.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';
import 'package:lamsa_app/features/catalog/data/variants.dart';
import 'package:lamsa_app/features/catalog/presentation/categories_screen.dart'
    show ScrollableMessage;
import 'package:lamsa_app/features/catalog/presentation/widgets/catalog_art.dart';
import 'package:lamsa_app/features/catalog/presentation/widgets/product_card_view.dart';
import 'package:lamsa_app/features/catalog/presentation/widgets/sections.dart';
import 'package:lamsa_app/features/favorites/presentation/favorite_button.dart';

class ProductScreen extends StatelessWidget {
  const ProductScreen({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ProductDetailCubit(context.read<CatalogRepository>(), slug)..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text(Strings.product)),
        body: const _ProductBody(),
      ),
    );
  }
}

class _ProductBody extends StatelessWidget {
  const _ProductBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProductDetailCubit>();
    return BlocBuilder<ProductDetailCubit, ProductDetailState>(
      builder: (context, state) {
        switch (state.status) {
          case LoadStatus.loading:
            return const LoadingView(message: Strings.loading);
          case LoadStatus.failed:
            return RefreshIndicator(
              onRefresh: () => cubit.load(refresh: true),
              child: ScrollableMessage(
                child: state.notFound
                    ? const EmptyView(message: Strings.productNotFound)
                    : state.connection
                    ? ConnectionErrorView(
                        onRetry: () => cubit.load(refresh: true),
                      )
                    : ErrorView(
                        message: state.error ?? Strings.productUnavailable,
                        onRetry: () => cubit.load(refresh: true),
                      ),
              ),
            );
          case LoadStatus.loaded:
            return RefreshIndicator(
              onRefresh: () => cubit.load(refresh: true),
              child: _Loaded(state: state),
            );
        }
      },
    );
  }
}

class _Loaded extends StatefulWidget {
  const _Loaded({required this.state});

  final ProductDetailState state;

  @override
  State<_Loaded> createState() => _LoadedState();
}

class _LoadedState extends State<_Loaded> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final product = state.product!;
    final variant = state.variant;
    final price = priceView(product, variant);
    final stock = stockView(product, variant);
    final images = imagesFor(product, variant);
    final c = context.lamsa;
    final theme = Theme.of(context).textTheme;
    final out = stock.status == StockStatus.out;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: Spacing.xxl),
      children: [
        // Keyed by variant: switching variant restarts at its first image.
        ProductGallery(
          key: ValueKey('gallery-${variant?.id}'),
          images: images,
          fallback: product.image,
        ),
        Padding(
          padding: const EdgeInsets.all(Spacing.pageGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.brand != null)
                InkWell(
                  onTap: () =>
                      context.push(Routes.brandPath(product.brand!.slug)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      product.brand!.name,
                      style: theme.titleSmall!.copyWith(color: c.accent),
                    ),
                  ),
                ),
              Text(product.name, style: theme.headlineSmall),
              const SizedBox(height: Spacing.sm),
              Wrap(
                spacing: Spacing.md,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PriceText(
                    price: price.current,
                    compareAt: price.regular,
                    currency: price.currency,
                    large: true,
                  ),
                  if (price.savings != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: c.accentSoft,
                        borderRadius: BorderRadius.circular(Radii.sm),
                      ),
                      child: Text(
                        Strings.productSave(
                          formatAmount(price.savings!, price.currency),
                        ),
                        style: theme.labelMedium!.copyWith(color: c.accent),
                      ),
                    ),
                ],
              ),
              for (final option in product.variantOptions)
                _OptionGroup(
                  product: product,
                  option: option,
                  variant: variant,
                ),
              const SizedBox(height: Spacing.md),
              _StockLine(stock: stock),
              if (out)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    Strings.productOutHint,
                    style: theme.bodySmall!.copyWith(color: c.muted),
                  ),
                ),
              const SizedBox(height: Spacing.lg),
              // Keyed by variant: switching variant resets quantity and limits.
              _BuyBar(
                key: ValueKey('buy-${variant?.id}'),
                product: product,
                variant: variant,
                stock: stock,
              ),
              const SizedBox(height: Spacing.xl),
              _Tabs(
                product: product,
                showDetails: _showDetails,
                onChanged: (v) => setState(() => _showDetails = v),
              ),
              if (product.type == ProductType.bundle &&
                  product.items.isNotEmpty)
                _BundleItems(items: product.items),
            ],
          ),
        ),
        _Related(section: state.related),
      ],
    );
  }
}

/// Swipeable image gallery with a thumbnail strip. Medium/large renditions
/// are chosen by on-screen size (see `ImageUrls.pick`).
class ProductGallery extends StatefulWidget {
  const ProductGallery({required this.images, required this.fallback, super.key});

  final List<ProductImage> images;

  /// Card image used when the product has no gallery images at all.
  final ImageUrls? fallback;

  @override
  State<ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<ProductGallery> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    final urls = widget.images.isNotEmpty
        ? [for (final i in widget.images) i.urls]
        : [widget.fallback];
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: PageView.builder(
            controller: _controller,
            itemCount: urls.length,
            onPageChanged: (p) => setState(() => _page = p),
            itemBuilder: (_, i) => Semantics(
              image: true,
              label: widget.images.isNotEmpty
                  ? (widget.images[i].altText ?? Strings.productImage(i + 1))
                  : null,
              child: CatalogImage(urls: urls[i], fit: BoxFit.contain),
            ),
          ),
        ),
        if (urls.length > 1)
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Spacing.pageGutter),
              itemCount: urls.length,
              separatorBuilder: (_, _) => const SizedBox(width: Spacing.sm),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _controller.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                ),
                child: Container(
                  width: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(
                      color: i == _page ? c.accent : c.line,
                      width: i == _page ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CatalogImage(urls: urls[i]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _OptionGroup extends StatelessWidget {
  const _OptionGroup({
    required this.product,
    required this.option,
    required this.variant,
  });

  final ProductDetail product;
  final VariantOption option;
  final Variant? variant;

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    final theme = Theme.of(context).textTheme;
    final selected = variant?.options[option.key];
    final cubit = context.read<ProductDetailCubit>();
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: '${option.label}: ',
              children: [
                TextSpan(
                  text: selected ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            style: theme.bodyMedium,
          ),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.md,
            runSpacing: Spacing.sm,
            children: [
              for (final v in option.values)
                () {
                  final target =
                      variantForValue(product, variant, option.key, v.value);
                  final na = target == null || target.stockStatus == StockStatus.out;
                  final on = selected == v.value;
                  void pick() => cubit.selectOption(option.key, v.value);
                  if (option.type == OptionType.color) {
                    return Semantics(
                      button: true,
                      selected: on,
                      label: na ? '${v.value} ${Strings.productOutShort}' : v.value,
                      child: Tooltip(
                        message: v.value,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: pick,
                          child: Opacity(
                            opacity: na ? .4 : 1,
                            child: Container(
                              width: 40,
                              height: 40,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: on ? c.accent : c.line,
                                  width: on ? 2 : 1,
                                ),
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: hexColor(v.hex),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return Opacity(
                    opacity: na ? .5 : 1,
                    child: ChoiceChip(
                      selected: on,
                      onSelected: (_) => pick(),
                      label: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(v.value, textDirection: TextDirection.ltr),
                          if (target != null)
                            Text(
                              na
                                  ? Strings.productOutShort
                                  : formatAmount(
                                      target.currentPrice,
                                      target.currency,
                                    ),
                              style: theme.labelSmall!.copyWith(color: c.muted),
                            ),
                        ],
                      ),
                    ),
                  );
                }(),
            ],
          ),
        ],
      ),
    );
  }
}

/// Availability text. The exact stock is never shown, except the backend's
/// own "low stock" count.
class _StockLine extends StatelessWidget {
  const _StockLine({required this.stock});

  final StockView stock;

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    final (text, color) = switch (stock.status) {
      StockStatus.out => (Strings.productOut, c.danger),
      StockStatus.low when stock.left != null =>
        (Strings.productLow(stock.left!), c.warn),
      StockStatus.low => (Strings.productInStock, c.warn),
      StockStatus.inStock => (Strings.productInStock, c.ok),
    };
    return Row(
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: Spacing.sm),
        Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleSmall!
              .copyWith(color: color),
        ),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.product,
    required this.showDetails,
    required this.onChanged,
  });

  final ProductDetail product;
  final bool showDetails;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    final theme = Theme.of(context).textTheme;
    final hasDetails = product.attributes.isNotEmpty;
    final details = showDetails && hasDetails;
    final description = product.description?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            const ButtonSegment(
              value: false,
              label: Text(Strings.productTabDescription),
            ),
            if (hasDetails)
              const ButtonSegment(
                value: true,
                label: Text(Strings.productTabDetails),
              ),
          ],
          selected: {details},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
        const SizedBox(height: Spacing.md),
        if (details)
          for (final a in product.attributes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      a.label,
                      style: theme.bodyMedium!.copyWith(color: c.muted),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(a.display, style: theme.bodyMedium),
                  ),
                ],
              ),
            )
        else
          Text(
            description.isEmpty ? Strings.productNoDescription : description,
            style: theme.bodyMedium!.copyWith(height: 1.7),
          ),
      ],
    );
  }
}

class _BundleItems extends StatelessWidget {
  const _BundleItems({required this.items});

  final List<BundleItem> items;

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(Strings.productBundleTitle, style: theme.titleLarge),
          const SizedBox(height: Spacing.sm),
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => context.push(Routes.productPath(item.product.slug)),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.md),
                child: SizedBox.square(
                  dimension: 56,
                  child: CatalogImage(urls: item.product.image),
                ),
              ),
              title: Text(item.product.name),
              subtitle: item.variantLabel == null ? null : Text(item.variantLabel!),
              trailing: Text(
                Strings.bundleQuantity(item.quantity),
                style: theme.titleSmall!.copyWith(color: c.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _Related extends StatelessWidget {
  const _Related({required this.section});

  final Section<List<ProductCard>> section;

  @override
  Widget build(BuildContext context) {
    final items = section.data ?? const <ProductCard>[];
    // Related is a bonus: nothing is shown when empty or failed.
    if (!section.isLoading && items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: Strings.productRelated),
        if (section.isLoading) const RailSkeleton() else ProductRail(products: items),
      ],
    );
  }
}

/// Quantity stepper, "أضِف إلى السلة" and the heart. Works for guests and
/// signed-in users (the cart cubit picks where the cart lives). The quantity
/// respects the backend's low-stock count; an `INSUFFICIENT_STOCK` answer
/// clamps it to what is left, and a sold-out item disables the button for
/// real (not for "not built yet").
class _BuyBar extends StatefulWidget {
  const _BuyBar({
    required this.product,
    required this.variant,
    required this.stock,
    super.key,
  });

  final ProductDetail product;
  final Variant? variant;
  final StockView stock;

  @override
  State<_BuyBar> createState() => _BuyBarState();
}

class _BuyBarState extends State<_BuyBar> {
  int _qty = 1;

  /// What the backend last said is left for this item (0: nothing).
  int? _limit;
  bool _adding = false;

  Future<void> _add() async {
    setState(() => _adding = true);
    final router = GoRouter.maybeOf(context);
    final error = await context.read<CartCubit>().add(
          productId: widget.product.id,
          variantId: widget.variant?.id,
          quantity: _qty,
          slug: widget.product.slug,
        );
    if (!mounted) return;
    setState(() {
      _adding = false;
      if (error?.code == 'OUT_OF_STOCK') _limit = 0;
      if (error?.code == 'INSUFFICIENT_STOCK' && error?.available != null) {
        _limit = error!.available;
        _qty = _qty.clamp(1, _limit! < 1 ? 1 : _limit!);
      }
    });
    if (error != null) {
      showToast(error.text);
      return;
    }
    showToast(
      Strings.toastCartAdded,
      actionLabel: Strings.toastCartAction,
      onAction: router == null ? null : () => router.go(Routes.cart),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    final out = widget.stock.status == StockStatus.out || _limit == 0;
    final max = (_limit != null && _limit! > 0 ? _limit! : maxQuantity(widget.stock))
        .clamp(1, maxQuantity(widget.stock));
    final qty = _qty.clamp(1, max);
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: Strings.quantityLess,
                icon: const Icon(Icons.remove),
                onPressed: out || qty <= 1 ? null : () => setState(() => _qty = qty - 1),
              ),
              Text('$qty', style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                tooltip: Strings.quantityMore,
                icon: const Icon(Icons.add),
                onPressed: out || qty >= max ? null : () => setState(() => _qty = qty + 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: FilledButton(
            // Disabled only for real state (sold out), never for a missing feature.
            onPressed: out || _adding ? null : _add,
            child: _adding
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : Text(out ? Strings.productOut : Strings.productAddToCart),
          ),
        ),
        const SizedBox(width: Spacing.md),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: FavoriteButton(
            productId: widget.product.id,
            slug: widget.product.slug,
            size: 24,
            overlay: false,
          ),
        ),
      ],
    );
  }
}
