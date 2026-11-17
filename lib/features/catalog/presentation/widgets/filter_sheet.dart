import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/features/catalog/cubit/product_list_cubit.dart';
import 'package:lamsa_app/features/catalog/data/list_filters.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';
import 'package:lamsa_app/features/catalog/presentation/widgets/product_card_view.dart'
    show hexColor;

/// Label of each sort option (relevance only exists while searching).
String sortLabel(SortKey key) => switch (key) {
      SortKey.newest => Strings.sortNewest,
      SortKey.priceAsc => Strings.sortPriceAsc,
      SortKey.priceDesc => Strings.sortPriceDesc,
      SortKey.relevance => Strings.sortRelevance,
    };

Future<void> showSortSheet(BuildContext context, ProductListCubit cubit) {
  final scope = cubit.scope;
  final current = cubit.state.filters.effectiveSort;
  final defaultSort = scope is SearchScope ? SortKey.relevance : SortKey.newest;
  final options = [
    if (scope is SearchScope) SortKey.relevance,
    SortKey.newest,
    SortKey.priceAsc,
    SortKey.priceDesc,
  ];
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: RadioGroup<SortKey>(
        groupValue: current,
        onChanged: (key) {
          if (key == null) return;
          Navigator.of(sheetContext).pop();
          // The default sort is "no sort param": one URL, one cache entry.
          unawaited(
            cubit.setFilters(
              cubit.state.filters.setValue(
                'sort',
                key == defaultSort ? null : key.wire,
                scope,
              ),
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Text(
                Strings.listSort,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            for (final key in options)
              RadioListTile<SortKey>(
                value: key,
                title: Text(sortLabel(key)),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showFilterSheet(BuildContext context, ProductListCubit cubit) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: const FilterSheet(),
    ),
  );
}

/// Bottom sheet with every facet of `/products/facets`, edited as a draft
/// and applied with "عرض النتائج". There is no "in stock only" toggle: the
/// backend already leaves out-of-stock products out of browsing.
class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key});

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late ListFilters _draft = context.read<ProductListCubit>().state.filters;
  int _resetCount = 0;

  ListScope get _scope => context.read<ProductListCubit>().scope;

  void _update(ListFilters f) => setState(() => _draft = f);

  void _apply() {
    final cubit = context.read<ProductListCubit>();
    Navigator.of(context).pop();
    unawaited(cubit.setFilters(_draft));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.pageGutter),
          child: Row(
            children: [
              Expanded(
                child: Text(Strings.filtersTitle, style: theme.textTheme.titleLarge),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _draft = _draft.cleared(_scope);
                  _resetCount++;
                }),
                child: const Text(Strings.clearAll),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: BlocBuilder<ProductListCubit, ProductListState>(
            buildWhen: (a, b) =>
                a.facets != b.facets || a.facetsFailed != b.facetsFailed,
            builder: (context, state) {
              final facets = state.facets;
              if (facets == null) {
                return Center(
                  child: state.facetsFailed
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(Strings.filtersUnavailable),
                            TextButton(
                              onPressed:
                                  context.read<ProductListCubit>().reloadFacets,
                              child: const Text(Strings.retry),
                            ),
                          ],
                        )
                      : const Text(Strings.filtersLoading),
                );
              }
              return ListView(
                key: ValueKey(_resetCount),
                padding: const EdgeInsets.all(Spacing.pageGutter),
                children: _groups(facets),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.pageGutter),
            child: FilledButton(
              onPressed: _apply,
              child: const Text(Strings.showResults),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _groups(Facets facets) {
    final scope = _scope;
    return [
      if (scope is! BrandScope && facets.brands.isNotEmpty)
        _Group(
          title: Strings.listBrand,
          child: Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              for (final b in facets.brands)
                FilterChip(
                  label: Text('${b.name} (${b.count})'),
                  selected: _draft.has('brand', b.slug),
                  onSelected: (_) => _update(_draft.toggle('brand', b.slug, scope)),
                ),
            ],
          ),
        ),
      _PriceGroup(
        key: ValueKey('price$_resetCount'),
        facets: facets,
        draft: _draft,
        scope: scope,
        onChanged: _update,
      ),
      for (final a in facets.attributes) ..._attribute(a, scope),
      for (final o in facets.options)
        if (o.values.isNotEmpty) _option(o, scope),
      if (scope is! SaleScope)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(Strings.onSaleOnly),
          value: _draft.has('on_sale', 'true'),
          onChanged: (on) =>
              _update(_draft.setValue('on_sale', on ? 'true' : null, scope)),
        ),
    ];
  }

  List<Widget> _attribute(AttributeFacet a, ListScope scope) {
    final name = 'attr.${a.key}';
    switch (a.type) {
      case AttributeType.number:
        return [
          _Group(
            title: a.unit == null ? a.label : '${a.label} (${a.unit})',
            child: _RangeFields(
              key: ValueKey('$name$_resetCount'),
              minHint: a.min?.toString(),
              maxHint: a.max?.toString(),
              minValue: _draft.value('$name.min'),
              maxValue: _draft.value('$name.max'),
              allowNegative: true,
              onChanged: (min, max) => _update(
                _draft
                    .setValue('$name.min', min, scope)
                    .setValue('$name.max', max, scope),
              ),
            ),
          ),
        ];
      case AttributeType.boolean:
        return [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(a.label),
            value: _draft.has(name, 'true'),
            onChanged: (on) =>
                _update(_draft.setValue(name, on ? 'true' : null, scope)),
          ),
        ];
      case AttributeType.select:
      case AttributeType.multiselect:
        final values = a.values ?? const <FacetValue>[];
        if (values.isEmpty) return const [];
        return [
          _Group(
            title: a.label,
            child: Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: [
                for (final v in values)
                  FilterChip(
                    label: Text('${v.value} (${v.count})'),
                    selected: _draft.has(name, v.value),
                    onSelected: (_) =>
                        _update(_draft.toggle(name, v.value, scope)),
                  ),
              ],
            ),
          ),
        ];
      case AttributeType.text:
      case AttributeType.date:
        return const [];
    }
  }

  Widget _option(OptionFacet o, ListScope scope) {
    final name = 'opt.${o.key}';
    if (o.type == OptionType.color) {
      return _Group(
        title: o.label,
        child: Wrap(
          spacing: Spacing.md,
          runSpacing: Spacing.md,
          children: [
            for (final v in o.values)
              _SwatchButton(
                color: hexColor(v.hex),
                label: '${v.value} (${v.count})',
                selected: _draft.has(name, v.value),
                onTap: () => _update(_draft.toggle(name, v.value, scope)),
              ),
          ],
        ),
      );
    }
    return _Group(
      title: o.label,
      child: Wrap(
        spacing: Spacing.sm,
        runSpacing: Spacing.sm,
        children: [
          for (final v in o.values)
            FilterChip(
              label: Text('${v.value} (${v.count})'),
              selected: _draft.has(name, v.value),
              onSelected: (_) => _update(_draft.toggle(name, v.value, scope)),
            ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: Spacing.sm),
          child,
        ],
      ),
    );
  }
}

