import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:lamsa_app/features/notifications/data/push_background.dart';
import 'package:lamsa_app/features/notifications/data/push_link.dart';

enum PushPermission { notDetermined, granted, denied }

/// The slice of Firebase Messaging the app uses, so the rest of the push code
/// runs (and is tested) without Firebase or a platform channel.
abstract interface class PushMessaging {
  /// Starts Firebase; false when it is not configured (no config files yet).
  Future<bool> initialize();

  Future<PushPermission> permission();

  Future<PushPermission> requestPermission();

  /// The FCM registration token.
  Future<String?> token();

  Stream<String> get tokenRefresh;

  /// A push that arrived while the app is open.
  Stream<PushMessage> get onMessage;

  /// A push the user tapped while the app was in the background.
  Stream<PushMessage> get onOpened;

  /// The push whose tap launched the app from terminated.
  Future<PushMessage?> initialMessage();
}

PushMessage _convert(RemoteMessage m) => PushMessage(
      title: m.notification?.title,
      body: m.notification?.body,
      data: {for (final e in m.data.entries) e.key: '${e.value ?? ''}'},
    );

PushPermission _status(AuthorizationStatus s) => switch (s) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional =>
        PushPermission.granted,
      AuthorizationStatus.denied ||
      AuthorizationStatus.deniedPermanently =>
        PushPermission.denied,
      AuthorizationStatus.notDetermined => PushPermission.notDetermined,
    };

/// The real thing. Everything is inert until `Firebase.initializeApp()`
/// succeeds, which needs google-services.json / GoogleService-Info.plist.
final class FirebasePushMessaging implements PushMessaging {
  FirebaseMessaging get _fm => FirebaseMessaging.instance;

  @override
  Future<bool> initialize() async {
    try {
      await Firebase.initializeApp();
      // Needed for pushes that arrive while the app is not running. It must
      // be a top-level function (see push_background.dart).
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      // The app draws its own banner in the foreground (iOS would otherwise
      // stay silent, Android never shows one).
      await _fm.setForegroundNotificationPresentationOptions();
      return true;
    } on Object catch (e) {
      debugPrint('[push] Firebase not configured, push disabled: $e');
      return false;
    }
  }

  @override
  Future<PushPermission> permission() async =>
      _status((await _fm.getNotificationSettings()).authorizationStatus);

  @override
  Future<PushPermission> requestPermission() async =>
      _status((await _fm.requestPermission()).authorizationStatus);

  // Deprecated in favour of FIDs, but the backend still sends to classic FCM
  // tokens; switch together with its `token=` -> `fid=` change.
  @override
  // ignore: deprecated_member_use
  Future<String?> token() => _fm.getToken();

  @override
  // ignore: deprecated_member_use
  Stream<String> get tokenRefresh => _fm.onTokenRefresh;

  @override
  Stream<PushMessage> get onMessage =>
      FirebaseMessaging.onMessage.map(_convert);

  @override
  Stream<PushMessage> get onOpened =>
      FirebaseMessaging.onMessageOpenedApp.map(_convert);

  @override
  Future<PushMessage?> initialMessage() async {
    final m = await _fm.getInitialMessage();
    return m == null ? null : _convert(m);
  }
}
