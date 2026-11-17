import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';

/// Shapes copied from the live backend (`GET /products`, `/categories`).
const _cardJson = {
  'id': 22,
  'slug': 'ee',
  'name': 'ee',
  'type': 'bundle',
  'currency': 'SYP',
  'brand': {'id': 2, 'name': 'بيلا', 'slug': 'demo-bella'},
  'category': {'id': 5, 'name': 'علبة هدايا', 'slug': 'demo-gifts'},
  'image': {
    'thumb': 'http://127.0.0.1:8000/media/a_thumb.webp',
    'medium': 'http://127.0.0.1:8000/media/a_medium.webp',
    'large': 'http://127.0.0.1:8000/media/a_large.webp',
  },
  'price': '23.00',
  'compare_at_price': '30.00',
  'discount_percent': 23,
  'is_new': true,
  'is_on_sale': true,
  'in_stock': true,
  'swatches': [
    {'name': 'وردي', 'hex': '#FF99AA'},
  ],
  'is_favorite': false,
};

void main() {
  test('product card parses every field', () {
    final c = ProductCard.fromJson(_cardJson);
    expect(c.id, 22);
    expect(c.type, ProductType.bundle);
    expect(c.brand!.slug, 'demo-bella');
    expect(c.price, '23.00');
    expect(c.compareAtPrice, '30.00');
    expect(c.discountPercent, 23);
    expect(c.isNew, isTrue);
    expect(c.swatches.single.hex, '#FF99AA');
    expect(c.image!.medium, endsWith('a_medium.webp'));
  });

  test('product card tolerates null brand, image and compare price', () {
    final c = ProductCard.fromJson({
      ..._cardJson,
      'brand': null,
      'image': null,
      'compare_at_price': null,
      'discount_percent': null,
      'swatches': <Object>[],
    });
    expect(c.brand, isNull);
    expect(c.image, isNull);
    expect(c.compareAtPrice, isNull);
  });

  test('product card round-trips through JSON', () {
    final c = ProductCard.fromJson(_cardJson);
    expect(ProductCard.fromJson(c.toJson()), c);
  });

  test('page parses items, paging and total', () {
    final p = ProductPage.fromJson({
      'items': [_cardJson],
      'page': 2,
      'page_size': 24,
      'total': 49,
    });
    expect(p.items.single.name, 'ee');
    expect(p.page, 2);
    expect(p.pageSize, 24);
    expect(p.total, 49);
    expect(ProductPage.fromJson(p.toJson()), p);
  });

  test('category tree and detail parse and round-trip', () {
    final node = CategoryNode.fromJson({
      'id': 2,
      'name': 'عناية وعطور',
      'slug': 'care',
      'description': null,
      'image': null,
      'product_count': 6,
      'children': [
        {
          'id': 3,
          'name': 'عطور',
          'slug': 'perfumes',
          'description': null,
          'image': null,
          'product_count': 2,
          'children': <Object>[],
        },
      ],
    });
    expect(node.children.single.slug, 'perfumes');
    expect(CategoryNode.fromJson(node.toJson()), node);

    final detail = CategoryDetail.fromJson({
      'id': 2,
      'name': 'عناية وعطور',
      'slug': 'care',
      'description': null,
      'image': null,
      'product_count': 6,
      'breadcrumb': [
        {'id': 2, 'name': 'عناية وعطور', 'slug': 'care'},
      ],
      'children': <Object>[],
      'attributes': [
        {
          'key': 'skin_type',
          'label': 'نوع البشرة',
          'type': 'select',
          'unit': null,
          'options': ['جافة', 'حساسة'],
        },
      ],
      'variant_options': <Object>[],
    });
    expect(detail.attributes.single.type, AttributeType.select);
    expect(detail.attributes.single.options, ['جافة', 'حساسة']);
    expect(CategoryDetail.fromJson(detail.toJson()), detail);
  });

  test('brand parses logo and own-brand flag', () {
    final b = Brand.fromJson({
      'id': 1,
      'name': 'لمى',
      'slug': 'luma',
      'description': null,
      'logo': null,
      'is_own_brand': true,
      'product_count': 4,
    });
    expect(b.isOwnBrand, isTrue);
    expect(b.logo, isNull);
    expect(Brand.fromJson(b.toJson()), b);
  });

  test('variable product detail: options, variants, images', () {
    final d = ProductDetail.fromJson({
      ..._cardJson,
      'type': 'variable',
      'description': 'وصف',
      'breadcrumb': <Object>[],
      'attributes': [
        {
          'key': 'volume',
          'label': 'الحجم',
          'type': 'number',
          'unit': 'ml',
          'value': 50,
          'display': '50 ml',
        },
      ],
      'images': [
        {
          'id': 7,
          'alt_text': null,
          'variant_id': null,
          'color': null,
          'width': 800,
          'height': 800,
          'urls': {'thumb': 't', 'medium': 'm', 'large': 'l'},
        },
      ],
      'variant_options': [
        {
          'key': 'color',
          'label': 'اللون',
          'type': 'color',
          'values': [
            {'value': 'وردي', 'hex': '#FF99AA'},
          ],
        },
      ],
      'variants': [
        {
          'id': 9,
          'options': {'color': 'وردي'},
          'currency': 'SYP',
          'price': '30.00',
          'sale_price': '23.00',
          'current_price': '23.00',
          'discount_percent': 23,
          'stock_status': 'low',
          'stock_left': 2,
          'image_ids': [7],
        },
      ],
    });
    expect(d.variants.single.stockStatus, StockStatus.low);
    expect(d.variants.single.stockLeft, 2);
    expect(d.variantOptions.single.type, OptionType.color);
    expect(d.attributes.single.display, '50 ml');
    expect(d.images.single.urls!.medium, 'm');
    expect(ProductDetail.fromJson(d.toJson()), d);
  });

  test('bundle detail carries its items', () {
    final d = ProductDetail.fromJson({
      ..._cardJson,
      'description': null,
      'breadcrumb': <Object>[],
      'attributes': <Object>[],
      'images': <Object>[],
      'stock_status': 'in_stock',
      'items': [
        {
          'product': {'id': 1, 'slug': 'a', 'name': 'أ', 'image': null},
          'variant_label': '50 ml',
          'quantity': 2,
        },
      ],
    });
    expect(d.stockStatus, StockStatus.inStock);
    expect(d.items.single.quantity, 2);
    expect(d.items.single.variantLabel, '50 ml');
    expect(ProductDetail.fromJson(d.toJson()), d);
  });

  test('unknown enum values degrade instead of throwing', () {
    final c = ProductCard.fromJson({..._cardJson, 'type': 'subscription'});
    expect(c.type, ProductType.simple);
    final v = Variant.fromJson({
      'id': 1,
      'options': <String, String>{},
      'currency': 'SYP',
      'price': '1.00',
      'sale_price': null,
      'current_price': '1.00',
      'discount_percent': null,
      'stock_status': 'preorder',
      'stock_left': null,
      'image_ids': <int>[],
    });
    expect(v.stockStatus, StockStatus.out);
  });

  test('facets parse brands, prices, attributes and options', () {
    final f = Facets.fromJson({
      'brands': [
        {'slug': 'luma', 'name': 'لمى', 'count': 3},
      ],
      'prices': [
        {'currency': 'SYP', 'min': '5000.00', 'max': '90000.00'},
        {'currency': 'USD', 'min': null, 'max': null},
      ],
      'attributes': [
        {
          'key': 'skin_type',
          'label': 'نوع البشرة',
          'type': 'select',
          'values': [
            {'value': 'جافة', 'count': 2},
          ],
        },
        {
          'key': 'spf',
          'label': 'عامل الحماية',
          'type': 'number',
          'unit': null,
          'min': 15,
          'max': 50.5,
        },
      ],
      'options': [
        {
          'key': 'color',
          'label': 'اللون',
          'type': 'color',
          'values': [
            {'value': 'وردي', 'hex': '#FF99AA', 'count': 1},
          ],
        },
      ],
    });
    expect(f.brands.single.count, 3);
    expect(f.prices.last.min, isNull);
    expect(f.attributes.first.values!.single.value, 'جافة');
    expect(f.attributes.last.max, 50.5);
    expect(f.options.single.values.single.hex, '#FF99AA');
    expect(Facets.fromJson(f.toJson()), f);
  });

  test('banner parses link and optional image', () {
    final b = HomeBanner.fromJson({
      'id': 1,
      'title': 'تخفيضات',
      'subtitle': null,
      'image': null,
      'link': {'type': 'sale', 'value': null},
    });
    expect(b.link.type, 'sale');
    expect(b.image, isNull);
    expect(HomeBanner.fromJson(b.toJson()), b);
  });
}
