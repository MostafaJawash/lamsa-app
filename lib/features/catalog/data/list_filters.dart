import 'package:equatable/equatable.dart';

/// What a product list is about. Mirrors lamsa-web's `ListScope`.
sealed class ListScope extends Equatable {
  const ListScope();

  /// Params the scope fixes itself (never part of the user's filters).
  Set<String> get fixedNames => const {};

  /// Backend params the scope adds to every request.
  List<(String, String)> get fixedParams => const [];

  @override
  List<Object?> get props => [runtimeType];
}

final class CategoryScope extends ListScope {
  const CategoryScope(this.slug);

  final String slug;

  @override
  List<(String, String)> get fixedParams => [('category', slug)];

  @override
  List<Object?> get props => [slug];
}

final class BrandScope extends ListScope {
  const BrandScope(this.slug);

  final String slug;

  @override
  Set<String> get fixedNames => const {'brand'};

  @override
  List<(String, String)> get fixedParams => [('brand', slug)];

  @override
  List<Object?> get props => [slug];
}

final class NewScope extends ListScope {
  const NewScope();

  @override
  Set<String> get fixedNames => const {'is_new'};

  @override
  List<(String, String)> get fixedParams => const [('is_new', 'true')];
}

final class SaleScope extends ListScope {
  const SaleScope();

  @override
  Set<String> get fixedNames => const {'on_sale'};

  @override
  List<(String, String)> get fixedParams => const [('on_sale', 'true')];
}

final class SearchScope extends ListScope {
  const SearchScope();
}

enum SortKey {
  newest('newest'),
  priceAsc('price_asc'),
  priceDesc('price_desc'),
  relevance('relevance');

  const SortKey(this.wire);

  final String wire;

  static SortKey? fromWire(String? value) {
    for (final s in values) {
      if (s.wire == value) return s;
    }
    return null;
  }
}

/// Page size of every product list (same as lamsa-web).
const productPageSize = 24;

final _money = RegExp(r'^\d{1,6}(\.\d{1,2})?$');
final _number = RegExp(r'^-?\d{1,9}(\.\d{1,4})?$');
final _key = RegExp(r'^[a-z][a-z0-9_]{0,63}$');
final _attr = RegExp(r'^attr\.([a-z0-9_]+)(\.(min|max))?$');
final _opt = RegExp(r'^opt\.([a-z0-9_]+)$');
const _maxValueLength = 100;

/// The user's list filters as a normalized, immutable set of `(name, value)`
/// pairs using the backend's own parameter names (`brand`, `min_price`,
/// `attr.<key>`, `opt.<key>`, `sort`, `q`, ...). Equal filters always compare
/// and serialize equal, so [cacheKey] is a safe cache key.
///
/// The page is not part of the filters: pagination is the cubit's job.
final class ListFilters extends Equatable {
  const ListFilters._(this.pairs);

  /// Normalizes [input] for [scope]: invalid names/values are dropped, single
  /// valued names keep their last value, duplicates are removed and the
  /// result is sorted.
  factory ListFilters.of(
    Iterable<(String, String)> input,
    ListScope scope,
  ) {
    final single = <String, String>{};
    final multi = <(String, String)>{};
    for (final (rawName, rawValue) in input) {
      final name = rawName.trim();
      final value = rawValue.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (!_valid(name, value, scope)) continue;
      if (_singleValued(name)) {
        single[name] = value;
      } else {
        multi.add((name, value));
      }
    }
    final out = <(String, String)>[
      for (final e in single.entries) (e.key, e.value),
      ...multi,
    ];
    // A currency only qualifies a price range: alone it is no filter.
    final hasRange =
        out.any((p) => p.$1 == 'min_price' || p.$1 == 'max_price');
    out.removeWhere((p) => p.$1 == 'price_currency' && !hasRange);
    out.sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
    return ListFilters._(List.unmodifiable(out));
  }

  static const empty = ListFilters._([]);

  final List<(String, String)> pairs;

  static bool _singleValued(String name) =>
      const {'min_price', 'max_price', 'on_sale', 'sort', 'q'}
          .contains(name) ||
      RegExp(r'^attr\.[a-z0-9_]+\.(min|max)$').hasMatch(name);

