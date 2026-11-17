import 'dart:async';

import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/cart/cubit/cart_cubit.dart';
import 'package:lamsa_app/features/cart/data/cart_api.dart';
import 'package:lamsa_app/features/cart/data/guest_codec.dart';
import 'package:lamsa_app/features/cart/data/guest_merge.dart';
import 'package:lamsa_app/features/cart/data/guest_store.dart';
import 'package:lamsa_app/features/cart/data/models/cart_models.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';
import 'package:lamsa_app/features/favorites/cubit/favorites_cubit.dart';
import 'package:lamsa_app/features/favorites/presentation/favorites_screen.dart';

import '../auth/auth_fakes.dart';

/// One variant (or the whole product when [variants] is empty).
class FakeVariant {
  FakeVariant(this.id, this.label, this.price, this.stock, {this.compareAt});

  final int id;
  final String label;
  final int price; // minor units (cents)
  int stock;
  final int? compareAt;
}

class FakeProduct {
  FakeProduct({
    required this.id,
    required this.name,
    this.currency = 'SYP',
    this.price = 10000,
    this.stock = 10,
    this.compareAt,
    this.variants = const [],
    this.visible = true,
  });

  final int id;
  final String name;
  final String currency;
  final int price;
  int stock;
  final int? compareAt;
  final List<FakeVariant> variants;
  bool visible;

  String get slug => 'p$id';
  bool get variable => variants.isNotEmpty;
  bool get inStock =>
      variable ? variants.any((v) => v.stock > 0) : stock > 0;

  ProductCard card() => ProductCard(
        id: id,
        slug: slug,
        name: name,
        type: variable ? ProductType.variable : ProductType.simple,
        currency: currency,
        price: money(price),
        compareAtPrice: compareAt == null ? null : money(compareAt!),
        inStock: inStock,
        brand: const BrandRef(id: 1, name: 'لمى', slug: 'luma'),
      );
}

String money(int cents) =>
    '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

/// A tiny shop that behaves like the backend for the cart rules under test:
/// preview/stored carts with per-line issues, per-currency totals (never
/// combined), stock and per-line limits, merge reports, favorites.
class FakeShop {
  FakeShop(List<FakeProduct> products)
      : products = {for (final p in products) p.id: p};

  final Map<int, FakeProduct> products;
  int maxPerLine = 10;
}

class _Stored {
  _Stored(this.id, this.productId, this.variantId, this.quantity);

  final int id;
  final int productId;
  final int? variantId;
  int quantity;
}

/// Fake of the cart API over a [FakeShop]. Records calls; can be told to fail.
class FakeCartApi implements CartApi {
  FakeCartApi(this.shop);

  final FakeShop shop;
  final calls = <String>[];
  final bodies = <String, Object?>{};
  final _stored = <_Stored>[];
  final _favorites = <int>[]; // newest first
  int _nextId = 1;

  /// Endpoint names that throw a network error.
  final failing = <String>{};
  Object? Function(String endpoint)? errorFor;

  int count_(String name) => calls.where((c) => c == name).length;

  List<int> get favoriteIdsNow => List.of(_favorites);
  List<({int productId, int? variantId, int quantity})> get storedLines => [
        for (final s in _stored)
          (productId: s.productId, variantId: s.variantId, quantity: s.quantity),
      ];

  void seedStored(int productId, {int? variantId, int quantity = 1}) =>
      _stored.add(_Stored(_nextId++, productId, variantId, quantity));

  void seedFavorite(int id) => _favorites.insert(0, id);

  void _enter(String name, [Object? body]) {
    calls.add(name);
    bodies[name] = body;
    final custom = errorFor?.call(name);
    if (custom != null) throw custom;
    if (failing.contains(name)) {
      throw const ApiError(code: ApiError.networkCode, backendMessage: null);
    }
  }

  static ApiError apiError(String code, int status, {Object? details}) =>
      ApiError(code: code, backendMessage: null, status: status, details: details);

  // ---- cart building (the backend's job) ----

  ({int unit, int regular, FakeProduct? product, FakeVariant? variant}) _price(
    int productId,
    int? variantId,
  ) {
    final p = shop.products[productId];
    if (p == null || !p.visible) return (unit: 0, regular: 0, product: null, variant: null);
    if (p.variable) {
      final v = p.variants.where((x) => x.id == variantId).firstOrNull;
      if (v == null) return (unit: 0, regular: 0, product: p, variant: null);
      return (unit: v.price, regular: v.compareAt ?? v.price, product: p, variant: v);
    }
    return (unit: p.price, regular: p.compareAt ?? p.price, product: p, variant: null);
  }

