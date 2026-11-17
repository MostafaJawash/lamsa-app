import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lamsa_app/features/account/data/settings_rules.dart';
import 'package:lamsa_app/features/auth/cubit/auth_form_state.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/auth/data/auth_api.dart';
import 'package:lamsa_app/features/auth/data/auth_errors.dart';
import 'package:lamsa_app/features/auth/data/auth_validation.dart';
import 'package:lamsa_app/features/auth/data/models/auth_user.dart';

/// Shared machinery of the account settings forms: client validation first,
/// one backend call, backend errors mapped to fields (the backend's Arabic
/// message wins), and the session's user refreshed on success.
abstract base class SettingsFormCubit extends Cubit<AuthFormState> {
  SettingsFormCubit(this.session, {this.delay}) : super(const AuthFormState());

  final SessionCubit session;
  final Future<void> Function(Duration)? delay;

  void clearField(AuthField field) {
    if (!state.fieldErrors.containsKey(field)) return;
    emit(state.copyWith(fieldErrors: {...state.fieldErrors}..remove(field)));
  }

  bool reject(Map<AuthField, String?> checks) {
    final errors = {
      for (final e in checks.entries)
        if (e.value != null) e.key: e.value!,
    };
    if (errors.isEmpty) return false;
    emit(state.copyWith(fieldErrors: errors, formError: null, done: false));
    return true;
  }

  Future<void> run(
    Future<AuthUser?> Function() call, {
    AuthErrorOptions options = const AuthErrorOptions(),
  }) async {
    if (state.submitting) return;
    emit(
      state.copyWith(
        submitting: true,
        fieldErrors: const {},
        formError: null,
        done: false,
      ),
    );
    try {
      final user = delay == null
          ? await retryOnceIfBusy(call)
          : await retryOnceIfBusy(call, delay: delay!);
      if (user != null) session.updateUser(user);
      if (!isClosed) emit(state.copyWith(submitting: false, done: true));
    } on Object catch (e) {
      if (isClosed) return;
      final f = mapAuthError(e, options);
      emit(
        state.copyWith(
          submitting: false,
          fieldErrors: f.fieldErrors,
          formError: f.formError,
        ),
      );
    }
  }
}

/// Name and email. Only what changed is sent (so an address the backend
/// would not accept anew stays); a blank email clears it.
final class ProfileCubit extends SettingsFormCubit {
  ProfileCubit(this._api, super.session, {super.delay});

  final AuthApi _api;

  Future<void> save({
    required String name,
    required String email,
    required AuthUser current,
  }) async {
    final v = validateProfile(name, email);
    if (reject({AuthField.name: v.name, AuthField.email: v.email})) return;
    final newName = name.trim();
    final newEmail = email.trim();
    final nameChanged = newName != current.name;
    final emailChanged = newEmail != (current.email ?? '');
    if (!nameChanged && !emailChanged) {
      emit(state.copyWith(done: true, fieldErrors: const {}, formError: null));
      return;
    }
    await run(
      () => _api.updateProfile(
        name: nameChanged ? newName : null,
        email: emailChanged ? newEmail : null,
      ),
    );
  }
}

/// The login phone. The backend asks phone accounts for the current password
/// (Google accounts have none); there is no SMS or code and the other
/// sessions stay.
final class PhoneCubit extends SettingsFormCubit {
  PhoneCubit(this._api, super.session, {super.delay});

  final AuthApi _api;

  Future<void> save({
    required String countryCode,
    required String phone,
    required String currentPassword,
    required bool needsPassword,
  }) async {
    if (reject({
      AuthField.phone: validatePhone(phone),
      if (needsPassword)
        AuthField.currentPassword: validateLoginPassword(currentPassword),
    })) {
      return;
    }
    await run(
      () => _api.changePhone(
        phone: combinePhone(countryCode, phone),
        currentPassword: needsPassword ? currentPassword : null,
      ),
      options: const AuthErrorOptions(credentialsField: AuthField.currentPassword),
    );
  }
}
