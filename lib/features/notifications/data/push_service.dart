import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:lamsa_app/features/notifications/data/devices_api.dart';
import 'package:lamsa_app/features/notifications/data/push_link.dart';

/// Push plumbing: Firebase init, permission, token registration with the
/// backend, and tapped-notification links.
///
/// Inert until the Firebase config files exist (see README): if
/// `Firebase.initializeApp()` fails the app keeps working without push.
final class PushService {
  PushService(this._devices);

  final DevicesApi _devices;

  bool _available = false;
  String? _token;
  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _opened;
  final _seen = <String>{};

  final _links = StreamController<PushLink>.broadcast();

  /// Links from notifications the user tapped, deduped by `notification_id`
  /// (delivery is at-least-once).
  Stream<PushLink> get links => _links.stream;

  bool get isAvailable => _available;

  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _available = true;
    } on Object catch (e) {
      debugPrint('[push] Firebase not configured, push disabled: $e');
      return;
    }
    _opened = FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _onOpened(initial);
  }

  /// Ask permission and register this device. Call after sign-in.
  Future<void> registerForUser() async {
    if (!_available) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      // Deprecated in favour of FIDs, but the backend still sends to classic
      // FCM tokens; switch together with its `token=` -> `fid=` change.
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token == null) return;
      await _register(token);
      await _tokenRefresh?.cancel();
      // ignore: deprecated_member_use
      _tokenRefresh = messaging.onTokenRefresh.listen(
        (t) => unawaited(_register(t)),
      );
    } on Object catch (e) {
      debugPrint('[push] registration failed: $e');
    }
  }

  /// Unregister before logout, while the session is still valid.
  Future<void> unregister() async {
    final token = _token;
    await _tokenRefresh?.cancel();
    _tokenRefresh = null;
    if (!_available || token == null) return;
    try {
      await _devices.unregister(fcmToken: token);
    } on Object catch (e) {
      debugPrint('[push] unregister failed: $e');
    }
    _token = null;
  }

  Future<void> _register(String token) async {
    _token = token;
    await _devices.register(
      fcmToken: token,
      platform: Platform.isIOS ? 'ios' : 'android',
    );
  }

  void _onOpened(RemoteMessage message) {
    final link = PushLink.fromData(message.data);
    if (link == null || !_seen.add(link.notificationId)) return;
    _links.add(link);
  }

  Future<void> dispose() async {
    await _tokenRefresh?.cancel();
    await _opened?.cancel();
    await _links.close();
  }
}
