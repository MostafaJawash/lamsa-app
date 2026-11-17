import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/auth/data/auth_validation.dart';

void main() {
  group('combinePhone (what is sent to the backend)', () {
    test('Syrian local number: trunk zero dropped, +963 added', () {
      expect(combinePhone('+963', '0933 123 456'), '+963933123456');
      expect(combinePhone('+963', '933123456'), '+963933123456');
      expect(combinePhone('+963', '0 933 123 456'), '+963933123456');
    });

    test('other countries keep their digits as typed (no zero stripping)', () {
      expect(combinePhone('+49', '1512 3456789'), '+4915123456789');
      expect(combinePhone('+961', '03 123 456'), '+96103123456');
    });

    test('an international number is sent as typed, ignoring the dropdown', () {
      expect(combinePhone('+963', '+49 1512 3456789'), '+49 1512 3456789');
      expect(combinePhone('+963', '0049 151 2345'), '0049 151 2345');
    });

    test('Arabic-Indic digits are read as Latin digits', () {
      expect(combinePhone('+963', '٠٩٣٣١٢٣٤٥٦'), '+963933123456');
      expect(normalizeDigits('۰۹۳۳'), '0933');
    });
  });

  group('validatePhone', () {
    test('accepts local and international spellings', () {
      for (final ok in [
        '0933 123 456',
        '+49 (151) 2345-678',
        '00961 3 123 456',
        '933123456',
      ]) {
        expect(validatePhone(ok), isNull, reason: ok);
      }
    });

    test('empty, letters, too short, too long, too many digits', () {
      expect(validatePhone(''), Strings.errPhoneRequired);
      expect(validatePhone('   '), Strings.errPhoneRequired);
      expect(validatePhone('09a3'), Strings.errPhoneInvalid);
      expect(validatePhone('123'), Strings.errPhoneInvalid);
      expect(validatePhone('1' * 16), Strings.errPhoneInvalid);
      expect(validatePhone('+${'1' * 32}'), Strings.errPhoneInvalid);
    });
  });

  group('names', () {
    test('required, trimmed, max 100', () {
      expect(validateName(''), Strings.errNameRequired);
      expect(validateName('   '), Strings.errNameRequired);
      expect(validateName('ليلى'), isNull);
      expect(validateName('ا' * 101), Strings.errNameTooLong);
      expect(validateName('ا' * 100), isNull);
    });
  });

  group('passwords', () {
    test('login only needs a value', () {
      expect(validateLoginPassword(''), Strings.errPasswordRequired);
      expect(validateLoginPassword('1'), isNull);
      expect(validateLoginPassword('x' * 1025), Strings.errPasswordLong);
    });

    test('new password: 8-128, not digits only', () {
      expect(validateNewPassword('abc12'), Strings.errPasswordShort);
      expect(validateNewPassword('12345678'), Strings.errPasswordDigits);
      expect(
        validateNewPassword('٠١٢٣٤٥٦٧٨'),
        Strings.errPasswordDigits,
      ); // Arabic-Indic digits
      expect(validateNewPassword('x' * 129), Strings.errPasswordLong);
      expect(validateNewPassword('abcd1234'), isNull);
      expect(validateNewPassword('كلمة-سر-قوية'), isNull);
    });

    test('new password must not be the phone, in any spelling', () {
      final forms = phoneForms('+963', '0933 123 456');
      // Digits-only spellings hit the digits rule first (same order as the
      // web); the live "ليست رقم هاتفك" hint still turns red for all of them.
      for (final same in ['0933123456', '00963933123456', '933123456']) {
        expect(
          validateNewPassword(same, forms),
          Strings.errPasswordDigits,
          reason: same,
        );
        expect(
          passwordRules(same, forms)[PasswordRule.notPhone],
          isFalse,
          reason: same,
        );
      }
      expect(
        validateNewPassword('+963933123456', forms),
        Strings.errPasswordPhone,
      );
      expect(
        validateNewPassword('0933 123 456', forms),
        Strings.errPasswordPhone,
      );
      expect(validateNewPassword('0933123456x', forms), isNull);
    });

    test('phone forms include the number as the backend may normalize it', () {
      final forms = phoneForms('+49', '0151 2345678');
      expect(forms, contains('+4901512345678'));
      expect(forms, contains('01512345678'));
      expect(phoneForms('+963', ''), isEmpty);
    });
  });

  group('live password rules', () {
    test('tracks each backend rule as you type', () {
      expect(passwordRules(''), {
        PasswordRule.length: false,
        PasswordRule.notDigits: false,
        PasswordRule.notPhone: false,
      });
      final partial = passwordRules('abc');
      expect(partial[PasswordRule.length], isFalse);
      expect(partial[PasswordRule.notDigits], isTrue);
      expect(partial[PasswordRule.notPhone], isTrue);

      final digits = passwordRules('12345678');
      expect(digits[PasswordRule.length], isTrue);
      expect(digits[PasswordRule.notDigits], isFalse);

      final forms = phoneForms('+963', '0933123456');
      expect(
        passwordRules('0933123456', forms)[PasswordRule.notPhone],
        isFalse,
      );
      expect(passwordRules('abcd1234', forms).values.every((v) => v), isTrue);
    });
  });
}
