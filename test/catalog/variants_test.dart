import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/images/image_urls.dart';
import 'package:lamsa_app/core/money/money_format.dart';
import 'package:lamsa_app/features/catalog/data/banner_link.dart';
import 'package:lamsa_app/features/catalog/data/brand_mark.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';
import 'package:lamsa_app/features/catalog/data/variants.dart';

Variant variant(
  int id,
  Map<String, String> options, {
  String price = '30000.00',
  String? sale,
  StockStatus stock = StockStatus.inStock,
  int? left,
  List<int> images = const [],
  String currency = 'SYP',
}) =>
    Variant(
      id: id,
      options: options,
      currency: currency,
      price: price,
      salePrice: sale,
      currentPrice: sale ?? price,
      stockStatus: stock,
      stockLeft: left,
      imageIds: images,
    );

ProductDetail product(
  List<Variant> variants, {
  List<ProductImage> images = const [],
}) =>
    ProductDetail(
      id: 1,
      slug: 'p',
      name: 'منتج',
      type: ProductType.variable,
      currency: 'SYP',
      price: '30000.00',
      variants: variants,
      images: images,
      variantOptions: const [
        VariantOption(
          key: 'color',
          label: 'اللون',
          type: OptionType.color,
          values: [OptionValue(value: 'وردي'), OptionValue(value: 'أحمر')],
        ),
        VariantOption(
          key: 'size',
          label: 'الحجم',
          type: OptionType.select,
          values: [OptionValue(value: '30'), OptionValue(value: '50')],
        ),
      ],
    );

