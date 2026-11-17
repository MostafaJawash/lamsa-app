import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/auth/data/auth_validation.dart';

/// Profile rules, mirroring the backend's `UserUpdate` and lamsa-web's
/// `settings-validation.ts`: name 1..100 after trimming, optional email up to
/// 255 that must look like an address; a blank email clears it. The backend
/// stays the judge.
const emailMax = 255;

/// A practical address check (one "@", a dotted domain, no spaces); the
/// backend is stricter.
bool isEmailLike(String value) =>
    RegExp(r'^[^\s@]+@[^\s@.]+(\.[^\s@.]+)+$').hasMatch(value);

String? validateEmail(String value) {
  final email = value.trim();
  if (email.isEmpty) return null;
  if (email.length > emailMax) return Strings.errEmailLong(emailMax);
  return isEmailLike(email) ? null : Strings.errEmailInvalid;
}

/// Name and email checks for the profile form: field -> message.
({String? name, String? email}) validateProfile(String name, String email) =>
    (name: validateName(name), email: validateEmail(email));
