import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/platform/external_links.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/core/widgets/app_messenger.dart';
import 'package:lamsa_app/core/widgets/lamsa_button.dart';
import 'package:lamsa_app/core/widgets/state_views.dart';
import 'package:lamsa_app/features/account/cubit/addresses_cubits.dart';
import 'package:lamsa_app/features/account/data/address_rules.dart';
import 'package:lamsa_app/features/account/data/addresses_repository.dart';
import 'package:lamsa_app/features/account/data/models/address_models.dart';
import 'package:lamsa_app/features/account/presentation/location_picker.dart';

/// What the address form needs from whoever opens it.
final class AddressFormArgs {
  const AddressFormArgs({required this.governorates, this.editing});

  final List<Governorate> governorates;
  final Address? editing;
}

/// Opens the address form and returns the saved address (or null when the
/// customer backed out). Used by the address book and by the checkout.
Future<Address?> openAddressForm(
  BuildContext context, {
  required List<Governorate> governorates,
  Address? editing,
}) =>
    context.push<Address>(
      Routes.addressForm,
      extra: AddressFormArgs(governorates: governorates, editing: editing),
    );

/// Account > Addresses.
class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) =>
            AddressesCubit(context.read<AddressesRepository>())..load(),
        child: const _AddressesView(),
      );
}

class _AddressesView extends StatelessWidget {
  const _AddressesView();

  Future<void> _add(BuildContext context, AddressesState state) async {
    final cubit = context.read<AddressesCubit>();
    final saved = await openAddressForm(context, governorates: state.governorates);
    if (saved != null) {
      showToast(Strings.toastAddressSaved);
      await cubit.load(refresh: true);
    }
  }

  Future<void> _edit(
    BuildContext context,
    AddressesState state,
    Address a,
  ) async {
    final cubit = context.read<AddressesCubit>();
    final saved = await openAddressForm(
      context,
      governorates: state.governorates,
      editing: a,
    );
    if (saved != null) {
      showToast(Strings.toastAddressSaved);
      await cubit.load(refresh: true);
    }
  }

