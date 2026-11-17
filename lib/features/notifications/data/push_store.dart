import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// What push keeps on the device between launches: the token last registered
/// (so logout can unregister it even after a restart), the recently handled
/// notification ids, and whether the permission explainer was already shown.
abstract interface class PushStore {
  Future<String?> readToken();

  Future<void> writeToken(String? token);

  Future<List<String>> readIds(String set);

  Future<void> writeIds(String set, List<String> ids);

  Future<bool> readFlag(String name);

  Future<void> writeFlag(String name, {required bool value});
}

final class SharedPrefsPushStore implements PushStore {
  SharedPrefsPushStore([SharedPreferencesAsync? prefs])
      : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _tokenKey = 'lamsa.push_token';
  static String _idsKey(String set) => 'lamsa.push_seen.$set';
  static String _flagKey(String name) => 'lamsa.push_flag.$name';

  @override
  Future<String?> readToken() =>
      _safe<String?>(() => _prefs.getString(_tokenKey), null);

  @override
  Future<void> writeToken(String? token) => _safe<void>(
        () => token == null
            ? _prefs.remove(_tokenKey)
            : _prefs.setString(_tokenKey, token),
        null,
      );

  @override
  Future<List<String>> readIds(String set) async =>
      await _safe<List<String>?>(() => _prefs.getStringList(_idsKey(set)), null) ??
      const [];

  @override
  Future<void> writeIds(String set, List<String> ids) =>
      _safe<void>(() => _prefs.setStringList(_idsKey(set), ids), null);

  @override
  Future<bool> readFlag(String name) async =>
      await _safe<bool?>(() => _prefs.getBool(_flagKey(name)), null) ?? false;

  @override
  Future<void> writeFlag(String name, {required bool value}) =>
      _safe<void>(() => _prefs.setBool(_flagKey(name), value), null);

  /// Storage trouble must never break push: reads fall back, writes are lost.
  static Future<T> _safe<T>(Future<T> Function() action, T fallback) async {
    try {
      return await action();
    } on Object {
      return fallback;
    }
  }
}

final class MemoryPushStore implements PushStore {
  String? token;
  final ids = <String, List<String>>{};
  final flags = <String, bool>{};

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String? value) async => token = value;

  @override
  Future<List<String>> readIds(String set) async => List.of(ids[set] ?? const []);

  @override
  Future<void> writeIds(String set, List<String> value) async =>
      ids[set] = List.of(value);

  @override
  Future<bool> readFlag(String name) async => flags[name] ?? false;

  @override
  Future<void> writeFlag(String name, {required bool value}) async =>
      flags[name] = value;
}

/// The set of recently handled `notification_id`s. Delivery is at least once
/// (after a crash a push may arrive twice), so a push whose id is already here
/// is ignored. Bounded to the newest [capacity] ids; survives restarts.
///
/// There are two sets (see [PushSets]): one for banners shown, one for taps
/// opened, so tapping a banner that was already shown still works.
/// A push without an id (a test push) is always "new" and is not remembered.
final class SeenIds {
  SeenIds(this._store, this._set, {this.capacity = 100});

  final PushStore _store;
  final String _set;
  final int capacity;

  List<String>? _ids;
  Future<void> _queue = Future<void>.value();

  /// True the first time [id] is seen (and remembers it), false after.
  Future<bool> firstTime(String id) {
    if (id.isEmpty) return Future.value(true);
    final result = Completer<bool>();
    // Serialised, so two pushes arriving together cannot both be "first".
    _queue = _queue.then((_) async {
      final ids = _ids ??= await _store.readIds(_set);
      if (ids.contains(id)) {
        result.complete(false);
        return;
      }
      ids.add(id);
      if (ids.length > capacity) ids.removeRange(0, ids.length - capacity);
      await _store.writeIds(_set, ids);
      result.complete(true);
    });
    return result.future;
  }
}

abstract final class PushSets {
  static const shown = 'shown';
  static const opened = 'opened';
}

abstract final class PushFlags {
  /// The order-confirmation explainer was shown (once; the inbox and
  /// preferences banner stay available).
  static const permissionExplained = 'permission_explained';
}
