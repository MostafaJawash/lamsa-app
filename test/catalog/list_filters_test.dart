import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/features/catalog/data/filter_chips.dart';
import 'package:lamsa_app/features/catalog/data/list_filters.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';

ListFilters f(List<(String, String)> pairs, [ListScope scope = const CategoryScope('care')]) =>
    ListFilters.of(pairs, scope);

void main() {
  const category = CategoryScope('care');

  group('normalization', () {
    test('drops invalid names and values, keeps valid ones sorted', () {
      final filters = f([
        ('brand', 'luma'),
        ('min_price', 'abc'), // not money
        ('max_price', '15000'),
        ('price_currency', 'SYP'),
        ('sort', 'price_asc'),
        ('sort', 'bogus'), // unknown sort is dropped, valid one stays
        ('nonsense', 'x'),
        ('brand', ''),
        ('attr.skin_type', 'جافة'),
        ('opt.color', 'وردي'),
      ]);
      expect(filters.pairs, [
        ('attr.skin_type', 'جافة'),
        ('brand', 'luma'),
        ('max_price', '15000'),
        ('opt.color', 'وردي'),
        ('price_currency', 'SYP'),
        ('sort', 'price_asc'),
      ]);
    });

    test('single-valued names keep the last value, multi-valued repeat', () {
      final filters = f([
        ('min_price', '100'),
        ('min_price', '200'),
        ('brand', 'a'),
        ('brand', 'b'),
        ('brand', 'a'),
      ]);
      expect(filters.value('min_price'), '200');
      expect(filters.values('brand'), ['a', 'b']);
    });

    test('a price currency alone is not a filter', () {
      expect(f([('price_currency', 'USD')]).pairs, isEmpty);
      expect(
        f([('price_currency', 'USD'), ('min_price', '5')]).pairs,
        contains(('price_currency', 'USD')),
      );
    });

    test('relevance only exists for search, q only for search', () {
      expect(f([('sort', 'relevance')]).pairs, isEmpty);
      expect(f([('q', 'x')]).pairs, isEmpty);
      const search = SearchScope();
      expect(f([('sort', 'relevance'), ('q', 'عطر')], search).pairs.length, 2);
    });

    test('fixed names of the scope never come from filters', () {
      expect(f([('brand', 'x')], const BrandScope('luma')).pairs, isEmpty);
      expect(f([('on_sale', 'true')], const SaleScope()).pairs, isEmpty);
    });

    test('attribute ranges need numbers', () {
      expect(f([('attr.spf.min', '15')]).pairs, [('attr.spf.min', '15')]);
      expect(f([('attr.spf.min', 'x')]).pairs, isEmpty);
    });

    test('equal filters share a cache key regardless of input order', () {
      expect(
        f([('brand', 'b'), ('brand', 'a')]).cacheKey,
        f([('brand', 'a'), ('brand', 'b')]).cacheKey,
      );
    });
  });

  group('changes', () {
    test('toggle adds then removes', () {
      final a = ListFilters.empty.toggle('brand', 'luma', category);
      expect(a.has('brand', 'luma'), isTrue);
      expect(a.toggle('brand', 'luma', category).pairs, isEmpty);
    });

    test('setValue replaces every value; null removes', () {
      final a = f([('attr.skin', 'a'), ('attr.skin', 'b')]);
      expect(a.setValue('attr.skin', 'c', category).values('attr.skin'), ['c']);
      expect(a.setValue('attr.skin', null, category).pairs, isEmpty);
    });

    test('cleared keeps only q and sort', () {
      const search = SearchScope();
      final a = f([
        ('q', 'عطر'),
        ('sort', 'price_asc'),
        ('brand', 'x'),
        ('on_sale', 'true'),
      ], search);
      expect(a.cleared(search).pairs, [('q', 'عطر'), ('sort', 'price_asc')]);
    });

    test('dropParam removes a rejected param and its .min/.max', () {
      final a = f([('attr.spf.min', '1'), ('attr.spf.max', '9'), ('brand', 'x')]);
      expect(a.dropParam('attr.spf').pairs, [('brand', 'x')]);
    });

    test('active excludes q and sort; effectiveSort has context defaults', () {
      final a = f([('q', 'x'), ('sort', 'price_desc'), ('brand', 'b')], const SearchScope());
      expect(a.active, [('brand', 'b')]);
      expect(a.effectiveSort, SortKey.priceDesc);
      expect(ListFilters.empty.effectiveSort, SortKey.newest);
      expect(
        f([('q', 'x')], const SearchScope()).effectiveSort,
        SortKey.relevance,
      );
    });
  });

  group('query building', () {
    test('product list: scope params, filters, page size, sorted', () {
      final q = CatalogQuery.products(
        category,
        f([('brand', 'luma'), ('brand', 'bella'), ('sort', 'price_asc')]),
      );
      expect(q, [
        ('brand', 'bella'),
        ('brand', 'luma'),
        ('category', 'care'),
        ('page_size', '24'),
        ('sort', 'price_asc'),
      ]);
    });

    test('page param only from page 2', () {
      expect(
        CatalogQuery.products(const NewScope(), ListFilters.empty),
        isNot(contains(('page', '1'))),
      );
      expect(
        CatalogQuery.products(const NewScope(), ListFilters.empty, page: 3),
        contains(('page', '3')),
      );
    });

    test('scopes add their fixed params', () {
      expect(
        CatalogQuery.products(const NewScope(), ListFilters.empty),
        contains(('is_new', 'true')),
      );
      expect(
        CatalogQuery.products(const SaleScope(), ListFilters.empty),
        contains(('on_sale', 'true')),
      );
      expect(
        CatalogQuery.products(const BrandScope('luma'), ListFilters.empty),
        contains(('brand', 'luma')),
      );
    });

    test('rail size is passed through as page_size', () {
      expect(
        CatalogQuery.products(const NewScope(), ListFilters.empty, pageSize: 12),
        contains(('page_size', '12')),
      );
    });

    test('a price range keeps its currency; in_stock is never sent', () {
      final q = CatalogQuery.products(
        category,
        f([('min_price', '5000'), ('max_price', '15000'), ('price_currency', 'SYP')]),
      );
      expect(q, contains(('price_currency', 'SYP')));
      expect(q, contains(('min_price', '5000')));
      expect(q.any((p) => p.$1 == 'in_stock'), isFalse);
    });

    test('facets query has no sort, page or page size', () {
      final q = CatalogQuery.facets(
        category,
        f([('sort', 'price_asc'), ('brand', 'luma')]),
      );
      expect(q, [('brand', 'luma'), ('category', 'care')]);
    });

    test('encode percent-encodes Arabic and repeats names', () {
      final s = CatalogQuery.encode([
        ('attr.skin_type', 'جافة'),
        ('attr.skin_type', 'حساسة'),
        ('opt.size', '50 ml'),
      ]);
      expect(
        Uri.splitQueryString(s.replaceAll('+', '%20')),
        // splitQueryString collapses repeats; check the raw text instead.
        isA<Map<String, String>>(),
      );
      expect(s, contains('attr.skin_type=%D8%AC%D8%A7%D9%81%D8%A9'));
      expect(s, contains('attr.skin_type=%D8%AD%D8%B3%D8%A7%D8%B3%D8%A9'));
      expect(s, contains('opt.size=50+ml'));
      expect('&'.allMatches(s).length, 2);
    });
  });

  group('filter chips', () {
    const facets = Facets(
      brands: [BrandFacet(slug: 'luma', name: 'لمى', count: 2)],
      attributes: [
        AttributeFacet(
          key: 'skin_type',
          label: 'نوع البشرة',
          type: AttributeType.select,
        ),
        AttributeFacet(
          key: 'spf',
          label: 'عامل الحماية',
          type: AttributeType.number,
          unit: 'x',
        ),
      ],
      options: [
        OptionFacet(key: 'color', label: 'اللون', type: OptionType.color),
      ],
    );

    test('labels use facet names and money in its currency', () {
      final chips = filterChips(
        f([
          ('brand', 'luma'),
          ('attr.skin_type', 'جافة'),
          ('opt.color', 'وردي'),
          ('on_sale', 'true'),
          ('min_price', '5000'),
          ('max_price', '15000'),
          ('price_currency', 'SYP'),
        ]),
        facets,
      );
      final labels = chips.map((c) => c.label).toList();
      expect(labels, contains('لمى'));
      expect(labels, contains('نوع البشرة: جافة'));
      expect(labels, contains('اللون: وردي'));
      expect(labels, contains('عليه خصم'));
      expect(
        labels.any((l) => l.startsWith('السعر:') && l.contains('ل.س')),
        isTrue,
      );
    });

    test('a USD range is shown in dollars, never converted', () {
      final chips = filterChips(
        f([('min_price', '10'), ('price_currency', 'USD')]),
        null,
      );
      expect(chips.single.label, contains(r'$'));
      expect(chips.single.label, isNot(contains('ل.س')));
    });

    test('removing a chip removes exactly its pairs', () {
      final filters = f([
        ('min_price', '5000'),
        ('max_price', '15000'),
        ('price_currency', 'SYP'),
        ('brand', 'luma'),
      ]);
      final price = filterChips(filters, null).first;
      expect(price.remove, [('min_price', '5000'), ('max_price', '15000')]);
      final after = filters.without(price.remove, category);
      expect(after.pairs, [('brand', 'luma')]); // orphan currency dropped
    });

    test('number attribute ranges merge into one chip', () {
      final chips = filterChips(
        f([('attr.spf.min', '15'), ('attr.spf.max', '50')]),
        facets,
      );
      expect(chips.single.label, 'عامل الحماية: 15–50 x');
      expect(chips.single.remove.length, 2);
    });
  });
}