  Future<void> _delete(BuildContext context, Address a) async {
    final cubit = context.read<AddressesCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(Strings.addressesDeleteTitle),
        content: Text(Strings.addressesDeleteText(a.label ?? a.details)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(Strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(Strings.addressesDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final error = await cubit.delete(a.id);
    showToast(error ?? Strings.toastAddressDeleted);
  }

  Future<void> _makeDefault(BuildContext context, Address a) async {
    final error = await context.read<AddressesCubit>().setDefault(a.id);
    showToast(error ?? Strings.toastAddressDefault);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.addresses)),
      body: BlocBuilder<AddressesCubit, AddressesState>(
        builder: (context, state) {
          switch (state.status) {
            case AddressesLoad.loading:
              return const LoadingView(message: Strings.loading);
            case AddressesLoad.failed:
              return ErrorView(
                message: state.error ?? Strings.addressesUnavailable,
                onRetry: () => context.read<AddressesCubit>().load(),
              );
            case AddressesLoad.ready:
              break;
          }
          final canAdd = state.governorates.isNotEmpty;
          return RefreshIndicator(
            onRefresh: () => context.read<AddressesCubit>().load(refresh: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(Spacing.pageGutter),
              children: [
                Text(
                  Strings.addressesSub,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: context.lamsa.muted,
                      ),
                ),
                const SizedBox(height: Spacing.lg),
                if (state.governoratesFailed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.md),
                    child: Text(
                      Strings.governoratesUnavailable,
                      style: TextStyle(color: context.lamsa.danger),
                    ),
                  ),
                if (state.addresses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.xl),
                    child: Column(
                      children: [
                        Text(
                          Strings.addressesEmptyTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: Spacing.sm),
                        const Text(
                          Strings.addressesEmptyText,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: Spacing.lg),
                        FilledButton(
                          onPressed: canAdd ? () => _add(context, state) : null,
                          child: const Text(Strings.addressesAddFirst),
                        ),
                      ],
                    ),
                  )
                else ...[
                  for (final a in state.addresses)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.md),
                      child: AddressCard(
                        address: a,
                        governorates: state.governorates,
                        actions: [
                          if (!a.isDefault)
                            TextButton(
                              onPressed: () => _makeDefault(context, a),
                              child: const Text(Strings.addressesSetDefault),
                            ),
                          TextButton(
                            onPressed: () => _edit(context, state, a),
                            child: const Text(Strings.addressesEdit),
                          ),
                          TextButton(
                            onPressed: () => _delete(context, a),
                            child: Text(
                              Strings.addressesDelete,
                              style: TextStyle(color: context.lamsa.danger),
                            ),
                          ),
                        ],
                      ),
                    ),
                  OutlinedButton(
                    onPressed: canAdd ? () => _add(context, state) : null,
                    child: const Text(Strings.addressesAdd),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One saved address (the address book and, selectable, the checkout).
class AddressCard extends StatelessWidget {
  const AddressCard({
    required this.address,
    required this.governorates,
    this.actions = const [],
    this.selected = false,
    this.onTap,
    super.key,
  });

  final Address address;
  final List<Governorate> governorates;
  final List<Widget> actions;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    final theme = Theme.of(context).textTheme;
    final place = [
      governorateName(governorates, address.governorate),
      if (address.area != null && address.area!.isNotEmpty) address.area!,
    ].join('، ');
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (onTap != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: Spacing.sm),
                      child: Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: selected ? c.accent : c.muted,
                        size: 20,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      address.label?.isNotEmpty ?? false
                          ? address.label!
                          : place,
                      style: theme.titleSmall,
                    ),
                  ),
                  if (address.isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: c.accentSoft,
                        borderRadius: BorderRadius.circular(Radii.sm),
                      ),
                      child: Text(
                        Strings.addressesDefault,
                        style: theme.labelSmall!.copyWith(color: c.accent),
                      ),
                    ),
                ],
              ),
              if (address.label?.isNotEmpty ?? false) ...[
                const SizedBox(height: 2),
                Text(place, style: theme.bodyMedium),
              ],
              const SizedBox(height: 2),
              Text(address.details, style: theme.bodyMedium),
              if (address.notes != null && address.notes!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  address.notes!,
                  style: theme.bodySmall!.copyWith(color: c.muted),
                ),
              ],
              if (address.hasLocation) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: c.muted),
                    const SizedBox(width: 4),
                    Text(
                      Strings.addressesHasLocation,
                      style: theme.bodySmall!.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ],
              if (actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.xs),
                  child: Wrap(spacing: Spacing.xs, children: actions),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The add / edit form. Pops with the saved [Address].
class AddressFormScreen extends StatelessWidget {
  const AddressFormScreen({required this.args, super.key});

  final AddressFormArgs args;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) => AddressFormCubit(
          context.read<AddressesRepository>(),
          governorateCodes: [for (final g in args.governorates) g.code],
          editing: args.editing,
        ),
        child: _AddressFormView(args: args),
      );
}

class _AddressFormView extends StatefulWidget {
  const _AddressFormView({required this.args});

  final AddressFormArgs args;

  @override
  State<_AddressFormView> createState() => _AddressFormViewState();
}

class _AddressFormViewState extends State<_AddressFormView> {
  late final TextEditingController _label;
  late final TextEditingController _area;
  late final TextEditingController _details;
  late final TextEditingController _notes;
  late String _governorate;
  late String _latitude;
  late String _longitude;
  late bool _default;

  @override
  void initState() {
    super.initState();
    final a = widget.args.editing;
    final d = a == null ? const AddressDraft() : AddressDraft.from(a);
    _label = TextEditingController(text: d.label);
    _area = TextEditingController(text: d.area);
    _details = TextEditingController(text: d.details);
    _notes = TextEditingController(text: d.notes);
    _governorate = d.governorate;
    _latitude = d.latitude;
    _longitude = d.longitude;
    _default = d.isDefault;
  }

