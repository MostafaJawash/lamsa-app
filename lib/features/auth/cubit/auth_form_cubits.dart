import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/auth/cubit/auth_form_state.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/auth/data/auth_api.dart';
import 'package:lamsa_app/features/auth/data/auth_errors.dart';
import 'package:lamsa_app/features/auth/data/auth_validation.dart';
import 'package:lamsa_app/features/auth/data/google_auth_service.dart';
import 'package:lamsa_app/features/auth/data/models/google_auth_result.dart';
import 'package:lamsa_app/features/auth/data/models/token_pair.dart';

/// Common machinery of the auth forms: client validation first, one backend
/// call, backend errors mapped to fields / the form, a lockout countdown for
/// `TOO_MANY_ATTEMPTS`, and the session update on success.
abstract base class AuthFormCubit extends Cubit<AuthFormState> {
  AuthFormCubit(this.session, {this._delay}) : super(const AuthFormState());

  final SessionCubit session;
  final Future<void> Function(Duration)? _delay;
  Timer? _lockTimer;

  /// Drops the error shown on [field] once the user edits it.
  void clearField(AuthField field) {
    if (!state.fieldErrors.containsKey(field)) return;
    emit(state.copyWith(fieldErrors: {...state.fieldErrors}..remove(field)));
  }

  /// Shows the validation messages; true means "do not call the backend".
  bool reject(Map<AuthField, String?> checks) {
    final errors = {
      for (final e in checks.entries)
        if (e.value != null) e.key: e.value!,
    };
    if (errors.isEmpty) return false;
    emit(state.copyWith(fieldErrors: errors, formError: null));
    return true;
  }

  Future<void> run(
    Future<TokenPair> Function() call, {
    AuthErrorOptions options = const AuthErrorOptions(),
  }) async {
    if (state.submitting || state.locked) return;
    emit(
      state.copyWith(submitting: true, fieldErrors: const {}, formError: null),
    );
    try {
      final pair = _delay == null
          ? await retryOnceIfBusy(call)
          : await retryOnceIfBusy(call, delay: _delay);
      await session.signIn(pair);
      if (!isClosed) emit(state.copyWith(submitting: false, done: true));
    } on Object catch (e) {
      if (!isClosed) fail(mapAuthError(e, options));
    }
  }

  void fail(AuthFailure failure) {
    emit(
      state.copyWith(
        submitting: false,
        fieldErrors: failure.fieldErrors,
        formError: failure.formError,
        lockSeconds: failure.retryAfter ?? 0,
      ),
    );
    if (failure.retryAfter != null) _startLock();
  }

  void _startLock() {
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = state.lockSeconds - 1;
      if (left <= 0) {
        t.cancel();
        emit(state.copyWith(lockSeconds: 0, formError: null));
      } else {
        emit(state.copyWith(lockSeconds: left));
      }
    });
  }

  @override
  Future<void> close() {
    _lockTimer?.cancel();
    return super.close();
  }
}

final class LoginCubit extends AuthFormCubit {
  LoginCubit(this._api, super.session, {super.delay});

  final AuthApi _api;

  Future<void> submit({
    required String countryCode,
    required String phone,
    required String password,
  }) async {
    if (reject({
      AuthField.phone: validatePhone(phone),
      AuthField.password: validateLoginPassword(password),
    })) {
      return;
    }
    await run(
      () => _api.login(
        phone: combinePhone(countryCode, phone),
        password: password,
      ),
    );
  }
}

final class RegisterCubit extends AuthFormCubit {
  RegisterCubit(this._api, super.session, {super.delay});

  final AuthApi _api;

  Future<void> submit({
    required String name,
    required String countryCode,
    required String phone,
    required String password,
  }) async {
    if (reject({
      AuthField.name: validateName(name),
      AuthField.phone: validatePhone(phone),
      AuthField.password: validateNewPassword(
        password,
        phoneForms(countryCode, phone),
      ),
    })) {
      return;
    }
    await run(
      () => _api.register(
        name: name.trim(),
        phone: combinePhone(countryCode, phone),
        password: password,
      ),
    );
  }
}

/// Google sign-in. A known account signs straight in; a new one returns the
/// [GoogleNeedsProfile] the caller must send to the complete-profile screen.
final class GoogleSignInCubit extends AuthFormCubit {
  GoogleSignInCubit(this._api, this._google, super.session, {super.delay});

  final AuthApi _api;
  final GoogleAuthService _google;

  Future<GoogleNeedsProfile?> signIn() async {
    if (state.submitting) return null;
    emit(
      state.copyWith(submitting: true, fieldErrors: const {}, formError: null),
    );
    try {
      final idToken = await _google.signIn();
      if (idToken == null) {
        emit(state.copyWith(submitting: false)); // cancelled: no error
        return null;
      }
      final result = await retryOnceIfBusy(
        () => _api.loginWithGoogle(idToken: idToken),
      );
      switch (result) {
        case GoogleRegistered(:final tokens):
          await session.signIn(tokens);
          if (!isClosed) emit(state.copyWith(submitting: false, done: true));
          return null;
        case GoogleNeedsProfile():
          if (!isClosed) emit(state.copyWith(submitting: false));
          return result;
      }
    } on Object catch (e) {
      if (isClosed) return null;
      // A failure of the Google SDK itself (not the backend) gets its own text.
      fail(
        e is ApiError
            ? mapAuthError(e)
            : const AuthFailure(
                formError: FormError(
                  FormErrorKind.generic,
                  Strings.googleFailed,
                ),
              ),
      );
      return null;
    }
  }
}

/// Google onboarding: name (prefilled from Google) and phone.
final class CompleteProfileCubit extends AuthFormCubit {
  CompleteProfileCubit(
    this._api,
    this.signupToken,
    super.session, {
    super.delay,
  });

  final AuthApi _api;
  final String signupToken;

  Future<void> submit({
    required String name,
    required String countryCode,
    required String phone,
  }) async {
    if (reject({
      AuthField.name: validateName(name),
      AuthField.phone: validatePhone(phone),
    })) {
      return;
    }
    await run(
      () => _api.completeGoogleSignup(
        signupToken: signupToken,
        name: name.trim(),
        phone: combinePhone(countryCode, phone),
      ),
      options: const AuthErrorOptions(signup: true),
    );
  }
}

/// Replaces a temporary password (also usable voluntarily later). The new
/// token pair it returns signs the session in again, which clears the flag.
final class ChangePasswordCubit extends AuthFormCubit {
  ChangePasswordCubit(this._api, super.session, {super.delay});

  final AuthApi _api;

  Future<void> submit({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (reject({
      AuthField.currentPassword: validateLoginPassword(currentPassword),
      AuthField.newPassword:
          validateNewPassword(newPassword) ??
          (newPassword == currentPassword ? Strings.errSamePassword : null),
      AuthField.confirmPassword: confirmPassword != newPassword
          ? Strings.errConfirmMismatch
          : null,
    })) {
      return;
    }
    await run(
      () => _api.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      ),
      options: const AuthErrorOptions(
        passwordField: AuthField.newPassword,
        credentialsField: AuthField.currentPassword,
      ),
    );
  }
}
