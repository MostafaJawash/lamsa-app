import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/features/cart/data/guest_codec.dart';
import 'package:lamsa_app/features/cart/data/guest_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  group('cart codec', () {
    test('round-trips, with a missing variant stored as 0', () {
      const items = [
        GuestCartItem(productId: 5, quantity: 2, slug: 'a'),
        GuestCartItem(productId: 6, variantId: 9, quantity: 1, slug: 'b'),
      ];
      final raw = encodeCart(items);
      expect(raw, contains('[5,0,2,"a"]'));
      expect(decodeCart(raw), items);
    });

    test('unreadable, wrong-version or non-list data decodes to an empty cart', () {
      expect(decodeCart(null), isEmpty);
      expect(decodeCart(''), isEmpty);
      expect(decodeCart('not json'), isEmpty);
      expect(decodeCart('{"v":2,"items":[[1,0,1,"a"]]}'), isEmpty);
      expect(decodeCart('{"v":1,"items":"x"}'), isEmpty);
      expect(decodeCart('[1,2,3]'), isEmpty);
    });

    test('invalid entries are dropped, valid ones kept', () {
      const raw = '{"v":1,"items":['
          '[1,0,2,"ok"],'
          '[0,0,1,"zero-id"],'
          '[2,0,0,"zero-qty"],'
          '[3,-1,1,"neg-variant"],'
          '["x",0,1,"bad-id"],'
          '[4,0,1,"bad\\u0001slug"],'
          '[5],'
          '"junk",'
          '[6,0,1.5,"float"],'
          '[7,8,3,"v"]'
          ']}';
      expect(decodeCart(raw), const [
        GuestCartItem(productId: 1, quantity: 2, slug: 'ok'),
        GuestCartItem(productId: 7, variantId: 8, quantity: 3, slug: 'v'),
      ]);
    });

    test('duplicate lines merge, quantity capped at 99', () {
      const raw = '{"v":1,"items":[[1,0,60,"a"],[1,0,70,"a"],[1,2,1,"a"]]}';
      final items = decodeCart(raw);
      expect(items.length, 2);
      expect(items.first.quantity, GuestLimits.maxQuantity);
    });

    test('at most 50 lines are kept', () {
      final raw = encodeCart([
        for (var i = 1; i <= 60; i++) GuestCartItem(productId: i, quantity: 1),
      ]);
      final items = decodeCart(raw);
      expect(items.length, GuestLimits.cartLines);
      expect(items.first.productId, 1);
    });

    test('setCartQuantity appends, updates in place and clamps', () {
      const base = [GuestCartItem(productId: 1, quantity: 2, slug: 'a')];
      final added = setCartQuantity(
        base,
        const GuestCartItem(productId: 2, quantity: 1, slug: 'b'),
        500,
      );
      expect(added.last.quantity, 99);
      expect(added.length, 2);
      final updated = setCartQuantity(
        base,
        const GuestCartItem(productId: 1, quantity: 1),
        0,
      );
      expect(updated.single.quantity, 1); // min 1
      expect(updated.single.slug, 'a'); // keeps the known slug
    });

    test('remove, quantity and keys', () {
      const items = [
        GuestCartItem(productId: 1, quantity: 2),
        GuestCartItem(productId: 1, variantId: 4, quantity: 3),
      ];
      expect(cartQuantity(items), 5);
      expect(removeCartLine(items, '1:0').single.variantId, 4);
      expect(items.last.key, '1:4');
      expect(parseCartKey('1:4'), (productId: 1, variantId: 4));
      expect(parseCartKey('9:0'), (productId: 9, variantId: null));
      expect(parseCartKey('x'), isNull);
      expect(parseCartKey('0:0'), isNull);
    });
  });

  group('favorites codec', () {
    test('round-trips and drops duplicates and junk', () {
      const raw = '{"v":1,"items":[[3,"c"],[3,"dup"],[0,"z"],[4,"d"],"x"]}';
      expect(decodeFavorites(raw), const [
        GuestFavorite(productId: 3, slug: 'c'),
        GuestFavorite(productId: 4, slug: 'd'),
      ]);
      final items = decodeFavorites(raw);
      expect(decodeFavorites(encodeFavorites(items)), items);
    });

    test('over the limit the newest 200 are kept', () {
      final raw = encodeFavorites([
        for (var i = 1; i <= 210; i++) GuestFavorite(productId: i),
      ]);
      final items = decodeFavorites(raw);
      expect(items.length, GuestLimits.favorites);
      expect(items.first.productId, 11);
      expect(items.last.productId, 210);
    });
  });

  group('SharedPrefsGuestStore', () {
    late SharedPrefsGuestStore store;

    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      store = SharedPrefsGuestStore();
    });

    test('starts empty', () async {
      expect(await store.readCart(), isEmpty);
      expect(await store.readFavorites(), isEmpty);
    });

    test('persists the cart and favorites separately', () async {
      const cart = [GuestCartItem(productId: 1, variantId: 2, quantity: 3, slug: 's')];
      const favs = [GuestFavorite(productId: 9, slug: 'f')];
      expect(await store.writeCart(cart), isTrue);
      expect(await store.writeFavorites(favs), isTrue);
      // A new store instance (a new launch) reads the same data.
      final again = SharedPrefsGuestStore();
      expect(await again.readCart(), cart);
      expect(await again.readFavorites(), favs);
    });

    test('writing an empty list removes the key; clearAll empties both', () async {
      await store.writeCart(const [GuestCartItem(productId: 1, quantity: 1)]);
      await store.writeFavorites(const [GuestFavorite(productId: 1)]);
      await store.writeCart(const []);
      final prefs = SharedPreferencesAsync();
      expect(await prefs.getString(SharedPrefsGuestStore.cartKeyName), isNull);
      expect(await prefs.getString(SharedPrefsGuestStore.favoritesKeyName), isNotNull);
      await store.clearAll();
      expect(await store.readFavorites(), isEmpty);
    });

    test('corrupted stored data reads as empty', () async {
      await SharedPreferencesAsync().setString(SharedPrefsGuestStore.cartKeyName, '{{{');
      expect(await store.readCart(), isEmpty);
    });
  });
}
