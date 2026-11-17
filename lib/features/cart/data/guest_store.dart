import 'package:lamsa_app/features/cart/data/guest_codec.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the guest cart and favorites live between launches.
abstract interface class GuestStore {
  Future<List<GuestCartItem>> readCart();

  /// False when the cart could not be saved (the caller reports the error).
  Future<bool> writeCart(List<GuestCartItem> items);

  Future<List<GuestFavorite>> readFavorites();

  Future<bool> writeFavorites(List<GuestFavorite> items);

  /// Removes both (after a successful merge into the account).
  Future<void> clearAll();
}

/// `shared_preferences`: two small JSON blobs. The data is not secret (ids and
/// quantities), so secure storage would only add cost.
final class SharedPrefsGuestStore implements GuestStore {
  SharedPrefsGuestStore([SharedPreferencesAsync? prefs])
      : _prefs = prefs ?? SharedPreferencesAsync();

  static const cartKeyName = 'lamsa.guest_cart';
  static const favoritesKeyName = 'lamsa.guest_favorites';

  final SharedPreferencesAsync _prefs;

  @override
  Future<List<GuestCartItem>> readCart() async =>
      decodeCart(await _read(cartKeyName));

  @override
  Future<bool> writeCart(List<GuestCartItem> items) =>
      _write(cartKeyName, items.isEmpty ? null : encodeCart(items));

  @override
  Future<List<GuestFavorite>> readFavorites() async =>
      decodeFavorites(await _read(favoritesKeyName));

  @override
  Future<bool> writeFavorites(List<GuestFavorite> items) =>
      _write(favoritesKeyName, items.isEmpty ? null : encodeFavorites(items));

  @override
  Future<void> clearAll() async {
    await _write(cartKeyName, null);
    await _write(favoritesKeyName, null);
  }

  Future<String?> _read(String key) async {
    try {
      return await _prefs.getString(key);
    } on Object {
      return null; // unreadable storage behaves like an empty one
    }
  }

  Future<bool> _write(String key, String? value) async {
    try {
      if (value == null) {
        await _prefs.remove(key);
      } else {
        await _prefs.setString(key, value);
      }
      return true;
    } on Object {
      return false;
    }
  }
}

/// In-memory store, for tests.
final class MemoryGuestStore implements GuestStore {
  MemoryGuestStore({this._cart = const [], this._favorites = const []});

  List<GuestCartItem> _cart;
  List<GuestFavorite> _favorites;
  bool failWrites = false;

  @override
  Future<List<GuestCartItem>> readCart() async => _cart;

  @override
  Future<bool> writeCart(List<GuestCartItem> items) async {
    if (failWrites) return false;
    _cart = items;
    return true;
  }

  @override
  Future<List<GuestFavorite>> readFavorites() async => _favorites;

  @override
  Future<bool> writeFavorites(List<GuestFavorite> items) async {
    if (failWrites) return false;
    _favorites = items;
    return true;
  }

  @override
  Future<void> clearAll() async {
    _cart = const [];
    _favorites = const [];
  }
}
