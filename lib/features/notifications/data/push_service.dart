import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lamsa_app/features/notifications/data/devices_api.dart';
import 'package:lamsa_app/features/notifications/data/push_link.dart';
import 'package:lamsa_app/features/notifications/data/push_messaging.dart';
import 'package:lamsa_app/features/notifications/data/push_store.dart';

/// Push plumbing: Firebase start-up, the token lifecycle with the backend,
/// the notification permission, and the streams of pushes that arrive in the
/// foreground or are tapped.
///
/// Inert until the Firebase config files exist (see README): if Firebase
/// cannot start the app keeps working without push.
///
/// Token lifecycle:
/// - registered silently after every sign-in and session restore (asking
///   for the permission is a separate, contextual step: [requestPermission]);
/// - registered again when FCM rotates it ([PushMessaging.tokenRefresh]) and
///   when the app resumes and the token has changed;
/// - unregistered with the backend's real endpoint before logout. The token
///   is also kept on the device, so this works after an app restart.
final class PushService {
  PushService(
    this._devices, {
    PushMessaging? messaging,
    PushStore? store,
    this._platform,
  })  : _messaging = messaging ?? FirebasePushMessaging(),
        _injectedStore = store;

  final DevicesApi _devices;
  final PushMessaging _messaging;
  final PushStore? _injectedStore;
  final String? _platform;

  // Created on first use, so plain construction never touches storage.
  late final PushStore _store = _injectedStore ?? SharedPrefsPushStore();

  bool _available = false;
  String? _registered;
  StreamSubscription<String>? _tokenRefresh;
  final _subscriptions = <StreamSubscription<PushMessage>>[];

  final _foreground = StreamController<PushMessage>.broadcast();
  final _opened = StreamController<PushMessage>.broadcast();

  /// Notification ids already shown as a banner / already opened.
  late final SeenIds shown = SeenIds(_store, PushSets.shown);
  late final SeenIds openedIds = SeenIds(_store, PushSets.opened);

  /// Pushes that arrived while the app is open.
  Stream<PushMessage> get foreground => _foreground.stream;

  /// Pushes the user tapped (app in the background, or launched from
  /// terminated by the tap).
  Stream<PushMessage> get opened => _opened.stream;

  bool get isAvailable => _available;

  String get platform =>
      _platform ??
      (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');

  /// Starts Firebase and begins listening. Safe to call without config files.
  Future<void> init() async {
    _available = await _messaging.initialize();
    if (!_available) return;
    _subscriptions
      ..add(_messaging.onMessage.listen(_foreground.add))
      ..add(_messaging.onOpened.listen(_opened.add));
    try {
      final initial = await _messaging.initialMessage();
      if (initial != null) _opened.add(initial);
    } on Object catch (e) {
      debugPrint('[push] initial message failed: $e');
    }
  }

  // ---- permission ----

  /// The current notification permission. Android below 13 reports granted.
  Future<PushPermission> permission() async {
    if (!_available) return PushPermission.denied;
    try {
      return await _messaging.permission();
    } on Object {
      return PushPermission.denied;
    }
  }

  /// Shows the system prompt (iOS, and Android 13+). Call it at a moment the
  /// customer understands why (see the order confirmation).
  Future<PushPermission> requestPermission() async {
    if (!_available) return PushPermission.denied;
    try {
      return await _messaging.requestPermission();
    } on Object {
      return PushPermission.denied;
    }
  }

  /// Whether the order-confirmation explainer was already shown.
  Future<bool> get explained => _store.readFlag(PushFlags.permissionExplained);

  Future<void> markExplained() =>
      _store.writeFlag(PushFlags.permissionExplained, value: true);

  // ---- token ----

  /// Registers this device for the signed-in user (no permission prompt).
  /// With [force] it registers even if this token was already sent (a sign-in:
  /// the backend moves a token seen on another account to this user).
  Future<void> registerForUser({bool force = false}) async {
    if (!_available) return;
    try {
      final token = await _messaging.token();
      if (token == null || token.isEmpty) return;
      if (!force && token == _registered) return;
      await _register(token);
      await _tokenRefresh?.cancel();
      _tokenRefresh = _messaging.tokenRefresh.listen(
        (t) => unawaited(_onRefresh(t)),
      );
    } on Object catch (e) {
      debugPrint('[push] registration failed: $e');
    }
  }

  Future<void> _onRefresh(String token) async {
    try {
      await _register(token);
    } on Object catch (e) {
      debugPrint('[push] re-registration failed: $e');
    }
  }

  Future<void> _register(String token) async {
    await _devices.register(fcmToken: token, platform: platform);
    _registered = token;
    await _store.writeToken(token);
  }

  /// Unregisters before logout, while the session is still valid. Uses the
  /// token kept on the device if this run has not registered one.
  Future<void> unregister() async {
    await _tokenRefresh?.cancel();
    _tokenRefresh = null;
    final token = _registered ?? await _store.readToken();
    if (token == null) return;
    try {
      await _devices.unregister(fcmToken: token);
      _registered = null;
      await _store.writeToken(null);
    } on Object catch (e) {
      // Sign-out goes on. The backend also drops tokens FCM reports as
      // unregistered, and a token seen on another account moves to it.
      debugPrint('[push] unregister failed: $e');
    }
  }

  Future<void> dispose() async {
    await _tokenRefresh?.cancel();
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _foreground.close();
    await _opened.close();
  }
}
