import 'package:equatable/equatable.dart';
import 'package:lamsa_app/core/errors/api_error.dart';

/// Form fields an error can land on.
enum AuthField {
  name,
  email,
  phone,
  password,
  currentPassword,
  newPassword,
  confirmPassword,
}

enum FormErrorKind {
  /// A message under the form (INVALID_CREDENTIALS, network, ...).
  generic,

  /// TOO_MANY_ATTEMPTS: live countdown, submit disabled until it ends.
  rateLimited,

  /// ALREADY_REGISTERED: with a link to login.
  alreadyRegistered,

  /// ACCOUNT_DISABLED: with the store's contact.
  disabled,

  /// Google signup token expired: start again from login.
  signupExpired,
}

final class FormError extends Equatable {
  const FormError(this.kind, this.message);

  final FormErrorKind kind;
  final String message;

  @override
  List<Object?> get props => [kind, message];
}

/// A backend failure mapped to what a form shows. Port of lamsa-web's
/// `mapAuthError`: the backend's Arabic message always wins; the local
/// fallback map only covers codes without one.
final class AuthFailure extends Equatable {
  const AuthFailure({
    this.fieldErrors = const {},
    this.formError,
    this.retryAfter,
  });

  final Map<AuthField, String> fieldErrors;
  final FormError? formError;

  /// Seconds to wait (TOO_MANY_ATTEMPTS).
  final int? retryAfter;

  @override
  List<Object?> get props => [fieldErrors, formError, retryAfter];
}

/// Backend field names (VALIDATION_ERROR details) to form fields.
const _backendFields = {
  'name': AuthField.name,
  'email': AuthField.email,
  'phone': AuthField.phone,
  'password': AuthField.password,
  'current_password': AuthField.currentPassword,
  'new_password': AuthField.newPassword,
};

class AuthErrorOptions {
  const AuthErrorOptions({
    this.passwordField = AuthField.password,
    this.credentialsField,
    this.signup = false,
  });

  /// Field of WEAK_PASSWORD / SAME_PASSWORD (`newPassword` on change password).
  final AuthField passwordField;

  /// INVALID_CREDENTIALS on a field (current password) instead of the form.
  final AuthField? credentialsField;

  /// Google signup: TOKEN_EXPIRED / TOKEN_INVALID mean "start again".
  final bool signup;
}

AuthFailure mapAuthError(
  Object error, [
  AuthErrorOptions options = const AuthErrorOptions(),
]) {
  final message = messageOf(error);
  final api = error is ApiError ? error : null;
  if (api == null) {
    return AuthFailure(formError: FormError(FormErrorKind.generic, message));
  }
  AuthFailure form(FormErrorKind kind, {int? retryAfter}) =>
      AuthFailure(formError: FormError(kind, message), retryAfter: retryAfter);

  switch (api.code) {
    case 'PHONE_TAKEN':
    case 'INVALID_PHONE':
      return AuthFailure(fieldErrors: {AuthField.phone: message});
    case 'WEAK_PASSWORD':
    case 'SAME_PASSWORD':
      return AuthFailure(fieldErrors: {options.passwordField: message});
    case 'INVALID_CREDENTIALS':
      return options.credentialsField != null
          ? AuthFailure(fieldErrors: {options.credentialsField!: message})
          : form(FormErrorKind.generic);
    case 'CURRENT_PASSWORD_REQUIRED':
      return AuthFailure(
        fieldErrors: {
          options.credentialsField ?? AuthField.currentPassword: message,
        },
      );
    case 'CURRENT_PASSWORD_INCORRECT':
      return AuthFailure(
        fieldErrors: {
          options.credentialsField ?? AuthField.currentPassword: message,
        },
      );
    case 'ALREADY_REGISTERED':
      return form(FormErrorKind.alreadyRegistered);
    case 'TOO_MANY_ATTEMPTS':
      return form(
        FormErrorKind.rateLimited,
        retryAfter: _retrySeconds(api) ?? 60,
      );
    case 'ACCOUNT_DISABLED':
      return form(FormErrorKind.disabled);
    case 'TOKEN_EXPIRED':
    case 'TOKEN_INVALID':
      if (options.signup) return form(FormErrorKind.signupExpired);
    case 'VALIDATION_ERROR':
      final fields = <AuthField, String>{};
      for (final d in api.validationDetails) {
        final field = _backendFields[d.field];
        if (field != null) {
          fields.putIfAbsent(
            field,
            () => d.message.isEmpty ? message : d.message,
          );
        }
      }
      return fields.isNotEmpty
          ? AuthFailure(fieldErrors: fields)
          : form(FormErrorKind.generic);
  }
  return form(FormErrorKind.generic);
}

int? _retrySeconds(ApiError e) {
  final r = e.retryAfter;
  if (r != null && r.inSeconds > 0) return r.inSeconds;
  return null;
}

/// Runs [call]; on `503 SERVICE_BUSY` (nothing happened server-side) waits the
/// advised time, capped at 5 s, and retries once.
Future<T> retryOnceIfBusy<T>(
  Future<T> Function() call, {
  Future<void> Function(Duration) delay = _delay,
}) async {
  try {
    return await call();
  } on ApiError catch (e) {
    if (e.code != 'SERVICE_BUSY') rethrow;
    final wait = e.retryAfter ?? const Duration(seconds: 1);
    await delay(
      wait > const Duration(seconds: 5) ? const Duration(seconds: 5) : wait,
    );
    return call();
  }
}

Future<void> _delay(Duration d) => Future<void>.delayed(d);
