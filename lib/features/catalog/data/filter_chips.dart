import 'package:equatable/equatable.dart';
import 'package:lamsa_app/core/money/money_format.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/catalog/data/list_filters.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';

/// One removable chip of the active filters: its text and the pairs removing
/// it takes out of the filters.
final class FilterChipData extends Equatable {
  const FilterChipData(this.label, this.remove);

  final String label;
  final List<(String, String)> remove;

  @override
  List<Object?> get props => [label, remove];
}

/// The active filters as chips labeled with the facet names (brand names,
/// "نوع البشرة: جافة", the price range, ...). Port of lamsa-web's
/// `filterChips`. [facets] may be null (not loaded): raw keys are used then.
List<FilterChipData> filterChips(ListFilters filters, Facets? facets) {
  final chips = <FilterChipData>[];
  String attrLabel(String key) =>
      facets?.attributes.where((a) => a.key == key).firstOrNull?.label ?? key;
  String optLabel(String key) =>
      facets?.options.where((o) => o.key == key).firstOrNull?.label ?? key;

  final min = filters.value('min_price');
  final max = filters.value('max_price');
  if (min != null || max != null) {
    final currency = filters.value('price_currency') ?? 'SYP';
    final range = min != null && max != null
        ? Strings.priceBetween(
            formatAmount(min, currency),
            formatAmount(max, currency),
          )
        : min != null
            ? Strings.priceFrom(formatAmount(min, currency))
            : Strings.priceTo(formatAmount(max!, currency));
    chips.add(
      FilterChipData(Strings.priceRangeChip(range), [
        if (min != null) ('min_price', min),
        if (max != null) ('max_price', max),
      ]),
    );
  }

  final ranges = <String, ({String? min, String? max})>{};
  for (final pair in filters.active) {
    final (name, val) = pair;
    if (name == 'min_price' || name == 'max_price') continue;
    if (name == 'price_currency') continue;
    if (name == 'brand') {
      final brand = facets?.brands.where((b) => b.slug == val).firstOrNull;
      chips.add(FilterChipData(brand?.name ?? val, [pair]));
    } else if (name == 'on_sale') {
      chips.add(FilterChipData(Strings.onSaleOnly, [pair]));
    } else if (name.startsWith('opt.')) {
      chips.add(
        FilterChipData('${optLabel(name.substring(4))}: $val', [pair]),
      );
    } else if (name.startsWith('attr.')) {
      final range = RegExp(r'^attr\.(.+)\.(min|max)$').firstMatch(name);
      if (range != null) {
        final key = range.group(1)!;
        final prev = ranges[key];
        ranges[key] = range.group(2) == 'min'
            ? (min: val, max: prev?.max)
            : (min: prev?.min, max: val);
        continue;
      }
      final key = name.substring(5);
      final text = switch (val) {
        'true' => Strings.yes,
        'false' => Strings.no,
        _ => val,
      };
      chips.add(FilterChipData('${attrLabel(key)}: $text', [pair]));
    }
  }
  for (final MapEntry(key: key, value: r) in ranges.entries) {
    final unit = facets?.attributes.where((a) => a.key == key).firstOrNull?.unit;
    final text = r.min != null && r.max != null
        ? '${r.min}–${r.max}'
        : r.min != null
            ? Strings.priceFrom(r.min!)
            : Strings.priceTo(r.max ?? '');
    chips.add(
      FilterChipData(
        '${attrLabel(key)}: $text${unit != null && unit.isNotEmpty ? ' $unit' : ''}',
        [
          if (r.min != null) ('attr.$key.min', r.min!),
          if (r.max != null) ('attr.$key.max', r.max!),
        ],
      ),
    );
  }
  return chips;
}
