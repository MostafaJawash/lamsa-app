import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/features/auth/data/auth_errors.dart';

ApiError err(
  String code, {
  String? message = 'رسالة من الخادم',
  int status = 400,
  Object? details,
  Duration? retryAfter,
}) => ApiError(
  code: code,
  backendMessage: message,
  status: status,
  details: details,
  retryAfter: retryAfter,
);

void main() {
  group('mapAuthError', () {
    test('phone problems land on the phone field with the backend text', () {
      for (final code in ['PHONE_TAKEN', 'INVALID_PHONE']) {
        final f = mapAuthError(err(code));
        expect(f.fieldErrors, {AuthField.phone: 'رسالة من الخادم'});
        expect(f.formError, isNull);
      }
    });

    test('password problems land on the password field (or newPassword)', () {
      expect(mapAuthError(err('WEAK_PASSWORD')).fieldErrors, {
        AuthField.password: 'رسالة من الخادم',
      });
      expect(
        mapAuthError(
          err('SAME_PASSWORD'),
          const AuthErrorOptions(passwordField: AuthField.newPassword),
        ).fieldErrors,
        {AuthField.newPassword: 'رسالة من الخادم'},
      );
    });

    test('INVALID_CREDENTIALS is a form error; on change-password a field', () {
      final f = mapAuthError(err('INVALID_CREDENTIALS', status: 401));
      expect(f.formError!.kind, FormErrorKind.generic);
      expect(f.fieldErrors, isEmpty);
      final onField = mapAuthError(
        err('INVALID_CREDENTIALS', status: 401),
        const AuthErrorOptions(credentialsField: AuthField.currentPassword),
      );
      expect(onField.fieldErrors.keys, [AuthField.currentPassword]);
    });

    test('CURRENT_PASSWORD_INCORRECT lands on the current password', () {
      expect(
        mapAuthError(err('CURRENT_PASSWORD_INCORRECT', status: 401))
            .fieldErrors
            .keys,
        [AuthField.currentPassword],
      );
    });

    test('TOO_MANY_ATTEMPTS: rate limited with Retry-After, default 60 s', () {
      final f = mapAuthError(
        err(
          'TOO_MANY_ATTEMPTS',
          status: 429,
          retryAfter: const Duration(seconds: 42),
        ),
      );
      expect(f.formError!.kind, FormErrorKind.rateLimited);
      expect(f.retryAfter, 42);
      expect(
        mapAuthError(err('TOO_MANY_ATTEMPTS', status: 429)).retryAfter,
        60,
      );
    });

    test('ALREADY_REGISTERED and ACCOUNT_DISABLED have their own kinds', () {
      expect(
        mapAuthError(err('ALREADY_REGISTERED', status: 409)).formError!.kind,
        FormErrorKind.alreadyRegistered,
      );
      expect(
        mapAuthError(err('ACCOUNT_DISABLED', status: 403)).formError!.kind,
        FormErrorKind.disabled,
      );
    });

    test(
      'expired signup token means "start again" only in the signup flow',
      () {
        const signup = AuthErrorOptions(signup: true);
        for (final code in ['TOKEN_EXPIRED', 'TOKEN_INVALID']) {
          expect(
            mapAuthError(err(code, status: 401), signup).formError!.kind,
            FormErrorKind.signupExpired,
          );
          expect(
            mapAuthError(err(code, status: 401)).formError!.kind,
            FormErrorKind.generic,
          );
        }
      },
    );

    test('VALIDATION_ERROR details go to their fields', () {
      final f = mapAuthError(
        err(
          'VALIDATION_ERROR',
          status: 422,
          details: [
            {'field': 'phone', 'message': 'رقم غير صالح'},
            {'field': 'name', 'message': ''},
            {'field': 'other', 'message': 'x'},
          ],
        ),
      );
      expect(f.fieldErrors[AuthField.phone], 'رقم غير صالح');
      expect(
        f.fieldErrors[AuthField.name],
        'رسالة من الخادم',
      ); // empty detail: form message
      expect(f.fieldErrors.length, 2);
    });

    test('VALIDATION_ERROR without known fields is a form error', () {
      final f = mapAuthError(
        err(
          'VALIDATION_ERROR',
          status: 422,
          details: [
            {'field': 'x', 'message': 'y'},
          ],
        ),
      );
      expect(f.formError!.kind, FormErrorKind.generic);
    });

    test('without a backend message the Arabic fallback by code is used', () {
      final f = mapAuthError(
        err('INVALID_CREDENTIALS', message: null, status: 401),
      );
      expect(f.formError!.message, contains('كلمة المرور'));
    });

    test('network and unknown failures are generic form errors', () {
      final net = mapAuthError(
        const ApiError(code: ApiError.networkCode, backendMessage: null),
      );
      expect(net.formError!.kind, FormErrorKind.generic);
      expect(net.formError!.message, contains('الاتصال'));
      expect(
        mapAuthError(StateError('x')).formError!.kind,
        FormErrorKind.generic,
      );
    });
  });

  group('retryOnceIfBusy', () {
    test(
      'retries once after SERVICE_BUSY, waiting the advised time (capped)',
      () async {
        var calls = 0;
        final waits = <Duration>[];
        final r = await retryOnceIfBusy<int>(() async {
          calls++;
          if (calls == 1) {
            throw err(
              'SERVICE_BUSY',
              status: 503,
              retryAfter: const Duration(seconds: 30),
            );
          }
          return 7;
        }, delay: (d) async => waits.add(d));
        expect(r, 7);
        expect(calls, 2);
        expect(waits.single, const Duration(seconds: 5));
      },
    );

    test(
      'a second SERVICE_BUSY is surfaced; other errors are not retried',
      () async {
        var calls = 0;
        await expectLater(
          retryOnceIfBusy<int>(() async {
            calls++;
            throw err('SERVICE_BUSY', status: 503);
          }, delay: (_) async {}),
          throwsA(isA<ApiError>()),
        );
        expect(calls, 2);

        calls = 0;
        await expectLater(
          retryOnceIfBusy<int>(() async {
            calls++;
            throw err('INVALID_CREDENTIALS', status: 401);
          }, delay: (_) async {}),
          throwsA(isA<ApiError>()),
        );
        expect(calls, 1);
      },
    );
  });
}
