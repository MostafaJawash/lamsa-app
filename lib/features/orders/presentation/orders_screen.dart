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
import 'package:lamsa_app/features/account/data/address_rules.dart';
import 'package:lamsa_app/features/account/data/addresses_repository.dart';
import 'package:lamsa_app/features/account/data/models/address_models.dart';
import 'package:lamsa_app/features/account/presentation/address_screens.dart';
import 'package:lamsa_app/features/cart/cubit/cart_cubit.dart';
import 'package:lamsa_app/features/catalog/presentation/widgets/catalog_art.dart';
import 'package:lamsa_app/features/orders/cubit/orders_cubits.dart';
import 'package:lamsa_app/features/orders/data/models/order_models.dart';
import 'package:lamsa_app/features/orders/data/order_format.dart';
import 'package:lamsa_app/features/orders/data/orders_api.dart';
import 'package:lamsa_app/features/orders/presentation/order_widgets.dart';

String _filterLabel(OrderFilter f) => switch (f) {
      OrderFilter.all => Strings.ordersFilterAll,
      OrderFilter.active => Strings.ordersFilterActive,
      OrderFilter.completed => Strings.ordersFilterCompleted,
      OrderFilter.cancelled => Strings.ordersFilterCancelled,
    };

/// Account > Orders: newest first, filter chips, infinite scroll.
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) => OrdersCubit(context.read<OrdersApi>())..load(),
        child: const _OrdersView(),
      );
}

class _OrdersView extends StatefulWidget {
  const _OrdersView();