  LineIssue? _issue(int productId, int? variantId, int quantity) {
    final r = _price(productId, variantId);
    if (r.product == null) {
      return const LineIssue(code: 'UNAVAILABLE', message: 'x');
    }
    if (r.product!.variable && r.variant == null) {
      return const LineIssue(code: 'VARIANT_UNAVAILABLE', message: 'x');
    }
    final stock = r.variant?.stock ?? r.product!.stock;
    if (stock <= 0) return const LineIssue(code: 'OUT_OF_STOCK', message: 'x');
    if (quantity > stock) {
      return LineIssue(code: 'INSUFFICIENT_STOCK', message: 'x', available: stock);
    }
    if (quantity > shop.maxPerLine) {
      return LineIssue(code: 'QUANTITY_LIMIT_EXCEEDED', message: 'x', max: shop.maxPerLine);
    }
    return null;
  }

  CartLine _line({
    required int productId,
    required int? variantId,
    required int quantity,
    int? id,
  }) {
    final r = _price(productId, variantId);
    final issue = _issue(productId, variantId, quantity);
    final p = r.product;
    return CartLine(
      id: id,
      key: id == null ? cartKey(productId, variantId) : null,
      quantity: quantity,
      product: CartProduct(
        id: productId,
        slug: p?.slug ?? '',
        name: p?.name ?? '',
        type: p?.variable == true ? 'variable' : 'simple',
        brand: p == null ? null : const CartBrand(name: 'لمى', slug: 'luma'),
      ),
      variant: r.variant == null
          ? null
          : CartVariant(id: r.variant!.id, label: r.variant!.label),
      currency: p?.currency ?? 'SYP',
      unitPrice: money(r.unit),
      regularPrice: money(r.regular),
      compareAtPrice: r.regular > r.unit ? money(r.regular) : null,
      lineTotal: issue == null ? money(r.unit * quantity) : '0.00',
      stockStatus: issue == null ? 'in_stock' : 'out',
      stockLeft: issue?.available,
      issue: issue,
    );
  }

  Cart _cart(List<CartLine> lines) {
    // One bucket per currency: never combined.
    final sub = <String, int>{};
    final sav = <String, int>{};
    var items = 0;
    var issues = 0;
    for (final l in lines) {
      if (l.issue != null) {
        issues++;
        continue;
      }
      items += l.quantity;
      final unit = _cents(l.unitPrice);
      final reg = _cents(l.regularPrice);
      sub[l.currency] = (sub[l.currency] ?? 0) + unit * l.quantity;
      if (reg > unit) sav[l.currency] = (sav[l.currency] ?? 0) + (reg - unit) * l.quantity;
    }
    List<CurrencyAmount> amounts(Map<String, int> m) => [
          for (final c in ['SYP', 'USD'])
            if (m.containsKey(c)) CurrencyAmount(currency: c, amount: money(m[c]!)),
        ];
    return Cart(
      lines: lines,
      itemsCount: items,
      linesCount: lines.length,
      subtotals: amounts(sub),
      savings: amounts(sav),
      totals: amounts(sub),
      canCheckout: lines.isNotEmpty && issues == 0,
      issuesCount: issues,
    );
  }

  static int _cents(String amount) {
    final parts = amount.split('.');
    return int.parse(parts[0]) * 100 + int.parse(parts[1].padRight(2, '0').substring(0, 2));
  }

  Cart _storedCart() => _cart([
        for (final s in _stored)
          _line(productId: s.productId, variantId: s.variantId, quantity: s.quantity, id: s.id),
      ]);

  // ---- CartApi ----

  @override
  Future<Cart> preview(List<GuestCartItem> items) async {
    _enter('preview', items);
    return _cart([
      for (final i in items)
        _line(productId: i.productId, variantId: i.variantId, quantity: i.quantity),
    ]);
  }

  @override
  Future<Cart> cart({String? governorate, String? deliveryMethodCode}) async {
    _enter('cart');
    return _storedCart();
  }

  @override
  Future<int> count() async {
    _enter('count');
    return _storedCart().itemsCount;
  }

  void _validateAdd(int productId, int? variantId, int total) {
    final r = _price(productId, variantId);
    if (r.product == null) throw apiError('PRODUCT_NOT_FOUND', 404);
    if (r.product!.variable && variantId == null) throw apiError('VARIANT_REQUIRED', 422);
    final stock = r.variant?.stock ?? r.product!.stock;
    if (stock <= 0) throw apiError('OUT_OF_STOCK', 409);
    if (total > stock) {
      throw apiError('INSUFFICIENT_STOCK', 409, details: {'available': stock});
    }
    if (total > shop.maxPerLine) {
      throw apiError('QUANTITY_LIMIT_EXCEEDED', 422, details: {'max': shop.maxPerLine});
    }
  }

