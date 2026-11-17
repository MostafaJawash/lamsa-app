import 'package:lamsa_app/core/strings.dart';

/// Phone and password rules of lamsa-web's `features/auth/schemas.ts`. The
/// backend stays the authority (it normalizes the phone and re-checks the
/// password rules); these give instant feedback and mirror it.

const nameMax = 100;
const passwordMin = 8;
const passwordMax = 128;

/// The backend accepts up to 32 characters for a phone.
const phoneMax = 32;

/// Country codes of the phone field, in the web's order; the first is default.
const phoneCountryCodes = [
  '+963',
  '+961',
  '+962',
  '+90',
  '+966',
  '+971',
  '+974',
  '+965',
  '+49',
];
const defaultCountryCode = '+963';

final _onlyDigits = RegExp(r'^\p{Nd}+$', unicode: true);
final _phoneChars = RegExp(r'^\+?[\d\s\-()]+$');

/// Arabic-Indic and Persian digits to ASCII, so a phone typed on an Arabic
/// keyboard is read like the same Latin digits. (Additive convenience: the web
/// field only offers Latin digits.)
String normalizeDigits(String input) {
  final out = StringBuffer();
  for (final unit in input.runes) {
    if (unit >= 0x0660 && unit <= 0x0669) {
      out.writeCharCode(0x30 + unit - 0x0660);
    } else if (unit >= 0x06F0 && unit <= 0x06F9) {
      out.writeCharCode(0x30 + unit - 0x06F0);
    } else {
      out.writeCharCode(unit);
    }
  }
  return out.toString();
}

String _digitsOf(String value) => value.replaceAll(RegExp(r'\D'), '');

bool _isInternational(String number) {
  final t = number.trim();
  return t.startsWith('+') || t.startsWith('00');
}

/// The number sent to the backend: what was typed when it is already
/// international (`+49...`, `0049...`), otherwise the country code plus the
/// national number (without its trunk "0", only for Syria).
String combinePhone(String countryCode, String number) {
  final typed = normalizeDigits(number);
  if (_isInternational(typed)) return typed.trim();
  final digits = _digitsOf(typed);
  final national = countryCode == '+963'
      ? digits.replaceFirst(RegExp(r'^0+'), '')
      : digits;
  return '$countryCode$national';
}

/// Spellings of the phone that a password must not equal (the backend's rule,
/// approximated), with and without the trunk 0 after the country code.
List<String> phoneForms(String countryCode, String number) {
  final typed = normalizeDigits(number);
  if (_digitsOf(typed).isEmpty) return const [];
  final combined = combinePhone(countryCode, typed);
  final international = _digitsOf(combined.replaceFirst(RegExp(r'^00'), ''));
  final code = _digitsOf(countryCode);
  final national = international.startsWith(code)
      ? international.substring(code.length)
      : _digitsOf(typed).replaceFirst(RegExp(r'^0'), '');
  return [
    '+$international',
    international,
    '00$international',
    '+${code}0$national',
    '00${code}0$national',
    '0$national',
    national,
  ];
}

bool _matchesPhone(String password, List<String> forms) {
  if (forms.isEmpty) return false;
  return forms.contains(password.replaceAll(RegExp(r'[\s\-()./]'), ''));
}

enum PasswordRule { length, notDigits, notPhone }

/// The live hints under a new password: which backend rules it already meets.
Map<PasswordRule, bool> passwordRules(
  String password, [
  List<String> forms = const [],
]) => {
  PasswordRule.length:
      password.length >= passwordMin && password.length <= passwordMax,
  PasswordRule.notDigits:
      password.isNotEmpty && !_onlyDigits.hasMatch(password),
  PasswordRule.notPhone: password.isNotEmpty && !_matchesPhone(password, forms),
};

// ---- field validators: null when valid, else the Arabic message ----

String? validateName(String value) {
  final v = value.trim();
  if (v.isEmpty) return Strings.errNameRequired;
  if (v.length > nameMax) return Strings.errNameTooLong;
  return null;
}

String? validatePhone(String value) {
  final v = normalizeDigits(value).trim();
  if (v.isEmpty) return Strings.errPhoneRequired;
  final digits = _digitsOf(v).length;
  if (v.length > phoneMax ||
      !_phoneChars.hasMatch(v) ||
      digits < 4 ||
      digits > 15) {
    return Strings.errPhoneInvalid;
  }
  return null;
}

/// Login only needs something to send; the rules apply when choosing one.
String? validateLoginPassword(String value) {
  if (value.isEmpty) return Strings.errPasswordRequired;
  if (value.length > 1024) return Strings.errPasswordLong;
  return null;
}

/// A new password: 8-128 characters, not digits only, not the phone.
String? validateNewPassword(String value, [List<String> forms = const []]) {
  if (value.length < passwordMin) return Strings.errPasswordShort;
  if (value.length > passwordMax) return Strings.errPasswordLong;
  if (_onlyDigits.hasMatch(value)) return Strings.errPasswordDigits;
  if (_matchesPhone(value, forms)) return Strings.errPasswordPhone;
  return null;
}