  @override
  void dispose() {
    _label.dispose();
    _area.dispose();
    _details.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() => context.read<AddressFormCubit>().save(
        AddressDraft(
          label: _label.text,
          governorate: _governorate,
          area: _area.text,
          details: _details.text,
          notes: _notes.text,
          latitude: _latitude,
          longitude: _longitude,
          isDefault: _default,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AddressFormCubit>();
    final c = context.lamsa;
    final editing = widget.args.editing != null;
    return BlocListener<AddressFormCubit, AddressFormState>(
      listenWhen: (a, b) => a.saved == null && b.saved != null,
      listener: (context, state) => context.pop(state.saved),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            editing ? Strings.addressesEditTitle : Strings.addressesNewTitle,
          ),
        ),
        body: SafeArea(
          child: BlocBuilder<AddressFormCubit, AddressFormState>(
            builder: (context, state) {
              final e = state.errors;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(Spacing.pageGutter),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _label,
                      onChanged: (_) => cubit.clearError(AddressField.label),
                      decoration: InputDecoration(
                        labelText: Strings.afLabel,
                        hintText: Strings.afLabelHint,
                        errorText: e[AddressField.label],
                        errorMaxLines: 3,
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    DropdownButtonFormField<String>(
                      initialValue: _governorate.isEmpty ? null : _governorate,
                      isExpanded: true,
                      hint: const Text(Strings.afGovernorateHint),
                      decoration: InputDecoration(
                        labelText: Strings.afGovernorate,
                        errorText: e[AddressField.governorate],
                        errorMaxLines: 3,
                      ),
                      items: [
                        for (final g in widget.args.governorates)
                          DropdownMenuItem(value: g.code, child: Text(g.name)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        cubit.clearError(AddressField.governorate);
                        setState(() => _governorate = v);
                      },
                    ),
                    const SizedBox(height: Spacing.lg),
                    TextField(
                      controller: _area,
                      onChanged: (_) => cubit.clearError(AddressField.area),
                      decoration: InputDecoration(
                        labelText: Strings.afArea,
                        errorText: e[AddressField.area],
                        errorMaxLines: 3,
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    TextField(
                      controller: _details,
                      minLines: 3,
                      maxLines: 5,
                      onChanged: (_) {
                        cubit.clearError(AddressField.details);
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: Strings.afDetails,
                        hintText: Strings.afDetailsHint,
                        helperText: Strings.afDetailsHelp,
                        counterText: Strings.afCounter(
                          textLength(_details.text),
                          AddressLimits.detailsMax,
                        ),
                        errorText: e[AddressField.details],
                        errorMaxLines: 3,
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    TextField(
                      controller: _notes,
                      minLines: 2,
                      maxLines: 4,
                      onChanged: (_) => cubit.clearError(AddressField.notes),
                      decoration: InputDecoration(
                        labelText: Strings.afNotes,
                        errorText: e[AddressField.notes],
                        errorMaxLines: 3,
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    LocationPicker(
                      governorate: _governorate,
                      latitude: _latitude,
                      longitude: _longitude,
                      onChanged: (p) {
                        cubit.clearError(AddressField.location);
                        setState(() {
                          _latitude = p == null ? '' : formatCoordinate(p.lat);
                          _longitude = p == null ? '' : formatCoordinate(p.lng);
                        });
                      },
                    ),
                    if (e[AddressField.location] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: Spacing.xs),
                        child: Text(
                          e[AddressField.location]!,
                          style: TextStyle(color: c.danger),
                        ),
                      ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _default,
                      onChanged: (v) => setState(() => _default = v ?? false),
                      title: const Text(Strings.afMakeDefault),
                    ),
                    if (e[AddressField.form] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Spacing.md),
                        child: Text(
                          e[AddressField.form]!,
                          style: TextStyle(color: c.danger),
                        ),
                      ),
                    LamsaButton(
                      label: Strings.afSave,
                      loading: state.submitting,
                      onPressed: _submit,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Opens an order's pin in OpenStreetMap (the website's map provider).
Future<void> openOnMap(String lat, String lng) =>
    ExternalLinks.opener(openStreetMapUri(lat, lng));