void main() {
  group('variant selection', () {
    final pinkS = variant(1, {'color': 'وردي', 'size': '30'}, stock: StockStatus.out);
    final pinkL = variant(2, {'color': 'وردي', 'size': '50'});
    final redS = variant(3, {'color': 'أحمر', 'size': '30'}, stock: StockStatus.out);
    final redL = variant(4, {'color': 'أحمر', 'size': '50'});
    final p = product([pinkS, pinkL, redS, redL]);

    test('default is the first variant that is not out of stock', () {
      expect(defaultVariantId(p), 2);
    });

    test('default falls back to the first when everything is out', () {
      final allOut = product([pinkS, redS]);
      expect(defaultVariantId(allOut), 1);
      expect(defaultVariantId(product(const [])), isNull);
    });

    test('picking a color keeps the current size when possible', () {
      expect(pickVariant(p, pinkL, 'color', 'أحمر')!.id, 4);
    });

    test('picking a value falls back to an in-stock variant, then any', () {
      // Red/30 is out; from pink/30 (out) choosing red keeps size 30 first.
      expect(pickVariant(p, pinkS, 'color', 'أحمر')!.id, 3);
      // Unknown value changes nothing.
      expect(pickVariant(p, pinkL, 'color', 'أزرق'), pinkL);
    });

    test('variantForValue is null when no variant has the value', () {
      expect(variantForValue(p, pinkL, 'color', 'أزرق'), isNull);
      expect(variantForValue(p, pinkL, 'size', '30')!.stockStatus, StockStatus.out);
    });
  });

  group('price, stock and images follow the selected variant', () {
    final onSale = variant(1, {'color': 'وردي'}, sale: '20000.00', left: 2, stock: StockStatus.low);
    final regular = variant(2, {'color': 'أحمر'}, price: '45000.00', images: [11, 12]);
    final p = product(
      [onSale, regular],
      images: const [
        ProductImage(id: 10),
        ProductImage(id: 11, variantId: 2),
        ProductImage(id: 12, variantId: 2),
        ProductImage(id: 13, variantId: 1),
      ],
    );

    test('sale variant: struck price, current price and savings', () {
      final v = priceView(p, onSale);
      expect(v.current, '20000.00');
      expect(v.regular, '30000.00');
      expect(v.savings, '10000.00');
      expect(v.currency, 'SYP');
    });

    test('regular variant: no strike and no savings', () {
      final v = priceView(p, regular);
      expect(v.current, '45000.00');
      expect(v.regular, isNull);
      expect(v.savings, isNull);
    });

    test('simple product uses sale/regular prices', () {
      const simple = ProductDetail(
        id: 2,
        slug: 's',
        name: 's',
        type: ProductType.simple,
        currency: 'USD',
        price: '8.50',
        regularPrice: '10.00',
        salePrice: '8.50',
        currentPrice: '8.50',
      );
      final v = priceView(simple, null);
      expect(v.regular, '10.00');
      expect(v.savings, '1.50');
      expect(v.currency, 'USD');
    });

    test('stock: low carries the count, others never expose one', () {
      final low = stockView(p, onSale);
      expect(low.status, StockStatus.low);
      expect(low.left, 2);
      expect(stockView(p, regular).left, isNull);
    });

    test('stock of a simple product comes from the product', () {
      const out = ProductDetail(
        id: 3,
        slug: 'o',
        name: 'o',
        type: ProductType.simple,
        currency: 'SYP',
        price: '1.00',
        inStock: false,
      );
      expect(stockView(out, null).status, StockStatus.out);
    });

    test('images: variant image_ids in order, else the general ones', () {
      expect(imagesFor(p, regular).map((i) => i.id), [11, 12]);
      expect(imagesFor(p, onSale).map((i) => i.id), [10]);
      expect(imagesFor(p, null).map((i) => i.id), [10]);
    });

    test('images: no general ones means every image', () {
      final onlyTied = product(
        [onSale],
        images: const [ProductImage(id: 1, variantId: 1)],
      );
      expect(imagesFor(onlyTied, null).map((i) => i.id), [1]);
    });
  });

  group('money display (never mixes currencies)', () {
    test('SYP has grouping and no decimals; USD trims zeros', () {
      expect(formatAmount('150000.00', 'SYP'), contains('150,000'));
      expect(formatAmount('150000.00', 'SYP'), endsWith('ل.س'));
      expect(formatAmount('8.50', 'USD'), contains('8.5'));
      expect(formatAmount('8.50', 'USD'), endsWith(r'$'));
    });

    test('an unparsable amount is shown as received', () {
      expect(formatAmount('oops', 'SYP'), 'oops SYP');
    });
  });

  group('banner links', () {
    test('map to in-app routes like lamsa-web', () {
      expect(bannerRoute(const BannerLink(type: 'sale')), '/sale');
      expect(bannerRoute(const BannerLink(type: 'new')), '/new');
      expect(
        bannerRoute(const BannerLink(type: 'category', value: 'makeup')),
        '/category/makeup',
      );
      expect(
        bannerRoute(const BannerLink(type: 'product', value: 'a b')),
        '/product/a%20b',
      );
      expect(
        bannerRoute(const BannerLink(type: 'brand', value: 'luma')),
        '/brands/luma',
      );
    });

    test('none, url, unknown and incomplete links are not tappable', () {
      expect(bannerRoute(const BannerLink(type: 'none')), isNull);
      expect(
        bannerRoute(const BannerLink(type: 'url', value: 'https://x.y')),
        isNull,
      );
      expect(bannerRoute(const BannerLink(type: 'order', value: '1')), isNull);
      expect(bannerRoute(const BannerLink(type: 'category')), isNull);
      expect(bannerRoute(const BannerLink(type: 'product', value: ' ')), isNull);
    });

    test('cta mirrors the link type', () {
      expect(bannerCta(const BannerLink(type: 'sale')), BannerCta.sale);
      expect(bannerCta(const BannerLink(type: 'new')), BannerCta.newArrivals);
      expect(bannerCta(const BannerLink(type: 'brand')), BannerCta.discover);
    });
  });

  group('brand mark and images', () {
    test('monogram ignores tashkeel', () {
      expect(monogram('لُمى'), 'ل');
      expect(monogram('  Bella'), 'B');
      expect(monogram(''), '');
    });

    test('brand color is deterministic and from the palette', () {
      expect(brandColor(5), brandColor(5));
      expect(brandColors, contains(brandColor(123)));
    });

    test('image size picked by physical width', () {
      const urls = ImageUrls(thumb: 't', medium: 'm', large: 'l');
      expect(urls.pick(150, devicePixelRatio: 2), 't'); // 300 px
      expect(urls.pick(200, devicePixelRatio: 3), 'm'); // 600 px
      expect(urls.pick(390, devicePixelRatio: 3), 'l'); // 1170 px
    });
  });
}
