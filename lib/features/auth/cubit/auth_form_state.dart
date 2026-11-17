import 'package:equatable/equatable.dart';
import 'package:lamsa_app/features/auth/data/auth_errors.dart';

const _keep = Object();

/// Shared state shape of the auth form cubits.
final class AuthFormState extends Equatable {
  const AuthFormState({
    this.submitting = false,
    this.fieldErrors = const {},
    this.formError,
    this.lockSeconds = 0,
    this.done = false,
  });

  final bool submitting;
  final Map<AuthField, String> fieldErrors;
  final FormError? formError;

  /// Seconds left of a TOO_MANY_ATTEMPTS lockout; submit is disabled while > 0.
  final int lockSeconds;

  /// The call succeeded (the session was updated).
  final bool done;

  bool get locked => lockSeconds > 0;

  AuthFormState copyWith({
    bool? submitting,
    Map<AuthField, String>? fieldErrors,
    Object? formError = _keep,
    int? lockSeconds,
    bool? done,
  }) => AuthFormState(
    submitting: submitting ?? this.submitting,
    fieldErrors: fieldErrors ?? this.fieldErrors,
    formError: identical(formError, _keep)
        ? this.formError
        : formError as FormError?,
    lockSeconds: lockSeconds ?? this.lockSeconds,
    done: done ?? this.done,
  );

  @override
  List<Object?> get props => [
    submitting,
    fieldErrors,
    formError,
    lockSeconds,
    done,
  ];
}