  @override
  Future<Cart> addItem({required int productId, int? variantId, int quantity = 1}) async {
    _enter('addItem', {'product_id': productId, 'variant_id': variantId, 'quantity': quantity});
    final existing = _stored
        .where((s) => s.productId == productId && s.variantId == variantId)
        .firstOrNull;
    _validateAdd(productId, variantId, (existing?.quantity ?? 0) + quantity);
    if (existing != null) {
      existing.quantity += quantity;
    } else {
      _stored.add(_Stored(_nextId++, productId, variantId, quantity));
    }
    return _storedCart();
  }

  @override
  Future<Cart> updateItem(int itemId, {required int quantity}) async {
    _enter('updateItem', {'id': itemId, 'quantity': quantity});
    final s = _stored.where((x) => x.id == itemId).firstOrNull;
    if (s == null) throw apiError('CART_ITEM_NOT_FOUND', 404);
    _validateAdd(s.productId, s.variantId, quantity);
    s.quantity = quantity;
    return _storedCart();
  }

  @override
  Future<Cart> removeItem(int itemId) async {
    _enter('removeItem', itemId);
    _stored.removeWhere((s) => s.id == itemId);
    return _storedCart();
  }

  @override
  Future<Cart> clear() async {
    _enter('clear');
    _stored.clear();
    return _storedCart();
  }

  @override
  Future<Cart> resolveIssues() async {
    _enter('resolveIssues');
    final notices = <CartNotice>[];
    for (final s in List.of(_stored)) {
      final issue = _issue(s.productId, s.variantId, s.quantity);
      if (issue == null) continue;
      if (const {'UNAVAILABLE', 'VARIANT_UNAVAILABLE', 'OUT_OF_STOCK'}.contains(issue.code)) {
        _stored.remove(s);
        notices.add(const CartNotice(code: 'LINE_REMOVED', message: 'x'));
      } else {
        s.quantity = [issue.available ?? s.quantity, issue.max ?? s.quantity]
            .reduce((a, b) => a < b ? a : b);
        notices.add(const CartNotice(code: 'QUANTITY_CAPPED', message: 'x'));
      }
    }
    return Cart(
      lines: _storedCart().lines,
      itemsCount: _storedCart().itemsCount,
      subtotals: _storedCart().subtotals,
      totals: _storedCart().totals,
      notices: notices,
    );
  }

  @override
  Future<CartMergeResult> mergeCart(List<GuestCartItem> items) async {
    _enter('mergeCart', items);
    final report = <MergeReportItem>[];
    for (final (index, i) in items.indexed) {
      MergeReportItem rep(String status, {String? reason, int? q}) => MergeReportItem(
            index: index,
            productId: i.productId,
            variantId: i.variantId,
            status: status,
            reason: reason,
            quantity: q ?? i.quantity,
          );
      final r = _price(i.productId, i.variantId);
      if (r.product == null) {
        report.add(rep('skipped', reason: 'PRODUCT_NOT_FOUND', q: 0));
        continue;
      }
      if (r.product!.variable && r.variant == null) {
        report.add(rep('skipped', reason: 'VARIANT_REQUIRED', q: 0));
        continue;
      }
      final stock = r.variant?.stock ?? r.product!.stock;
      if (stock <= 0) {
        report.add(rep('skipped', reason: 'OUT_OF_STOCK', q: 0));
        continue;
      }
      final existing = _stored
          .where((s) => s.productId == i.productId && s.variantId == i.variantId)
          .firstOrNull;
      final want = (existing?.quantity ?? 0) + i.quantity;
      final cap = [stock, shop.maxPerLine].reduce((a, b) => a < b ? a : b);
      final got = want > cap ? cap : want;
      if (existing != null) {
        existing.quantity = got;
      } else {
        _stored.add(_Stored(_nextId++, i.productId, i.variantId, got));
      }
      report.add(
        got < want
            ? rep('capped', reason: stock < want ? 'INSUFFICIENT_STOCK' : 'QUANTITY_LIMIT_EXCEEDED', q: got)
            : rep(existing != null ? 'merged' : 'added', q: got),
      );
    }
    return CartMergeResult(cart: _storedCart(), report: report);
  }

  // ---- favorites ----

  @override
  Future<List<int>> favoriteIds() async {
    _enter('favoriteIds');
    return List.of(_favorites);
  }

