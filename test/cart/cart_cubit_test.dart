import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/cart/cubit/cart_cubit.dart';
import 'package:lamsa_app/features/cart/data/guest_codec.dart';
import 'package:lamsa_app/features/cart/data/guest_store.dart';

import '../auth/auth_fakes.dart';
import 'cart_fakes.dart';

FakeShop shop() => FakeShop([
      FakeProduct(id: 1, name: 'كريم', stock: 5),
      FakeProduct(id: 2, name: 'عطر', currency: 'USD', price: 850, compareAt: 1000, stock: 3),
      FakeProduct(
        id: 3,
        name: 'أحمر شفاه',
        variants: [
          FakeVariant(31, 'وردي', 20000, 2),
          FakeVariant(32, 'بني', 20000, 0),
        ],
      ),
      FakeProduct(id: 4, name: 'نافد', stock: 0),
      FakeProduct(id: 5, name: 'مخزون كبير', stock: 50),
    ]);

void main() {
  late CommerceTestKit kit;

  setUp(() => kit = CommerceTestKit(shop: shop()));

  tearDown(() async {
    await kit.cart.close();
    await kit.favorites.close();
    await kit.session.close();
  });

  Future<void> guest() async {
    await kit.session.restore(); // no tokens: a guest
    await pumpEventQueue(); // let the cubits see the session change
  }

  Future<void> signIn() async {
    await kit.session.signIn(testPair());
    await kit.cart.load(refresh: true);
  }

  group('guest cart (validated by /cart/preview)', () {
    test('an empty guest cart needs no network', () async {
      await guest();
      await kit.cart.load();
      expect(kit.cart.state.status, CartLoad.ready);
      expect(kit.cart.state.cart.lines, isEmpty);
      expect(kit.api.calls, isEmpty);
    });

    test('add: the preview of the cart WITH the change decides, then it is saved', () async {
      await guest();
      final error = await kit.cart.add(productId: 1, quantity: 2, slug: 'p1');
      expect(error, isNull);
      expect(kit.api.calls, ['preview']);
      expect(kit.api.bodies['preview'], const [
        GuestCartItem(productId: 1, quantity: 2, slug: 'p1'),
      ]);
      expect(await kit.store.readCart(), const [
        GuestCartItem(productId: 1, quantity: 2, slug: 'p1'),
      ]);
      expect(kit.cart.state.count, 2);
      expect(kit.cart.state.cart.lines.single.quantity, 2);
    });

    test('adding the same line again accumulates', () async {
      await guest();
      await kit.cart.add(productId: 1, quantity: 2);
      await kit.cart.add(productId: 1, quantity: 1);
      expect((await kit.store.readCart()).single.quantity, 3);
      expect(kit.cart.state.count, 3);
    });

    test('too many for the stock: INSUFFICIENT_STOCK with what is left, nothing saved', () async {
      await guest();
      final error = await kit.cart.add(productId: 1, quantity: 6);
      expect(error!.code, 'INSUFFICIENT_STOCK');
      expect(error.available, 5);
      expect(error.text, Strings.toastLow(5));
      expect(await kit.store.readCart(), isEmpty);
      expect(kit.cart.state.count, 0);
    });

    test('accumulating past the stock is refused too', () async {
      await guest();
      await kit.cart.add(productId: 1, quantity: 4);
      final error = await kit.cart.add(productId: 1, quantity: 2);
      expect(error!.code, 'INSUFFICIENT_STOCK');
      expect((await kit.store.readCart()).single.quantity, 4);
    });

    test('out of stock, unknown product, variants and the per-line limit', () async {
      await guest();
      expect((await kit.cart.add(productId: 4, quantity: 1))!.code, 'OUT_OF_STOCK');
      expect((await kit.cart.add(productId: 999, quantity: 1))!.code, 'PRODUCT_NOT_FOUND');
      // Variable product without a variant, and a variant that is gone.
      expect((await kit.cart.add(productId: 3, quantity: 1))!.code, 'VARIANT_REQUIRED');
      expect(
        (await kit.cart.add(productId: 3, variantId: 999, quantity: 1))!.code,
        'VARIANT_NOT_FOUND',
      );
      expect(
        (await kit.cart.add(productId: 3, variantId: 32, quantity: 1))!.code,
        'OUT_OF_STOCK',
      );
      final limit = await kit.cart.add(productId: 5, quantity: 11);
      expect(limit!.code, 'QUANTITY_LIMIT_EXCEEDED');
      expect(limit.max, 10);
      expect(limit.text, Strings.toastMax(10));
      expect(await kit.store.readCart(), isEmpty);
    });

    test('a variant can be added and shows its label', () async {
      await guest();
      expect(await kit.cart.add(productId: 3, variantId: 31, quantity: 1), isNull);
      expect(kit.cart.state.cart.lines.single.variant!.label, 'وردي');
    });

    test('at 50 lines a new line is refused without calling the backend', () async {
      await kit.store.writeCart([
        for (var i = 1; i <= 50; i++) GuestCartItem(productId: 100 + i, quantity: 1),
      ]);
      await guest();
      await kit.cart.load(); // let the launch load settle first
      kit.api.calls.clear();
      final error = await kit.cart.add(productId: 1, quantity: 1);
      expect(error!.code, 'CART_LIMIT_REACHED');
      expect(error.max, 50);
      expect(kit.api.calls, isEmpty);
    });

    test('a failed local write is reported and the count does not move', () async {
      await guest();
      (kit.store as MemoryGuestStore).failWrites = true;
      final error = await kit.cart.add(productId: 1, quantity: 1);
      expect(error, isNotNull);
      expect(kit.cart.state.count, 0);
    });

    test('a backend failure on add is surfaced and nothing is saved', () async {
      await guest();
      kit.api.failing.add('preview');
      final error = await kit.cart.add(productId: 1, quantity: 1);
      expect(error!.code, 'NETWORK_ERROR');
      expect(await kit.store.readCart(), isEmpty);
    });

    test('load shows the stored guest cart with live backend data', () async {
      await kit.store.writeCart(const [GuestCartItem(productId: 1, quantity: 2, slug: 'p1')]);
      await guest();
      await kit.cart.load();
      expect(kit.cart.state.count, 2);
      expect(kit.cart.state.cart.lines.single.unitPrice, '100.00');
      expect(kit.cart.state.cart.lines.single.lineTotal, '200.00');
    });

    test('a failing preview on load is a failed state; the badge stays local', () async {
      await kit.store.writeCart(const [GuestCartItem(productId: 1, quantity: 2)]);
      await guest();
      kit.api.failing.add('preview');
      await kit.cart.load();
      expect(kit.cart.state.status, CartLoad.failed);
      expect(kit.cart.state.error, isNotNull);
    });

    test('going up is validated; an error reverts the line and is shown under it', () async {
      await guest();
      await kit.cart.add(productId: 1, quantity: 2);
      final line = kit.cart.state.cart.lines.single;
      final error = await kit.cart.setQuantity(line.ref, 9);
      expect(error!.code, 'INSUFFICIENT_STOCK');
      expect(kit.cart.state.cart.lines.single.quantity, 2); // reverted
      expect(kit.cart.state.lineErrors[line.ref], Strings.toastLow(5));
      expect((await kit.store.readCart()).single.quantity, 2);
    });

    test('a valid change is saved and recomputed by the backend', () async {
      await guest();
      await kit.cart.add(productId: 1, quantity: 2);
      final ref = kit.cart.state.cart.lines.single.ref;
      expect(await kit.cart.setQuantity(ref, 4), isNull);
      expect(kit.cart.state.cart.lines.single.lineTotal, '400.00');
      expect(kit.cart.state.count, 4);
      expect(kit.cart.state.lineErrors, isEmpty);
    });

    test('going down is always allowed, even while the line has an issue', () async {
      await guest();
      await kit.cart.add(productId: 1, quantity: 5);
      kit.shop.products[1]!.stock = 2; // stock dropped: the line now has an issue
      await kit.cart.load(refresh: true);
      expect(kit.cart.state.cart.lines.single.issue!.code, 'INSUFFICIENT_STOCK');
      final ref = kit.cart.state.cart.lines.single.ref;
      expect(await kit.cart.setQuantity(ref, 4), isNull); // still too many, but a decrease
      expect((await kit.store.readCart()).single.quantity, 4);
    });

    test('remove and clear', () async {
      await guest();
      await kit.cart.add(productId: 1, quantity: 1);
      await kit.cart.add(productId: 2, quantity: 1);
      await kit.cart.remove(kit.cart.state.cart.lines.first.ref);
      expect((await kit.store.readCart()).single.productId, 2);
      expect(kit.cart.state.count, 1);
      expect(await kit.cart.clear(), isNull);
      expect(await kit.store.readCart(), isEmpty);
      expect(kit.cart.state.cart.lines, isEmpty);
      expect(kit.cart.state.count, 0);
    });

    test('resolve issues: unavailable lines go, quantities are capped, toast text', () async {
      await guest();
      await kit.cart.add(productId: 1, quantity: 5);
      await kit.cart.add(productId: 2, quantity: 3);
      kit.shop.products[1]!.stock = 2; // INSUFFICIENT_STOCK (available 2)
      kit.shop.products[2]!.stock = 0; // OUT_OF_STOCK
      await kit.cart.load(refresh: true);
      expect(kit.cart.state.cart.issuesCount, 2);
      expect(kit.cart.state.cart.canCheckout, isFalse);

      final r = await kit.cart.resolveIssues();
      expect(r.error, isNull);
      expect(r.toast, contains(Strings.noticeLineRemoved));
      expect(r.toast, contains(Strings.noticeQuantityCapped));
      final saved = await kit.store.readCart();
      expect(saved.length, 1);
      expect(saved.single.quantity, 2);
      expect(kit.cart.state.cart.issuesCount, 0);
      expect(kit.cart.state.cart.canCheckout, isTrue);
    });

    test('changes are serialized: fast adds are all applied in order', () async {
      await guest();
      await Future.wait([
        kit.cart.add(productId: 1, quantity: 1),
        kit.cart.add(productId: 1, quantity: 1),
        kit.cart.add(productId: 1, quantity: 1),
      ]);
      expect((await kit.store.readCart()).single.quantity, 3);
      expect(kit.cart.state.count, 3);
    });
  });

  group('currency-aware totals (never summed across SYP and USD)', () {
    test('a mixed cart keeps one total per currency', () async {
      await guest();
      await kit.cart.add(productId: 1, quantity: 2); // 2 x 100.00 SYP
      await kit.cart.add(productId: 2, quantity: 3); // 3 x 8.50 USD (regular 10.00)
      final cart = kit.cart.state.cart;
      expect(cart.subtotals.map((a) => (a.currency, a.amount)).toList(), [
        ('SYP', '200.00'),
        ('USD', '25.50'),
      ]);
      expect(cart.totals.length, 2);
      expect(cart.savings.map((a) => (a.currency, a.amount)).toList(), [('USD', '4.50')]);
      // No single combined figure exists anywhere.
      expect(cart.totals.any((a) => a.amount == '225.50'), isFalse);
      // Each line is in its own currency.
      expect(cart.lines.map((l) => l.currency), ['SYP', 'USD']);
    });
  });

  group('signed in (backend cart)', () {
    test('load reads the stored cart and sets the badge from items_count', () async {
      kit.api.seedStored(1, quantity: 3);
      await signIn();
      expect(kit.cart.state.cart.lines.single.id, isNotNull);
      expect(kit.cart.state.count, 3);
      expect(kit.api.calls, contains('cart'));
      expect(kit.api.calls, isNot(contains('preview')));
    });

    test('add / update / remove / clear use the real endpoints', () async {
      await signIn();
      expect(await kit.cart.add(productId: 1, quantity: 2), isNull);
      expect(kit.api.calls, contains('addItem'));
      final ref = kit.cart.state.cart.lines.single.ref;
      expect(await kit.cart.setQuantity(ref, 4), isNull);
      expect(kit.api.bodies['updateItem'], {'id': int.parse(ref), 'quantity': 4});
      expect(kit.cart.state.count, 4);
      expect(await kit.cart.remove(ref), isNull);
      expect(kit.api.calls, contains('removeItem'));
      expect(kit.cart.state.cart.lines, isEmpty);
      await kit.cart.add(productId: 1, quantity: 1);
      expect(await kit.cart.clear(), isNull);
      expect(kit.api.calls, contains('clear'));
      expect(await kit.store.readCart(), isEmpty); // guest storage is not used
    });

    test('backend errors carry their details through', () async {
      await signIn();
      final stock = await kit.cart.add(productId: 1, quantity: 9);
      expect(stock!.code, 'INSUFFICIENT_STOCK');
      expect(stock.available, 5);
      expect(stock.text, Strings.toastLow(5));
      final limit = await kit.cart.add(productId: 5, quantity: 11);
      expect(limit!.max, 10);
    });

    test('an update error reverts the line and shows the message under it', () async {
      await signIn();
      await kit.cart.add(productId: 1, quantity: 2);
      final ref = kit.cart.state.cart.lines.single.ref;
      final error = await kit.cart.setQuantity(ref, 9);
      expect(error!.code, 'INSUFFICIENT_STOCK');
      expect(kit.cart.state.cart.lines.single.quantity, 2);
      expect(kit.cart.state.lineErrors[ref], Strings.toastLow(5));
    });

    test('resolve issues calls the backend and reports the notices', () async {
      await signIn();
      kit.api.seedStored(1, quantity: 5);
      kit.api.seedStored(4);
      kit.shop.products[1]!.stock = 2;
      await kit.cart.load(refresh: true);
      expect(kit.cart.state.cart.issuesCount, 2);
      final r = await kit.cart.resolveIssues();
      expect(kit.api.calls, contains('resolveIssues'));
      expect(r.toast, contains(Strings.noticeLineRemoved));
      expect(r.toast, contains(Strings.noticeQuantityCapped));
      expect(kit.cart.state.cart.lines.single.quantity, 2);
    });

    test('a failing cart load is a failed state', () async {
      kit.api.failing.add('cart');
      await kit.session.signIn(testPair());
      await kit.cart.load(refresh: true);
      expect(kit.cart.state.status, CartLoad.failed);
    });
  });

  group('mode switching', () {
    test('signing out goes back to the (empty) guest cart', () async {
      kit.api.seedStored(1, quantity: 3);
      await signIn();
      expect(kit.cart.state.count, 3);
      await kit.session.signOut();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(kit.cart.state.cart.lines, isEmpty);
      expect(kit.cart.state.count, 0);
      expect(await kit.cart.add(productId: 1, quantity: 1), isNull);
      expect(kit.api.calls.last, 'preview'); // guest again
    });

    test('while the session is unknown nothing is loaded', () async {
      await kit.cart.load();
      expect(kit.cart.state.status, CartLoad.idle);
    });
  });
}
