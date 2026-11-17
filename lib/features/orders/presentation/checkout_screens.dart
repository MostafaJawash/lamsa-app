import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/money/money_format.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/core/widgets/app_messenger.dart';
import 'package:lamsa_app/core/widgets/lamsa_button.dart';
import 'package:lamsa_app/core/widgets/state_views.dart';
import 'package:lamsa_app/features/account/data/addresses_repository.dart';
import 'package:lamsa_app/features/account/presentation/address_screens.dart';
import 'package:lamsa_app/features/cart/cubit/cart_cubit.dart';
import 'package:lamsa_app/features/cart/data/cart_api.dart';
import 'package:lamsa_app/features/cart/data/models/cart_models.dart';
import 'package:lamsa_app/features/catalog/presentation/widgets/catalog_art.dart';
import 'package:lamsa_app/features/orders/cubit/checkout_cubit.dart';
import 'package:lamsa_app/features/orders/data/models/order_models.dart';
import 'package:lamsa_app/features/orders/data/orders_api.dart';
import 'package:lamsa_app/features/orders/presentation/order_widgets.dart';

/// Checkout: address, delivery method (as the backend offers it for that
/// address), cash on delivery, notes, and the confirmation.
class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) => CheckoutCubit(
          cartApi: context.read<CartApi>(),
          orders: context.read<OrdersApi>(),
          addresses: context.read<AddressesRepository>(),
          cart: context.read<CartCubit>(),
        )..load(),
        child: const _CheckoutView(),
      );
}

class _CheckoutView extends StatefulWidget {
  const _CheckoutView();

