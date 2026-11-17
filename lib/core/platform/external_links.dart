import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens links outside the app (browser, dialer, WhatsApp). The opener is a
/// field so tests can replace it.
abstract final class ExternalLinks {
  static Future<bool> Function(Uri uri) opener = _launch;

  static Future<bool> open(Uri uri) => opener(uri);

  /// Only `https` links (and `tel:` made by the app) are opened, like
  /// lamsa-web's banner rule.
  static bool isSafeWebLink(String? value) {
    if (value == null) return false;
    return RegExp(r'^https://', caseSensitive: false).hasMatch(value.trim()) &&
        Uri.tryParse(value.trim())?.hasAuthority == true;
  }

  static Future<bool> _launch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object catch (e) {
      debugPrint('[links] could not open $uri: $e');
      return false;
    }
  }
}