  @override
  State<_OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<_OrdersView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) {
        context.read<OrdersCubit>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _open(int id) async {
    final cubit = context.read<OrdersCubit>();
    await context.push(Routes.orderPath(id));
    // The order may have been cancelled meanwhile.
    if (mounted) await cubit.load(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.orders)),
      body: BlocBuilder<OrdersCubit, OrdersState>(
        builder: (context, state) {
          return Column(
            children: [
              // A scroll view with a row (all chips exist at once; there are
              // only four) rather than a lazy list.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.pageGutter,
                  vertical: Spacing.sm,
                ),
                child: Row(
                  children: [
                    for (final f in OrderFilter.values)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: Spacing.sm),
                        child: ChoiceChip(
                          label: Text(_filterLabel(f)),
                          selected: state.filter == f,
                          onSelected: (_) =>
                              context.read<OrdersCubit>().load(filter: f),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(child: _body(context, state)),
            ],
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, OrdersState state) {
    switch (state.status) {
      case OrdersLoad.loading:
        return const LoadingView(message: Strings.loading);
      case OrdersLoad.failed:
        if (state.connection) {
          return ConnectionErrorView(
            onRetry: () => context.read<OrdersCubit>().load(),
          );
        }
        return ErrorView(
          message: state.error ?? Strings.ordersUnavailable,
          onRetry: () => context.read<OrdersCubit>().load(),
        );
      case OrdersLoad.ready:
        break;
    }
    if (state.items.isEmpty) {
      final filtered = state.filter != OrderFilter.all;
      return RefreshIndicator(
        onRefresh: () => context.read<OrdersCubit>().load(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(Spacing.xl),
          children: [
            const SizedBox(height: Spacing.xl),
            Text(
              filtered ? Strings.ordersEmptyFiltered : Strings.ordersEmptyTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (!filtered) ...[
              const SizedBox(height: Spacing.lg),
              Center(
                child: FilledButton(
                  onPressed: () => context.go(Routes.home),
                  child: const Text(Strings.ordersStartShopping),
                ),
              ),
            ],
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => context.read<OrdersCubit>().load(refresh: true),
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Spacing.pageGutter),
        itemCount: state.items.length + (state.loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: Spacing.md),
        itemBuilder: (context, i) {
          if (i >= state.items.length) {
            return const Padding(
              padding: EdgeInsets.all(Spacing.lg),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final o = state.items[i];
          return _OrderCard(order: o, onTap: () => _open(o.id));
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final OrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    final theme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.sm),
                child: SizedBox.square(
                  dimension: 56,
                  child: CatalogImage(urls: order.image),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            Strings.orderNumber(order.id),
                            style: theme.titleSmall,
                          ),
                        ),
                        StatusPill(status: order.status, label: order.statusLabel),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatOrderDate(order.createdAt),
                      style: theme.bodySmall!.copyWith(color: c.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Strings.products(order.itemsCount)} · ${order.deliveryMethodName}',
                      style: theme.bodySmall!.copyWith(color: c.muted),
                    ),
                    const SizedBox(height: Spacing.xs),
                    // One line per currency; never combined.
                    for (final t in order.totals)
                      Text(
                        formatAmount(t.total, t.currency),
                        style: theme.titleSmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One order: timeline, lines, delivery, totals, cancel and reorder.
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({required this.orderId, this.seed, super.key});

  final int orderId;

  /// The order just placed, shown at once while it refreshes.
  final OrderDetail? seed;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) {
          final cubit = OrderDetailCubit(
            context.read<OrdersApi>(),
            orderId,
            context.read<CartCubit>(),
          );
          if (seed != null) cubit.seed(seed!);
          cubit.load(refresh: seed != null);
          return cubit;
        },
        child: _OrderDetailView(orderId: orderId),
      );
}

class _OrderDetailView extends StatelessWidget {
  const _OrderDetailView({required this.orderId});

  final int orderId;

  Future<void> _cancel(BuildContext context) async {
    final cubit = context.read<OrderDetailCubit>();
    // null: the customer kept the order; a string (maybe empty): the reason.
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _CancelDialog(),
    );
    if (reason == null) return;
    final error = await cubit.cancel(reason: reason);
    showToast(error ?? Strings.toastOrderCancelled);
  }

  Future<void> _reorder(BuildContext context) async {
    final router = GoRouter.of(context);
    final outcome = await context.read<OrderDetailCubit>().reorder();
    if (outcome.error != null) {
      showToast(outcome.error!);
    } else if (outcome.restored == 0) {
      showToast(Strings.odReorderNothing);
    } else {
      showToast(
        Strings.toastMerged(outcome.restored),
        sub: outcome.adjusted ? Strings.toastMergedAdjusted : null,
        actionLabel: Strings.toastCartAction,
        onAction: () => router.go(Routes.cart),
      );
      router.go(Routes.cart);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Strings.orderNumber(orderId))),
      body: BlocBuilder<OrderDetailCubit, OrderDetailState>(
        builder: (context, state) {
          switch (state.status) {
            case OrderLoad.loading:
              return const LoadingView(message: Strings.loading);
            case OrderLoad.notFound:
            case OrderLoad.failed:
              if (state.connection) {
                return ConnectionErrorView(
                  onRetry: () => context.read<OrderDetailCubit>().load(),
                );
              }
              return ErrorView(
                message: state.error ?? Strings.ordersUnavailable,
                onRetry: state.status == OrderLoad.failed
                    ? () => context.read<OrderDetailCubit>().load()
                    : null,
              );
            case OrderLoad.ready:
              return _content(context, state, state.order!);
          }
        },
      ),
    );
  }

  Widget _content(BuildContext context, OrderDetailState state, OrderDetail o) {
    final c = context.lamsa;
    final theme = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: () => context.read<OrderDetailCubit>().load(refresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Spacing.pageGutter),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  Strings.orderPlacedOn(formatOrderDate(o.createdAt, time: true)),
                  style: theme.bodyMedium!.copyWith(color: c.muted),
                ),
              ),
              StatusPill(status: o.status, label: o.statusLabel),
            ],
          ),
          if (o.cancelReason != null && o.cancelReason!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.sm),
              child: Text(
                Strings.odCancelReasonShown(o.cancelReason!),
                style: theme.bodyMedium!.copyWith(color: c.danger),
              ),
            ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.sm),
              child: Text(state.error!, style: TextStyle(color: c.danger)),
            ),
          const SizedBox(height: Spacing.lg),
          _Section(
            title: Strings.odTimeline,
            child: Column(
              children: [
                for (var i = 0; i < o.timeline.length; i++)
                  _TimelineRow(step: o.timeline[i], last: i == o.timeline.length - 1),
              ],
            ),
          ),
          _Section(
            title: Strings.odItems,
            child: Column(
              children: [for (final it in o.items) _ItemRow(item: it)],
            ),
          ),
          _Section(title: Strings.odDelivery, child: _DeliveryInfo(order: o)),
          _Section(
            title: Strings.odPayment,
            child: Text(
              '${Strings.odCod} · ${_paymentLabel(o.paymentStatus)}',
              style: theme.bodyMedium,
            ),
          ),
          if (o.customerNotes != null && o.customerNotes!.isNotEmpty)
            _Section(
              title: Strings.checkoutNotes,
              child: Text(o.customerNotes!),
            ),
          if (o.giftMessage != null && o.giftMessage!.isNotEmpty)
            _Section(
              title: Strings.checkoutGiftLabel,
              child: Text(o.giftMessage!),
            ),
          _Section(
            title: Strings.cartSummary,
            child: _Totals(order: o),
          ),
          const SizedBox(height: Spacing.sm),
          if (o.canCancel)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: OutlinedButton(
                onPressed: state.busy ? null : () => _cancel(context),
                style: OutlinedButton.styleFrom(foregroundColor: c.danger),
                child: const Text(Strings.odCancel),
              ),
            ),
          FilledButton(
            onPressed: state.busy ? null : () => _reorder(context),
            child: state.busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Text(Strings.odReorder),
          ),
        ],
      ),
    );
  }

  String _paymentLabel(String status) => switch (status) {
        'paid' => Strings.odPaid,
        'refunded' => Strings.odRefunded,
        _ => Strings.odCod,
      };
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Spacing.lg),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: Spacing.md),
                child,
              ],
            ),
          ),
        ),
      );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.step, required this.last});

  final TimelineStep step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    final theme = Theme.of(context).textTheme;
    final reached = step.reachedAt != null;
    final cancelled = statusTone(step.status) == StatusTone.cancelled;
    final color = !reached
        ? c.line
        : cancelled
            ? c.danger
            : step.isCurrent
                ? c.accent
                : c.ok;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    color: reached ? color : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                ),
                if (!last) Expanded(child: Container(width: 2, color: c.line)),
              ],
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: theme.bodyMedium!.copyWith(
                      fontWeight: step.isCurrent ? FontWeight.w700 : null,
                      color: reached ? null : c.muted,
                    ),
                  ),
                  if (reached)
                    Text(
                      formatOrderDate(step.reachedAt!, time: true),
                      style: theme.bodySmall!.copyWith(color: c.muted),
                    ),
                  if (step.cancelReason != null && step.cancelReason!.isNotEmpty)
                    Text(
                      Strings.odCancelReasonShown(step.cancelReason!),
                      style: theme.bodySmall!.copyWith(color: c.danger),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final c = context.lamsa;
    final slug = item.productSlug;
    return InkWell(
      onTap: slug == null || slug.isEmpty
          ? null
          : () => context.push(Routes.productPath(slug)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.sm),
              child: SizedBox.square(
                dimension: 52,
                child: CatalogImage(urls: item.image),
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: theme.bodyMedium),
                  if (item.variantLabel != null && item.variantLabel!.isNotEmpty)
                    Text(
                      item.variantLabel!,
                      style: theme.bodySmall!.copyWith(color: c.muted),
                    ),
                  Text(
                    '${formatAmount(item.unitPrice, item.currency)} × ${item.quantity}',
                    style: theme.bodySmall!.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
            Text(
              formatAmount(item.lineTotal, item.currency),
              style: theme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryInfo extends StatelessWidget {
  const _DeliveryInfo({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final c = context.lamsa;
    return FutureBuilder<List<Governorate>>(
      future: context
          .read<AddressesRepository>()
          .governorates()
          .onError<Object>((_, _) => const <Governorate>[]),
      builder: (context, snap) {
        final names = snap.data ?? const <Governorate>[];
        final view = describeAddressSnapshot(
          order.shippingAddress,
          (code) => governorateName(names, code),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(order.delivery.name, style: theme.bodyMedium),
            if (order.delivery.feePaidToCarrier)
              Text(
                Strings.checkoutCarrierPaid,
                style: theme.bodySmall!.copyWith(color: c.warn),
              ),
            if (view != null) ...[
              const SizedBox(height: Spacing.md),
              Text(Strings.odAddress, style: theme.labelMedium),
              for (final line in view.lines) Text(line, style: theme.bodyMedium),
              if (view.notes != null)
                Text(
                  view.notes!,
                  style: theme.bodySmall!.copyWith(color: c.muted),
                ),
              if (view.location != null)
                TextButton.icon(
                  onPressed: () => openOnMap(view.location!.lat, view.location!.lng),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text(Strings.odViewOnMap),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final t = order.totals;
    final hasDiscount = t.any((x) => (double.tryParse(x.discount) ?? 0) > 0);
    return Column(
      children: [
        AmountRow(
          label: Strings.cartSubtotal,
          amounts: orderTotalsOf(t, (x) => x.subtotal),
        ),
        if (hasDiscount)
          AmountRow(
            label: Strings.cartSavings,
            amounts: orderTotalsOf(t, (x) => x.discount),
          ),
        if (order.delivery.feePaidToCarrier)
          const AmountRow(
            label: Strings.cartDelivery,
            amounts: [],
            note: Strings.checkoutPaidToCarrier,
          )
        else
          AmountRow(
            label: Strings.cartDelivery,
            amounts: orderTotalsOf(t, (x) => x.shippingFee),
          ),
        const Divider(height: Spacing.xl),
        AmountRow(
          label: Strings.cartTotal,
          amounts: orderTotalsOf(t, (x) => x.total),
          strong: true,
        ),
      ],
    );
  }
}

/// Asks to confirm the cancellation, with an optional reason. Owns its text
/// controller so it is disposed only after the dialog has left the screen.
class _CancelDialog extends StatefulWidget {
  const _CancelDialog();

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(Strings.odCancelTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(Strings.odCancelText),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _reason,
              maxLines: 2,
              maxLength: 500,
              decoration: const InputDecoration(labelText: Strings.odCancelReason),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Strings.odKeep),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_reason.text),
          child: const Text(Strings.odCancelConfirm),
        ),
      ],
    );
  }
}
