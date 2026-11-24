import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/money/money_format.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/core/widgets/app_messenger.dart';
import 'package:lamsa_app/core/widgets/connection_error_view.dart';
import 'package:lamsa_app/core/widgets/state_views.dart';
import 'package:lamsa_app/features/cart/cubit/cart_cubit.dart';
import 'package:lamsa_app/features/cart/data/cart_errors.dart';
import 'package:lamsa_app/features/cart/data/guest_codec.dart';
import 'package:lamsa_app/features/cart/data/models/cart_models.dart';
import 'package:lamsa_app/features/catalog/presentation/categories_screen.dart'
    show ScrollableMessage;
import 'package:lamsa_app/features/catalog/presentation/widgets/catalog_art.dart';
import 'package:lamsa_app/features/catalog/presentation/widgets/product_card_view.dart'
    show PriceText;

/// Cart tab. Guests and signed-in users see the same screen: the cubit keeps
/// the cart on the device (validated by `/cart/preview`) or in the backend.
/// Prices, stock, issues and totals always come from the backend; there is no
/// checkout yet (a disabled "إتمام الطلب قريبًا" ends the screen).
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    // Fresh prices and stock whenever the tab is (re)built.
    unawaited(context.read<CartCubit>().load(refresh: true));
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CartCubit>();
    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.cart),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: () => cubit.load(refresh: true),
        child: BlocBuilder<CartCubit, CartState>(
          builder: (context, state) {
            final lines = state.cart.lines;
            if (state.status == CartLoad.failed && lines.isEmpty) {
              return ScrollableMessage(
                child: state.connection
                    ? ConnectionErrorView(onRetry: cubit.load)
                    : ErrorView(
                        message: Strings.cartUnavailable,
                        onRetry: cubit.load,
                      ),
              );
            }
            if (lines.isEmpty) {
              if (state.status == CartLoad.ready) {
                return const ScrollableMessage(child: _EmptyCart());
              }
              return const LoadingView(message: Strings.loading);
            }
            return _CartContent(state: state);
          },
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 56, color: context.lamsa.muted),
            const SizedBox(height: Spacing.lg),
            Text(
              Strings.cartEmptyTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              Strings.cartEmptyText,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(color: context.lamsa.muted),
            ),
            const SizedBox(height: Spacing.xl),
            FilledButton(
              onPressed: () => context.go(Routes.home),
              child: const Text(Strings.cartStartShopping),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartContent extends StatelessWidget {
  const _CartContent({required this.state});

  final CartState state;

  Future<void> _resolve(BuildContext context) async {
    final r = await context.read<CartCubit>().resolveIssues();
    if (r.error != null) {
      showToast(r.error!.text);
      return;
    }
    final text = r.toast;
    showToast(text == null || text.isEmpty ? Strings.cartUpdated : text);
  }

  Future<void> _confirmClear(BuildContext context) async {
    final cubit = context.read<CartCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(Strings.cartClearTitle),
        content: const Text(Strings.cartClearText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(Strings.cartClearConfirm),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(Strings.cancel),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final error = await cubit.clear();
    if (error != null) showToast(error.text);
  }

  @override
  Widget build(BuildContext context) {
    final cart = state.cart;
    final theme = Theme.of(context).textTheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Spacing.pageGutter),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                Strings.items(cart.itemsCount),
                style: theme.bodyMedium!.copyWith(color: context.lamsa.muted),
              ),
            ),
            TextButton(
              onPressed: () => _confirmClear(context),
              child: const Text(Strings.cartClear),
            ),
          ],
        ),
        if (cart.issuesCount > 0) ...[
          _IssuesNotice(onResolve: () => _resolve(context)),
          const SizedBox(height: Spacing.md),
        ],
        for (final line in cart.lines) ...[
          CartLineTile(
            key: ValueKey(line.ref),
            line: line,
            lineError: state.lineErrors[line.ref],
          ),
          const SizedBox(height: Spacing.md),
        ],
        const SizedBox(height: Spacing.sm),
        _Summary(cart: cart),
        const SizedBox(height: Spacing.xl),
      ],
    );
  }
}

class _IssuesNotice extends StatelessWidget {
  const _IssuesNotice({required this.onResolve});

  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: c.warn.withValues(alpha: .1),
        border: Border.all(color: c.warn.withValues(alpha: .5)),
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              Strings.cartIssuesNotice,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: Spacing.md),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            ),
            onPressed: onResolve,
            child: const Text(Strings.cartResolve),
          ),
        ],
      ),
    );
  }
}

/// One cart line: image, name (links to the product), brand and variant, unit
/// price (struck regular price when on sale), quantity stepper, line total in
/// the line's own currency, remove. A line with an issue shows the backend's
/// reason and no total (it is not counted).
class CartLineTile extends StatefulWidget {
  const CartLineTile({required this.line, this.lineError, super.key});

  final CartLine line;
  final String? lineError;

  @override
  State<CartLineTile> createState() => _CartLineTileState();
}

class _CartLineTileState extends State<CartLineTile> {
  static const _debounce = Duration(milliseconds: 300);