  @override
  State<_CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<_CheckoutView> {
  final _notes = TextEditingController();
  final _gift = TextEditingController();
  bool _giftOpen = false;

  @override
  void dispose() {
    _notes.dispose();
    _gift.dispose();
    super.dispose();
  }

  Future<void> _addAddress(CheckoutState state) async {
    final cubit = context.read<CheckoutCubit>();
    final saved = await openAddressForm(
      context,
      governorates: state.governorates,
    );
    if (saved != null) {
      showToast(Strings.toastAddressSaved);
      await cubit.addressAdded(saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<CheckoutCubit, CheckoutState>(
          listenWhen: (a, b) => a.placed == null && b.placed != null,
          listener: (context, state) =>
              context.go(Routes.checkoutDone, extra: state.placed),
        ),
        BlocListener<CheckoutCubit, CheckoutState>(
          listenWhen: (a, b) => a.redirect == null && b.redirect != null,
          listener: (context, state) {
            final message = state.redirect?.message;
            context.read<CheckoutCubit>().redirectHandled();
            if (message != null) showToast(message);
            context.go(Routes.cart);
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(title: const Text(Strings.checkoutTitle)),
        body: BlocBuilder<CheckoutCubit, CheckoutState>(
          builder: (context, state) {
            switch (state.status) {
              case CheckoutStatus.loading:
                return const LoadingView(message: Strings.loading);
              case CheckoutStatus.unavailable:
                return ErrorView(
                  message: state.error ?? Strings.checkoutUnavailable,
                  onRetry: () => context.read<CheckoutCubit>().load(),
                );
              case CheckoutStatus.ready:
                return _form(context, state);
            }
          },
        ),
      ),
    );
  }

  Widget _form(BuildContext context, CheckoutState state) {
    final cubit = context.read<CheckoutCubit>();
    final c = context.lamsa;
    final theme = Theme.of(context).textTheme;
    final notice = switch (state.notice) {
      CheckoutNotice.price => Strings.checkoutPriceChanged,
      CheckoutNotice.method => Strings.checkoutMethodChanged,
      CheckoutNotice.address || CheckoutNotice.location =>
        Strings.checkoutAddressInvalid,
      null => null,
    };
    final quote = state.quote;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(Spacing.pageGutter),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          if (notice != null) _Banner(text: notice, color: c.accentSoft),
          // ---- address ----
          const _SectionTitle(Strings.checkoutAddress),
          if (state.addresses.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: Text(
                Strings.checkoutNoAddress,
                style: theme.bodyMedium!.copyWith(color: c.muted),
              ),
            ),
          for (final a in state.addresses)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: AddressCard(
                address: a,
                governorates: state.governorates,
                selected: a.id == state.addressId,
                onTap: state.placing ? null : () => cubit.selectAddress(a.id),
              ),
            ),
          OutlinedButton(
            onPressed: state.governorates.isEmpty || state.placing
                ? null
                : () => _addAddress(state),
            child: const Text(Strings.checkoutAddAddress),
          ),
          const SizedBox(height: Spacing.xl),
          // ---- delivery ----
          const _SectionTitle(Strings.checkoutDelivery),
          if (state.address == null)
            Text(
              Strings.checkoutDeliveryNeedsAddress,
              style: theme.bodyMedium!.copyWith(color: c.muted),
            )
          else if (state.quotes.isEmpty)
            Text(
              Strings.checkoutNoMethods,
              style: theme.bodyMedium!.copyWith(color: c.danger),
            )
          else
            for (final q in state.quotes)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: _QuoteCard(
                  quote: q,
                  selected: q.code == state.methodCode,
                  onTap: state.placing ? null : () => cubit.selectMethod(q.code),
                ),
              ),
          const SizedBox(height: Spacing.xl),
          // ---- payment ----
          const _SectionTitle(Strings.checkoutPayment),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.payments_outlined, color: c.accent),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(Strings.checkoutCod, style: theme.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          Strings.checkoutCodHint,
                          style: theme.bodySmall!.copyWith(color: c.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.xl),
          // ---- notes ----
          const _SectionTitle(Strings.checkoutExtras),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            onChanged: cubit.setNotes,
            decoration: const InputDecoration(
              labelText: Strings.checkoutNotes,
              hintText: Strings.checkoutNotesHint,
            ),
          ),
          const SizedBox(height: Spacing.md),
          if (_giftOpen)
            TextField(
              controller: _gift,
              minLines: 2,
              maxLines: 4,
              onChanged: cubit.setGift,
              decoration: const InputDecoration(
                labelText: Strings.checkoutGiftLabel,
                hintText: Strings.checkoutGiftHint,
              ),
            )
          else
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => setState(() => _giftOpen = true),
                icon: const Icon(Icons.card_giftcard, size: 18),
                label: const Text(Strings.checkoutGift),
              ),
            ),
          const SizedBox(height: Spacing.xl),
          // ---- summary ----
          const _SectionTitle(Strings.checkoutYourOrder),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final line in state.cart.lines) _SummaryLine(line: line),
                  const Divider(height: Spacing.xl),
                  AmountRow(
                    label: Strings.cartSubtotal,
                    amounts: fromCart(state.cart.subtotals),
                  ),
                  if (state.cart.savings.isNotEmpty)
                    AmountRow(
                      label: Strings.cartSavings,
                      amounts: fromCart(state.cart.savings),
                    ),
                  _DeliveryRow(quote: quote),
                  const Divider(height: Spacing.xl),
                  AmountRow(
                    label: Strings.cartTotal,
                    amounts: fromCart(state.totals),
                    strong: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: Text(state.error!, style: TextStyle(color: c.danger)),
            ),
          if (state.address == null || quote == null)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: Text(
                state.address == null
                    ? Strings.checkoutNeedAddress
                    : Strings.checkoutNeedMethod,
                textAlign: TextAlign.center,
                style: theme.bodySmall!.copyWith(color: c.muted),
              ),
            ),
          LamsaButton(
            label: Strings.checkoutConfirm,
            loading: state.placing,
            onPressed: state.canPlace ? cubit.place : null,
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            Strings.checkoutNotifyHint,
            textAlign: TextAlign.center,
            style: theme.bodySmall!.copyWith(color: c.muted),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Spacing.sm),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Spacing.lg),
        child: Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Text(text),
        ),
      );
}

