import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Entry point for pushes that arrive while the app is in the background or
/// terminated. firebase_messaging runs it in its own isolate, so it must be a
/// top-level (not a closure or a method) function marked as an entry point;
/// otherwise release builds drop it silently.
///
/// Pushes carry a `notification` block, so the system tray draws them by
/// itself; there is nothing to show here. The tap is handled by
/// `onMessageOpenedApp` / `getInitialMessage` when the app is opened.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } on Object {
    // Not configured: nothing to do.
  }
}
