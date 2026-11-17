import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/features/cart/data/guest_codec.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';
import 'package:lamsa_app/features/favorites/cubit/favorites_cubit.dart';

import '../auth/auth_fakes.dart';
import 'cart_fakes.dart';

void main() {
  late CommerceTestKit kit;

  setUp(() {
    kit = CommerceTestKit(
      shop: FakeShop([
        FakeProduct(id: 1, name: 'كريم', stock: 5),
        FakeProduct(id: 2, name: 'عطر', stock: 3),
        FakeProduct(id: 3, name: 'مخفي', visible: false),
        FakeProduct(id: 4, name: 'نافد', stock: 0),
        FakeProduct(
          id: 5,
          name: 'أحمر شفاه',
          variants: [FakeVariant(51, 'بني', 20000, 0), FakeVariant(52, 'وردي', 20000, 2)],
        ),
      ]),
    );
  });

  tearDown(() async {
    await kit.cart.close();
    await kit.favorites.close();
    await kit.session.close();
  });

  Future<void> guest() async {
    await kit.session.restore();
    await pumpEventQueue(); // let the cubits see the session change
  }

  Future<void> signIn() async {
    await kit.session.signIn(testPair());
    await kit.favorites.load();
  }

  group('guest favorites (on the device)', () {
    test('adding validates the product with one lookup and saves id + slug', () async {
      await guest();
      final r = await kit.favorites.toggle(1);
      expect(r.ok, isTrue);
      expect(r.on, isTrue);
      expect(kit.lookups, 1);
      expect(kit.favorites.state.ids, {1});
      expect(await kit.store.readFavorites(), const [GuestFavorite(productId: 1, slug: 'p1')]);
      expect(kit.api.calls, isEmpty); // nothing sent to the backend
    });

    test('toggling again removes it (no lookup)', () async {
      await guest();
      await kit.favorites.toggle(1);
      final r = await kit.favorites.toggle(1);
      expect(r.ok, isTrue);
      expect(r.on, isFalse);
      expect(kit.lookups, 1);
      expect(kit.favorites.state.ids, isEmpty);
      expect(await kit.store.readFavorites(), isEmpty);
    });

    test('the heart is on immediately, before the validation answers (optimistic)', () async {
      await guest();
      final slow = Completer<void>();
      final slowKit = CommerceTestKit(shop: kit.shop);
      addTearDown(slowKit.session.close);
      // Replace the lookup of a kit with a slow one via a fresh cubit.
      final cubit = FavoritesCubit(
        api: slowKit.api,
        store: slowKit.store,
        session: slowKit.session,
        cart: slowKit.cart,
        lookup: (ids) async {
          await slow.future;
          return slowKit.lookup(ids);
        },
        detail: slowKit.detail,
      );
      addTearDown(cubit.close);
      await slowKit.session.restore();
      await pumpEventQueue();
      final future = cubit.toggle(1);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.ids, {1}); // on, though not confirmed yet
      slow.complete();
      expect((await future).ok, isTrue);
      expect(cubit.state.ids, {1});
    });

    test('a hidden product is refused and the heart rolls back', () async {
      await guest();
      final r = await kit.favorites.toggle(3);
      expect(r.ok, isFalse);
      expect(r.error!.code, 'PRODUCT_NOT_FOUND');
      expect(kit.favorites.state.ids, isEmpty);
      expect(await kit.store.readFavorites(), isEmpty);
    });

    test('a failing validation rolls back', () async {
      await guest();
      final failing = FavoritesCubit(
        api: kit.api,
        store: kit.store,
        session: kit.session,
        cart: kit.cart,
        lookup: (ids) async => throw StateError('offline'),
        detail: kit.detail,
      );
      addTearDown(failing.close);
      final r = await failing.toggle(1);
      expect(r.ok, isFalse);
      expect(failing.state.ids, isEmpty);
    });

    test('at 200 favorites the add is refused with the limit', () async {
      await kit.store.writeFavorites([
        for (var i = 100; i < 300; i++) GuestFavorite(productId: i),
      ]);
      await guest();
      await kit.favorites.load();
      expect(kit.favorites.state.ids.length, 200);
      final r = await kit.favorites.toggle(1);
      expect(r.ok, isFalse);
      expect(r.error!.code, 'FAVORITES_LIMIT_REACHED');
      expect(r.error!.max, 200);
      expect(kit.favorites.state.ids, isNot(contains(1)));
    });

    test('a second tap while one is in flight is ignored', () async {
      await guest();
      final a = kit.favorites.toggle(1);
      final b = await kit.favorites.toggle(1);
      expect(b, FavoriteResult.ignored);
      expect((await a).ok, isTrue);
      expect(kit.favorites.state.ids, {1});
    });

    test('adds bump the version (an open list is stale); removals do not', () async {
      await guest();
      final v0 = kit.favorites.state.version;
      await kit.favorites.toggle(1);
      final v1 = kit.favorites.state.version;
      expect(v1, greaterThan(v0));
      await kit.favorites.toggle(1);
      expect(kit.favorites.state.version, v1);
    });

    test('load reads the ids from the device', () async {
      await kit.store.writeFavorites(const [
        GuestFavorite(productId: 2, slug: 'p2'),
        GuestFavorite(productId: 1, slug: 'p1'),
      ]);
      await guest();
      await kit.favorites.load();
      expect(kit.favorites.state.ids, {1, 2});
      expect(kit.favorites.state.ready, isTrue);
    });
  });

  group('signed-in favorites (backend)', () {
    test('hearts are filled from /favorites/ids', () async {
      kit.api.seedFavorite(2);
      kit.api.seedFavorite(1);
      await signIn();
      expect(kit.favorites.state.ids, {1, 2});
      expect(kit.api.calls, contains('favoriteIds'));
    });

    test('add and remove call PUT / DELETE and never touch device storage', () async {
      await signIn();
      expect((await kit.favorites.toggle(1)).ok, isTrue);
      expect(kit.api.favoriteIdsNow, [1]);
      expect(kit.lookups, 0); // the backend validates (404 for hidden)
      expect((await kit.favorites.toggle(1)).on, isFalse);
      expect(kit.api.favoriteIdsNow, isEmpty);
      expect(await kit.store.readFavorites(), isEmpty);
    });

    test('a failed add rolls back; a hidden product is a 404 message', () async {
      await signIn();
      kit.api.failing.add('addFavorite');
      final r = await kit.favorites.toggle(1);
      expect(r.ok, isFalse);
      expect(kit.favorites.state.ids, isEmpty);

      kit.api.failing.clear();
      final hidden = await kit.favorites.toggle(3);
      expect(hidden.error!.code, 'PRODUCT_NOT_FOUND');
      expect(kit.favorites.state.ids, isEmpty);
    });

    test('a failed remove brings the heart back', () async {
      kit.api.seedFavorite(1);
      await signIn();
      kit.api.failing.add('removeFavorite');
      final r = await kit.favorites.toggle(1);
      expect(r.ok, isFalse);
      expect(kit.favorites.state.ids, {1});
    });
  });

  group('move to cart', () {
    Future<ProductCard> card(int id) async =>
        (await kit.lookup([id])).first;

    test('guest: a simple product goes to the guest cart and leaves the favorites', () async {
      await guest();
      await kit.favorites.toggle(1);
      final r = await kit.favorites.moveToCart(await card(1));
      expect(r.ok, isTrue);
      expect(kit.favorites.state.ids, isEmpty);
      expect(await kit.store.readFavorites(), isEmpty);
      expect((await kit.store.readCart()).single.productId, 1);
      expect(kit.cart.state.count, 1);
    });

    test('guest: a variable product uses its first variant in stock', () async {
      await guest();
      await kit.favorites.toggle(5);
      final r = await kit.favorites.moveToCart(await card(5));
      expect(r.ok, isTrue);
      expect((await kit.store.readCart()).single.variantId, 52); // 51 is sold out
    });

    test('guest: out of stock is refused and the favorite stays', () async {
      await guest();
      await kit.favorites.toggle(4);
      final r = await kit.favorites.moveToCart(await card(4));
      expect(r.ok, isFalse);
      expect(r.error!.code, 'OUT_OF_STOCK');
      expect(kit.favorites.state.ids, {4});
      expect(await kit.store.readCart(), isEmpty);
    });

    test('guest: if the cart refuses the add, the favorite stays', () async {
      await guest();
      await kit.favorites.toggle(1);
      kit.shop.products[1]!.stock = 1;
      await kit.cart.add(productId: 1, quantity: 1);
      final r = await kit.favorites.moveToCart(await card(1)); // would be 2 > stock 1
      expect(r.ok, isFalse);
      expect(r.error!.code, 'INSUFFICIENT_STOCK');
      expect(kit.favorites.state.ids, {1});
    });

    test('signed in: POST move-to-cart, the cart is replaced, the heart goes', () async {
      kit.api.seedFavorite(1);
      await signIn();
      await kit.cart.load(refresh: true);
      final r = await kit.favorites.moveToCart(await card(1));
      expect(r.ok, isTrue);
      expect(kit.api.calls, contains('moveToCart'));
      expect(kit.favorites.state.ids, isEmpty);
      expect(kit.cart.state.count, 1);
    });

    test('signed in: if the add fails the favorite stays', () async {
      kit.api.seedFavorite(4);
      await signIn();
      final r = await kit.favorites.moveToCart(await card(4));
      expect(r.ok, isFalse);
      expect(r.error!.code, 'OUT_OF_STOCK');
      expect(kit.favorites.state.ids, {4});
      expect(kit.api.favoriteIdsNow, [4]);
    });
  });
}