/// One delivery method as the backend quoted it for the address.
class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.quote,
    required this.selected,
    required this.onTap,
  });

  final DeliveryQuote quote;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    final theme = Theme.of(context).textTheme;
    final fee = quote.feePaidToCarrier
        ? Strings.checkoutPaidToCarrier
        : quote.isFree
            ? Strings.checkoutFree
            : formatAmount(quote.fee, quote.currency);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(
          color: selected ? c.accent : c.line,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? c.accent : c.muted,
                size: 20,
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(quote.name, style: theme.titleSmall),
                    if (quote.description != null &&
                        quote.description!.isNotEmpty)
                      Text(
                        quote.description!,
                        style: theme.bodySmall!.copyWith(color: c.muted),
                      ),
                    if (quote.feePaidToCarrier)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          Strings.checkoutCarrierPaid,
                          style: theme.bodySmall!.copyWith(color: c.warn),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Text(fee, style: theme.titleSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow({required this.quote});

  final DeliveryQuote? quote;

  @override
  Widget build(BuildContext context) {
    final q = quote;
    if (q == null) {
      return const AmountRow(
        label: Strings.cartDelivery,
        amounts: [],
        note: Strings.checkoutDeliveryPending,
      );
    }
    if (q.feePaidToCarrier) {
      return const AmountRow(
        label: Strings.cartDelivery,
        amounts: [],
        note: Strings.checkoutPaidToCarrier,
      );
    }
    if (q.isFree) {
      return const AmountRow(
        label: Strings.cartDelivery,
        amounts: [],
        note: Strings.checkoutFree,
      );
    }
    return AmountRow(
      label: Strings.cartDelivery,
      amounts: [(amount: q.fee, currency: q.currency)],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.sm),
            child: SizedBox.square(
              dimension: 48,
              child: CatalogImage(urls: line.image),
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodyMedium,
                ),
                Text(
                  [
                    if (line.variant != null) line.variant!.label,
                    '× ${line.quantity}',
                  ].join(' · '),
                  style: theme.bodySmall!.copyWith(color: context.lamsa.muted),
                ),
              ],
            ),
          ),
          Text(formatAmount(line.lineTotal, line.currency), style: theme.bodyMedium),
        ],
      ),
    );
  }
}

/// Order confirmation.
class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({required this.order, super.key});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    final theme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.successTitle),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.pageGutter),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.check_circle, size: 72, color: c.ok),
                  const SizedBox(height: Spacing.lg),
                  Text(
                    Strings.successTitle,
                    textAlign: TextAlign.center,
                    style: theme.headlineSmall,
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    '${Strings.successNumber}: #${order.id}',
                    textAlign: TextAlign.center,
                    style: theme.titleMedium,
                  ),
                  const SizedBox(height: Spacing.lg),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.lg),
                      child: Column(
                        children: [
                          AmountRow(
                            label: Strings.cartTotal,
                            amounts: orderTotalsOf(order.totals, (t) => t.total),
                            strong: true,
                          ),
                          const SizedBox(height: Spacing.xs),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${Strings.odPayment}: ${Strings.checkoutCod}',
                                  style: theme.bodySmall!.copyWith(color: c.muted),
                                ),
                              ),
                              StatusPill(
                                status: order.status,
                                label: order.statusLabel,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  Text(
                    Strings.checkoutNotifyHint,
                    textAlign: TextAlign.center,
                    style: theme.bodySmall!.copyWith(color: c.muted),
                  ),
                  const SizedBox(height: Spacing.xl),
                  FilledButton(
                    onPressed: () {
                      // Back from the order leads to the account tab.
                      context.go(Routes.account);
                      context.push(Routes.orderPath(order.id));
                    },
                    child: const Text(Strings.successTrack),
                  ),
                  const SizedBox(height: Spacing.sm),
                  OutlinedButton(
                    onPressed: () => context.go(Routes.home),
                    child: const Text(Strings.successContinue),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