class _SwatchButton extends StatelessWidget {
  const _SwatchButton({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? c.accent : c.line,
                width: selected ? 2 : 1,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceGroup extends StatelessWidget {
  const _PriceGroup({
    required this.facets,
    required this.draft,
    required this.scope,
    required this.onChanged,
    super.key,
  });

  final Facets facets;
  final ListFilters draft;
  final ListScope scope;
  final ValueChanged<ListFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final currencies = [for (final p in facets.prices) p.currency];
    final currency = draft.value('price_currency') ??
        (currencies.isNotEmpty ? currencies.first : 'SYP');
    final range = facets.prices.where((p) => p.currency == currency).firstOrNull;
    return _Group(
      title: Strings.listPrice,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (currencies.length > 1) ...[
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                for (final cur in currencies)
                  ButtonSegment(
                    value: cur,
                    label: Text(
                      cur == 'USD' ? Strings.currencyUsd : Strings.currencySyp,
                    ),
                  ),
              ],
              selected: {currency},
              onSelectionChanged: (s) => onChanged(
                draft.setValue('price_currency', s.first, scope),
              ),
            ),
            const SizedBox(height: Spacing.sm),
          ],
          _RangeFields(
            key: ValueKey('range$currency'),
            minHint: range?.min,
            maxHint: range?.max,
            minValue: draft.value('min_price'),
            maxValue: draft.value('max_price'),
            decimals: true,
            onChanged: (min, max) => onChanged(
              draft
                  .setValue('min_price', min, scope)
                  .setValue('max_price', max, scope)
                  .setValue('price_currency', currency, scope),
            ),
          ),
        ],
      ),
    );
  }
}

/// "من / إلى" number fields. Invalid text never reaches the filters: the
/// draft normalizes it away.
class _RangeFields extends StatefulWidget {
  const _RangeFields({
    required this.onChanged,
    super.key,
    this.minHint,
    this.maxHint,
    this.minValue,
    this.maxValue,
    this.decimals = false,
    this.allowNegative = false,
  });

  final String? minHint;
  final String? maxHint;
  final String? minValue;
  final String? maxValue;
  final bool decimals;
  final bool allowNegative;
  final void Function(String? min, String? max) onChanged;

  @override
  State<_RangeFields> createState() => _RangeFieldsState();
}

class _RangeFieldsState extends State<_RangeFields> {
  late final _min = TextEditingController(text: widget.minValue);
  late final _max = TextEditingController(text: widget.maxValue);

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _emit() {
    String? v(TextEditingController c) {
      final t = c.text.trim();
      return t.isEmpty ? null : t;
    }

    widget.onChanged(v(_min), v(_max));
  }

  @override
  Widget build(BuildContext context) {
    final pattern = RegExp(
      widget.allowNegative ? r'[0-9.\-]' : (widget.decimals ? r'[0-9.]' : r'[0-9]'),
    );
    Widget field(TextEditingController c, String label, String? hint) =>
        Expanded(
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(pattern)],
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: label, hintText: hint),
            onChanged: (_) => _emit(),
          ),
        );
    return Row(
      children: [
        field(_min, Strings.minPrice, widget.minHint),
        const SizedBox(width: Spacing.md),
        field(_max, Strings.maxPrice, widget.maxHint),
      ],
    );
  }
}