  @override
  Future<ProductPage> favorites({int page = 1, int pageSize = 24}) async {
    _enter('favorites', page);
    final visible = [
      for (final id in _favorites)
        if (shop.products[id]?.visible == true) shop.products[id]!.card(),
    ];
    final from = (page - 1) * pageSize;
    final items = visible.skip(from).take(pageSize).toList();
    return ProductPage(items: items, page: page, pageSize: pageSize, total: visible.length);
  }

  @override
  Future<void> addFavorite(int productId) async {
    _enter('addFavorite', productId);
    if (shop.products[productId]?.visible != true) {
      throw apiError('PRODUCT_NOT_FOUND', 404);
    }
    _favorites
      ..remove(productId)
      ..insert(0, productId);
  }

  @override
  Future<void> removeFavorite(int productId) async {
    _enter('removeFavorite', productId);
    _favorites.remove(productId);
  }

  @override
  Future<FavoritesMergeResult> mergeFavorites(List<int> productIds) async {
    _enter('mergeFavorites', productIds);
    var added = 0;
    final skipped = <SkippedFavorite>[];
    for (final id in productIds) {
      if (shop.products[id]?.visible != true) {
        skipped.add(SkippedFavorite(productId: id, reason: 'PRODUCT_NOT_FOUND'));
      } else {
        if (!_favorites.contains(id)) _favorites.insert(0, id);
        added++;
      }
    }
    return FavoritesMergeResult(added: added, skipped: skipped);
  }

  @override
  Future<Cart> moveToCart(int productId, {int? variantId, int quantity = 1}) async {
    _enter('moveToCart', productId);
    final p = shop.products[productId];
    var variant = variantId;
    if (p != null && p.variable && variant == null) {
      variant = p.variants.where((v) => v.stock > 0).firstOrNull?.id;
    }
    final cart = await addItem(productId: productId, variantId: variant, quantity: quantity);
    _favorites.remove(productId);
    return cart;
  }
}

/// Everything commerce-related, wired like production but over fakes.
class CommerceTestKit {
  CommerceTestKit({
    required this.shop,
    GuestStore? store,
    FakeAuthApi? auth,
    void Function(MergeOutcome)? onMergedExtra,
  })  : api = FakeCartApi(shop),
        store = store ?? MemoryGuestStore(),
        auth = auth ?? FakeAuthApi() {
    merged = <MergeOutcome>[];
    void record(MergeOutcome o) {
      merged.add(o);
      onMergedExtra?.call(o);
    }

    mergeService = GuestMergeService(api, this.store);
    merger = CommerceMerger(
      mergeService,
      onMerged: record,
      onSignedIn: (outcome) async {
        final c = outcome?.cart;
        if (c != null) {
          cart.setServerCart(c);
        } else {
          await cart.load(refresh: true);
        }
        await favorites.load();
      },
    );
    session = makeSession(api: this.auth, merger: merger);
    cart = CartCubit(
      api: api,
      store: this.store,
      session: session,
      merge: mergeService,
      onMerged: record,
    );
    favorites = FavoritesCubit(
      api: api,
      store: this.store,
      session: session,
      cart: cart,
      lookup: lookup,
      detail: detail,
    );
  }

  final FakeShop shop;
  final FakeCartApi api;
  final GuestStore store;
  final FakeAuthApi auth;
  late final List<MergeOutcome> merged;
  late final GuestMergeService mergeService;
  late final CommerceMerger merger;
  late final SessionCubit session;
  late final CartCubit cart;
  late final FavoritesCubit favorites;

  int lookups = 0;

  /// While set, guest product lookups wait for it (to observe optimistic UI).
  Completer<void>? lookupGate;

  Future<List<ProductCard>> lookup(List<int> ids) async {
    lookups++;
    if (lookupGate != null) await lookupGate!.future;
    return [
      for (final id in ids)
        if (shop.products[id]?.visible == true) shop.products[id]!.card(),
    ];
  }

  Future<ProductDetail> detail(String slug) async {
    final p = shop.products.values.firstWhere((x) => x.slug == slug);
    return ProductDetail(
      id: p.id,
      slug: p.slug,
      name: p.name,
      type: p.variable ? ProductType.variable : ProductType.simple,
      currency: p.currency,
      price: money(p.price),
      variants: [
        for (final v in p.variants)
          Variant(
            id: v.id,
            options: const {},
            currency: p.currency,
            price: money(v.price),
            currentPrice: money(v.price),
            stockStatus: v.stock > 0 ? StockStatus.inStock : StockStatus.out,
          ),
      ],
    );
  }

  /// Replaces the favorites screen's collaborators (e.g. a failing lookup).
  FavoritesDeps? favoritesDepsOverride;

  FavoritesDeps get favoritesDeps =>
      favoritesDepsOverride ?? FavoritesDeps(api: api, store: store, lookup: lookup);
}
