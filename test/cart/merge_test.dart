import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/features/auth/cubit/auth_form_cubits.dart';
import 'package:lamsa_app/features/auth/data/models/google_auth_result.dart';
import 'package:lamsa_app/features/cart/cubit/cart_cubit.dart';
import 'package:lamsa_app/features/cart/data/guest_codec.dart';

import '../auth/auth_fakes.dart';
import 'cart_fakes.dart';

FakeShop shop() => FakeShop([
      FakeProduct(id: 1, name: 'كريم', stock: 5),
      FakeProduct(id: 2, name: 'عطر', currency: 'USD', price: 850, stock: 3),
      FakeProduct(id: 3, name: 'مخفي', visible: false),
      FakeProduct(id: 4, name: 'نافد', stock: 0),
      FakeProduct(id: 5, name: 'قليل', stock: 2),
    ]);

void main() {
  late CommerceTestKit kit;

  setUp(() => kit = CommerceTestKit(shop: shop()));

  tearDown(() async {
    await kit.cart.close();
    await kit.favorites.close();
    await kit.session.close();
  });

  Future<void> seedGuest({
    List<GuestCartItem> cart = const [],
    List<GuestFavorite> favorites = const [],
  }) async {
    await kit.store.writeCart(cart);
    await kit.store.writeFavorites(favorites);
  }

  group('GuestMergeService', () {
    test('nothing on the device: no backend call at all', () async {
      expect(await kit.mergeService.hasPending(), isFalse);
      expect(await kit.mergeService.mergeIfAny(), isNull);
      expect(kit.api.calls, isEmpty);
    });

    test('favorites are merged first, then the cart; local data is cleared', () async {
      await seedGuest(
        cart: const [GuestCartItem(productId: 1, quantity: 2, slug: 'p1')],
        favorites: const [GuestFavorite(productId: 2, slug: 'p2')],
      );
      expect(await kit.mergeService.hasPending(), isTrue);
      final outcome = await kit.mergeService.mergeIfAny();

      expect(kit.api.calls, ['mergeFavorites', 'mergeCart']);
      expect(kit.api.bodies['mergeFavorites'], [2]);
      expect(outcome!.restored, 1);
      expect(outcome.adjusted, isFalse);
      expect(outcome.cart!.lines.single.quantity, 2);
      expect(await kit.store.readCart(), isEmpty);
      expect(await kit.store.readFavorites(), isEmpty);
      expect(kit.api.favoriteIdsNow, [2]);
    });

    test('only favorites on the device: no cart merge call', () async {
      await seedGuest(favorites: const [GuestFavorite(productId: 1)]);
      final outcome = await kit.mergeService.mergeIfAny();
      expect(kit.api.calls, ['mergeFavorites']);
      expect(outcome!.cart, isNull);
      expect(outcome.restored, 0);
      expect(await kit.store.readFavorites(), isEmpty);
    });

    test('the cart merge never fails for one bad item: it reports each line', () async {
      await seedGuest(
        cart: const [
          GuestCartItem(productId: 1, quantity: 2), // fine
          GuestCartItem(productId: 5, quantity: 9), // capped to stock 2
          GuestCartItem(productId: 4, quantity: 1), // out of stock: skipped
          GuestCartItem(productId: 3, quantity: 1), // hidden: skipped
          GuestCartItem(productId: 999, quantity: 1), // gone: skipped
        ],
      );
      final outcome = (await kit.mergeService.mergeIfAny())!;
      final report = {for (final r in outcome.cart!.lines) r.product.id: r};
      expect(report.keys.toSet(), {1, 5}); // only valid lines reached the account
      expect(outcome.restored, 2); // added + capped, not the 3 skipped
      expect(outcome.adjusted, isTrue); // something was capped or skipped
      expect(report[5]!.quantity, 2);
      // Local data is cleared even though some lines were skipped.
      expect(await kit.store.readCart(), isEmpty);
    });

    test('a merge into an account that already has the line sums it (capped)', () async {
      kit.api.seedStored(1, quantity: 4);
      await seedGuest(cart: const [GuestCartItem(productId: 1, quantity: 3)]);
      final outcome = (await kit.mergeService.mergeIfAny())!;
      expect(outcome.cart!.lines.single.quantity, 5); // 4 + 3 capped to stock 5
      expect(outcome.adjusted, isTrue);
    });

    test('skipped favorites (not found) do not stop the rest or the clearing', () async {
      await seedGuest(
        favorites: const [
          GuestFavorite(productId: 1),
          GuestFavorite(productId: 3), // hidden now
          GuestFavorite(productId: 999), // gone
        ],
      );
      await kit.mergeService.mergeIfAny();
      expect(kit.api.favoriteIdsNow, [1]);
      expect(await kit.store.readFavorites(), isEmpty);
    });

    test('a failed cart merge keeps ALL local data and rethrows', () async {
      await seedGuest(
        cart: const [GuestCartItem(productId: 1, quantity: 2)],
        favorites: const [GuestFavorite(productId: 2)],
      );
      kit.api.failing.add('mergeCart');
      await expectLater(kit.mergeService.mergeIfAny(), throwsA(anything));
      expect(await kit.store.readCart(), isNotEmpty);
      expect(await kit.store.readFavorites(), isNotEmpty);

      // Retry: favorites merge again (harmless), the cart goes through.
      kit.api.failing.clear();
      final outcome = await kit.mergeService.mergeIfAny();
      expect(outcome!.restored, 1);
      expect(kit.api.favoriteIdsNow, [2]); // not duplicated
      expect(await kit.store.readCart(), isEmpty);
    });

    test('a failed favorites merge keeps the data and does not touch the cart', () async {
      await seedGuest(
        cart: const [GuestCartItem(productId: 1, quantity: 2)],
        favorites: const [GuestFavorite(productId: 2)],
      );
      kit.api.failing.add('mergeFavorites');
      await expectLater(kit.mergeService.mergeIfAny(), throwsA(anything));
      expect(kit.api.calls, ['mergeFavorites']);
      expect(await kit.store.readCart(), isNotEmpty);
    });

    test('concurrent triggers share one merge (single-flight)', () async {
      await seedGuest(cart: const [GuestCartItem(productId: 1, quantity: 1)]);
      final results = await Future.wait([
        kit.mergeService.mergeIfAny(),
        kit.mergeService.mergeIfAny(),
        kit.mergeService.mergeIfAny(),
      ]);
      expect(kit.api.count_('mergeCart'), 1);
      expect(results.every((r) => r != null), isTrue);
    });
  });

  group('after sign-in (the real GuestDataMerger)', () {
    test('merges once, switches the app to backend mode and refreshes the hearts', () async {
      await kit.session.restore();
      await pumpEventQueue();
      await kit.cart.add(productId: 1, quantity: 2);
      await kit.favorites.toggle(2);
      expect(kit.api.count_('mergeCart'), 0);

      await kit.session.signIn(testPair());

      expect(kit.api.count_('mergeCart'), 1);
      expect(kit.api.count_('mergeFavorites'), 1);
      expect(kit.merged.single.restored, 1);
      // Backend-backed from now on.
      expect(kit.cart.state.cart.lines.single.id, isNotNull);
      expect(kit.cart.state.count, 2);
      expect(kit.favorites.state.ids, {2});
      expect(await kit.store.readCart(), isEmpty);
      expect(await kit.store.readFavorites(), isEmpty);

      await kit.cart.add(productId: 1, quantity: 1);
      expect(kit.api.calls, contains('addItem')); // not the guest preview path
    });

    test('nothing to merge: no merge calls, but the cart and hearts load from the backend', () async {
      kit.api.seedStored(1, quantity: 3);
      kit.api.seedFavorite(2);
      await kit.session.signIn(testPair());
      expect(kit.api.count_('mergeCart'), 0);
      expect(kit.api.count_('mergeFavorites'), 0);
      expect(kit.merged, isEmpty);
      expect(kit.cart.state.count, 3);
      expect(kit.favorites.state.ids, {2});
    });

    test('the merge is skipped while a temporary password is pending, then runs once after the change', () async {
      await seedGuest(
        cart: const [GuestCartItem(productId: 1, quantity: 2)],
        favorites: const [GuestFavorite(productId: 2)],
      );
      await kit.session.signIn(testPair(user: testUser(mustChange: true)));
      expect(kit.api.count_('mergeCart'), 0);
      expect(kit.api.count_('mergeFavorites'), 0);
      expect(await kit.store.readCart(), isNotEmpty); // untouched
      expect(kit.merged, isEmpty);

      // The password change signs in again with a clean user.
      await kit.session.signIn(testPair(refresh: 'refresh-2'));
      expect(kit.api.count_('mergeCart'), 1);
      expect(kit.api.count_('mergeFavorites'), 1);
      expect(kit.merged.length, 1);
      expect(kit.cart.state.count, 2);
      expect(await kit.store.readCart(), isEmpty);
    });

    test('a failed merge never blocks the sign-in; the next cart load retries it', () async {
      await seedGuest(cart: const [GuestCartItem(productId: 1, quantity: 2)]);
      kit.api.failing.add('mergeCart');
      await kit.session.signIn(testPair());
      expect(kit.session.state.isAuthenticated, isTrue);
      expect(kit.merged, isEmpty);
      expect(await kit.store.readCart(), isNotEmpty); // still on the device

      // The post-sign-in reload already retried once (and failed again);
      // opening the cart tab later retries once more.
      expect(kit.api.count_('mergeCart'), 2);
      kit.api.failing.clear();
      await kit.cart.load(refresh: true);
      expect(kit.api.count_('mergeCart'), 3);
      expect(kit.merged.single.restored, 1);
      expect(kit.cart.state.count, 2);
      expect(await kit.store.readCart(), isEmpty);
    });

    test('Google sign-in merges too', () async {
      await seedGuest(cart: const [GuestCartItem(productId: 1, quantity: 1)]);
      final cubit = GoogleSignInCubit(kit.auth, FakeGoogle(), kit.session);
      addTearDown(cubit.close);
      await cubit.signIn();
      expect(kit.api.count_('mergeCart'), 1);
      expect(kit.cart.state.count, 1);
    });

    test('complete-profile (new Google user) merges too', () async {
      await seedGuest(favorites: const [GuestFavorite(productId: 1)]);
      final cubit = CompleteProfileCubit(kit.auth, 'signup', kit.session);
      addTearDown(cubit.close);
      await cubit.submit(name: 'سارة', countryCode: '+963', phone: '0933123456');
      expect(kit.api.count_('mergeFavorites'), 1);
      expect(kit.favorites.state.ids, {1});
    });

    test('merge data from a Google new-user flow is not lost on the profile step', () async {
      await seedGuest(cart: const [GuestCartItem(productId: 1, quantity: 1)]);
      kit.auth.onGoogle = () async =>
          const GoogleNeedsProfile(signupToken: 'tok', name: 'سارة');
      final cubit = GoogleSignInCubit(kit.auth, FakeGoogle(), kit.session);
      addTearDown(cubit.close);
      final need = await cubit.signIn();
      expect(need, isNotNull);
      // Not signed in yet: nothing merged, nothing cleared.
      expect(kit.api.count_('mergeCart'), 0);
      expect(await kit.store.readCart(), isNotEmpty);
    });

    test('signing out afterwards starts a fresh, empty guest cart', () async {
      await kit.session.restore();
      await pumpEventQueue();
      await kit.cart.add(productId: 1, quantity: 2);
      await kit.session.signIn(testPair());
      await kit.session.signOut();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(await kit.store.readCart(), isEmpty);
      expect(kit.cart.state.count, 0);
      expect(kit.cart.state.status, CartLoad.ready);
    });
  });
}