  /// The quantity being typed in, before the debounced change is sent.
  int? _draft;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _remove() async {
    _timer?.cancel();
    setState(() => _draft = null);
    final error = await context.read<CartCubit>().remove(widget.line.ref);
    if (error != null) showToast(error.text);
  }

  void _step(int delta) {
    final next = (_draft ?? widget.line.quantity) + delta;
    if (next < 1) {
      unawaited(_remove()); // "−" at 1 removes the line
      return;
    }
    if (next > GuestLimits.maxQuantity) return;
    setState(() => _draft = next);
    _timer?.cancel();
    _timer = Timer(_debounce, () async {
      final q = _draft;
      if (q == null) return;
      final error = await context.read<CartCubit>().setQuantity(widget.line.ref, q);
      if (mounted) setState(() => _draft = null);
      if (error != null) showToast(error.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final c = context.lamsa;
    final theme = Theme.of(context).textTheme;
    final quantity = _draft ?? line.quantity;
    final name = line.product.name.isEmpty ? Strings.cartUnknownProduct : line.product.name;
    final subtitle = [line.product.brand?.name, line.variant?.label]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join('، ');
    final slug = line.product.slug;
    final error = line.issue != null ? issueText(line.issue!) : widget.lineError;
    final canOpen = slug.isNotEmpty;
    return Card(
      margin: EdgeInsets.zero,
      color: line.issue != null ? c.surface2 : null,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: canOpen ? () => context.push(Routes.productPath(slug)) : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.md),
                child: SizedBox.square(
                  dimension: 76,
                  child: CatalogImage(urls: line.image),
                ),
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: canOpen ? () => context.push(Routes.productPath(slug)) : null,
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.titleSmall,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: theme.bodySmall!.copyWith(color: c.muted),
                    ),
                  if (canOpen) ...[
                    const SizedBox(height: 4),
                    PriceText(
                      price: line.unitPrice,
                      compareAt: line.compareAtPrice,
                      currency: line.currency,
                    ),
                  ],
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        error,
                        style: theme.bodySmall!.copyWith(color: c.danger),
                      ),
                    ),
                  const SizedBox(height: Spacing.sm),
                  // A wrap, not a row: large amounts (hundreds of thousands
                  // of SYP) must not overflow next to the stepper.
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: Spacing.xs,
                    children: [
                      _Stepper(
                        quantity: quantity,
                        name: name,
                        onLess: () => _step(-1),
                        onMore: quantity >= GuestLimits.maxQuantity
                            ? null
                            : () => _step(1),
                      ),
                      if (line.issue == null)
                        Text(
                          formatAmount(line.lineTotal, line.currency),
                          style: theme.titleSmall!.copyWith(fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '${Strings.cartRemove}: $name',
              icon: const Icon(Icons.close),
              onPressed: _remove,
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.quantity,
    required this.name,
    required this.onLess,
    required this.onMore,
  });

  final int quantity;
  final String name;
  final VoidCallback onLess;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.lamsa.line),
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: Strings.quantityLess,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove, size: 18),
            onPressed: onLess,
          ),
          Semantics(
            label: '${Strings.quantity}: $name',
            child: SizedBox(
              width: 28,
              child: Text(
                '$quantity',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
          IconButton(
            tooltip: Strings.quantityMore,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add, size: 18),
            onPressed: onMore,
          ),
        ],
      ),
    );
  }
}

/// Subtotal, savings and total, **one row per currency** exactly as the
/// backend returns them (SYP and USD are never added together), then the
/// disabled checkout button.
class _Summary extends StatelessWidget {
  const _Summary({required this.cart});

  final Cart cart;

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    final theme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(Strings.cartSummary, style: theme.titleMedium),
            const SizedBox(height: Spacing.md),
            _AmountRow(label: Strings.cartSubtotal, amounts: cart.subtotals),
            const _TextRow(
              label: Strings.cartDelivery,
              value: Strings.cartDeliveryNext,
            ),
            if (cart.savings.isNotEmpty)
              _AmountRow(label: Strings.cartSavings, amounts: cart.savings),
            const Divider(height: Spacing.xl),
            _AmountRow(label: Strings.cartTotal, amounts: cart.totals, strong: true),
            const SizedBox(height: Spacing.lg),
            // A guest is sent to login by the router and comes back here.
            FilledButton(
              onPressed:
                  cart.canCheckout ? () => context.push(Routes.checkout) : null,
              child: const Text(Strings.checkoutTitle),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              cart.canCheckout ? Strings.cartCheckoutHint : Strings.cartFixFirst,
              textAlign: TextAlign.center,
              style: theme.bodySmall!.copyWith(color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amounts,
    this.strong = false,
  });

  final String label;
  final List<CurrencyAmount> amounts;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final style = strong
        ? theme.titleMedium!.copyWith(fontWeight: FontWeight.w700)
        : theme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          // One line per currency; never a combined figure.
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final a in amounts)
                Text(formatAmount(a.amount, a.currency), style: style),
            ],
          ),
        ],
      ),
    );
  }
}

class _TextRow extends StatelessWidget {
  const _TextRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.bodyMedium)),
          Text(
            value,
            style: theme.bodySmall!.copyWith(color: context.lamsa.muted),
          ),
        ],
      ),
    );
  }
}