  static bool _valid(String name, String value, ListScope scope) {
    if (value.isEmpty || value.length > _maxValueLength) return false;
    if (scope.fixedNames.contains(name)) return false;
    switch (name) {
      case 'brand':
        return true;
      case 'min_price':
      case 'max_price':
        return _money.hasMatch(value);
      case 'price_currency':
        return value == 'SYP' || value == 'USD';
      case 'on_sale':
        return value == 'true';
      case 'sort':
        final sort = SortKey.fromWire(value);
        return sort != null &&
            (sort != SortKey.relevance || scope is SearchScope);
      case 'q':
        return scope is SearchScope;
    }
    final attr = _attr.firstMatch(name);
    if (attr != null) {
      return _key.hasMatch(attr.group(1)!) &&
          (attr.group(2) == null || _number.hasMatch(value));
    }
    final opt = _opt.firstMatch(name);
    return opt != null && _key.hasMatch(opt.group(1)!);
  }

  // ---- reads ----

  List<String> values(String name) =>
      [for (final p in pairs) if (p.$1 == name) p.$2];

  String? value(String name) {
    for (final p in pairs) {
      if (p.$1 == name) return p.$2;
    }
    return null;
  }

  bool has(String name, String value) =>
      pairs.any((p) => p.$1 == name && p.$2 == value);

  /// Filters that narrow the result set (not `q`, not `sort`): the "active"
  /// ones shown as chips and counted on the filter button.
  List<(String, String)> get active =>
      [for (final p in pairs) if (p.$1 != 'q' && p.$1 != 'sort') p];

  /// The sort in effect: relevance while searching, newest otherwise.
  SortKey get effectiveSort =>
      SortKey.fromWire(value('sort')) ??
      (value('q') != null ? SortKey.relevance : SortKey.newest);

  // ---- changes (each returns a new, normalized instance) ----

  ListFilters toggle(String name, String val, ListScope scope) => ListFilters.of(
        has(name, val)
            ? pairs.where((p) => !(p.$1 == name && p.$2 == val))
            : [...pairs, (name, val)],
        scope,
      );

  /// Replaces every value of [name]; `null` removes it.
  ListFilters setValue(String name, String? val, ListScope scope) =>
      ListFilters.of(
        [
          ...pairs.where((p) => p.$1 != name),
          if (val != null) (name, val),
        ],
        scope,
      );

  ListFilters without(Iterable<(String, String)> remove, ListScope scope) {
    final drop = remove.toSet();
    return ListFilters.of(pairs.where((p) => !drop.contains(p)), scope);
  }

  /// Keeps only the search text and sort ("مسح الكل").
  ListFilters cleared(ListScope scope) => ListFilters.of(
        pairs.where((p) => p.$1 == 'q' || p.$1 == 'sort'),
        scope,
      );

  /// Removes a parameter the backend rejected (`INVALID_FILTER`), together
  /// with its `.min`/`.max` companions.
  ListFilters dropParam(String name) => ListFilters._(
        List.unmodifiable(
          pairs.where((p) => p.$1 != name && !p.$1.startsWith('$name.')),
        ),
      );

  /// Stable string for caches: equal filters give equal keys.
  String get cacheKey =>
      pairs.map((p) => '${Uri.encodeQueryComponent(p.$1)}='
          '${Uri.encodeQueryComponent(p.$2)}').join('&');

  @override
  List<Object?> get props => [cacheKey];
}

/// Query assembly for `GET /products` and `GET /products/facets`.
abstract final class CatalogQuery {
  /// Params of a product page: scope params, filters, `page`, `page_size`.
  static List<(String, String)> products(
    ListScope scope,
    ListFilters filters, {
    int page = 1,
    int pageSize = productPageSize,
  }) =>
      _sorted([
        ...scope.fixedParams,
        ...filters.pairs,
        ('page_size', '$pageSize'),
        if (page > 1) ('page', '$page'),
      ]);

  /// Facets take the same filters but no sort, page or page size.
  static List<(String, String)> facets(ListScope scope, ListFilters filters) =>
      _sorted([
        ...scope.fixedParams,
        for (final p in filters.pairs)
          if (p.$1 != 'sort') p,
      ]);

  static List<(String, String)> _sorted(List<(String, String)> pairs) =>
      pairs
        ..sort((a, b) {
          final c = a.$1.compareTo(b.$1);
          return c != 0 ? c : a.$2.compareTo(b.$2);
        });

  /// `a=b&c=d`, percent-encoded (Arabic included); repeated names stay
  /// repeated, as the backend expects for OR filters.
  static String encode(List<(String, String)> pairs) => pairs
      .map((p) => '${Uri.encodeQueryComponent(p.$1)}='
          '${Uri.encodeQueryComponent(p.$2)}')
      .join('&');
}
