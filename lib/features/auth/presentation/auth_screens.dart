import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/features/auth/cubit/auth_form_cubits.dart';
import 'package:lamsa_app/features/auth/cubit/auth_form_state.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/auth/data/auth_api.dart';
import 'package:lamsa_app/features/auth/data/auth_errors.dart';
import 'package:lamsa_app/features/auth/data/auth_validation.dart';
import 'package:lamsa_app/features/auth/data/google_auth_service.dart';
import 'package:lamsa_app/features/auth/data/models/google_auth_result.dart';
import 'package:lamsa_app/features/auth/presentation/auth_widgets.dart';

/// After a successful sign-in, leave the auth flow for [from] (or home). The
/// router's own redirect covers a screen reached by `go`; a login screen
/// *pushed* over a tab (from a gated tab) needs this explicit navigation.
class _LeaveOnSuccess<C extends AuthFormCubit> extends StatelessWidget {
  const _LeaveOnSuccess({required this.from, required this.child});

  final String? from;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<C, AuthFormState>(
      listenWhen: (a, b) => !a.done && b.done,
      listener: (context, _) => context.go(safeReturnPath(from)),
      child: child,
    );
  }
}

/// Google button (and the "أو" divider) under the login/register forms.
/// Real Google, the dev-only fake, or nothing, depending on the service.
class GoogleSignInSection extends StatelessWidget {
  const GoogleSignInSection({this.from, super.key});

  final String? from;

  @override
  Widget build(BuildContext context) {
    final google = context.read<GoogleAuthService>();
    if (google.kind == GoogleAuthKind.none) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => GoogleSignInCubit(
        context.read<AuthApi>(),
        google,
        context.read<SessionCubit>(),
      ),
      child: Builder(
        builder: (context) {
          return _LeaveOnSuccess<GoogleSignInCubit>(
            from: from,
            child: BlocBuilder<GoogleSignInCubit, AuthFormState>(
              builder: (context, state) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: Spacing.lg),
                    child: Center(child: Text(Strings.authOr)),
                  ),
                  FormErrorBanner(error: state.formError),
                  OutlinedButton.icon(
                    onPressed: state.submitting
                        ? null
                        : () async {
                            final router = GoRouter.of(context);
                            final profile = await context
                                .read<GoogleSignInCubit>()
                                .signIn();
                            if (profile != null) {
                              _pushCompleteProfile(router, profile, from);
                            }
                          },
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: Text(
                      state.submitting
                          ? Strings.authPending
                          : google.kind == GoogleAuthKind.dev
                          ? Strings
                                .googleDev // DEV-ONLY scaffolding
                          : Strings.googleContinue,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// New Google user: on to name + phone, carrying the signup token in the route.
void _pushCompleteProfile(
  GoRouter router,
  GoogleNeedsProfile profile,
  String? from,
) {
  unawaited(
    router.push<void>(
      Routes.withFrom(Routes.completeProfile, from),
      extra: profile,
    ),
  );
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({this.from, this.expired = false, super.key});

  final String? from;

  /// A stored session died: show the "انتهت الجلسة" notice.
  final bool expired;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          LoginCubit(context.read<AuthApi>(), context.read<SessionCubit>()),
      child: _LoginView(from: from, expired: expired),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView({required this.from, required this.expired});

  final String? from;
  final bool expired;

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String _country = defaultCountryCode;

  @override
  void initState() {
    super.initState();
    // The router sent us here because the session ended; we now show why,
    // so mark it handled (guests may then browse without being bounced back).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SessionCubit>().acknowledgeEnd();
    });
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() => context.read<LoginCubit>().submit(
    countryCode: _country,
    phone: _phone.text,
    password: _password.text,
  );

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LoginCubit>();
    return _LeaveOnSuccess<LoginCubit>(
      from: widget.from,
      child: AuthScaffold(
        title: Strings.login,
        lead: Strings.loginLead,
        children: [
          if (widget.expired) const AuthNotice(Strings.sessionExpired),
          BlocBuilder<LoginCubit, AuthFormState>(
            builder: (context, state) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PhoneInput(
                  countryCode: _country,
                  onCountryChanged: (v) => setState(() => _country = v),
                  controller: _phone,
                  error: state.fieldErrors[AuthField.phone],
                  onChanged: (_) => cubit.clearField(AuthField.phone),
                ),
                PasswordInput(
                  label: Strings.fieldPassword,
                  controller: _password,
                  error: state.fieldErrors[AuthField.password],
                  onChanged: (_) => cubit.clearField(AuthField.password),
                  onSubmitted: _submit,
                ),
                FormErrorBanner(
                  error: state.formError,
                  lockSeconds: state.lockSeconds,
                ),
                AuthSubmitButton(
                  label: Strings.loginSubmit,
                  submitting: state.submitting,
                  locked: state.locked,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
          GoogleSignInSection(from: widget.from),
          const SizedBox(height: Spacing.lg),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(Strings.loginNoAccount),
                  TextButton(
                    onPressed: () => context.go(
                      Routes.withFrom(Routes.register, widget.from),
                    ),
                    child: const Text(Strings.loginRegister),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => showForgotPasswordDialog(context),
                child: const Text(Strings.loginForgot),
              ),
            ],
          ),
          TextButton(
            onPressed: () => context.go(Routes.home),
            child: const Text(Strings.loginContinueAsGuest),
          ),
        ],
      ),
    );
  }
}

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({this.from, super.key});

  final String? from;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          RegisterCubit(context.read<AuthApi>(), context.read<SessionCubit>()),
      child: _RegisterView(from: from),
    );
  }
}

class _RegisterView extends StatefulWidget {
  const _RegisterView({required this.from});

  final String? from;

  @override
  State<_RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<_RegisterView> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String _country = defaultCountryCode;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() => context.read<RegisterCubit>().submit(
    name: _name.text,
    countryCode: _country,
    phone: _phone.text,
    password: _password.text,
  );

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RegisterCubit>();
    return _LeaveOnSuccess<RegisterCubit>(
      from: widget.from,
      child: AuthScaffold(
        title: Strings.register,
        lead: Strings.registerLead,
        children: [
          BlocBuilder<RegisterCubit, AuthFormState>(
            builder: (context, state) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  label: Strings.fieldName,
                  hint: Strings.fieldNameHint,
                  controller: _name,
                  autofillHints: const [AutofillHints.name],
                  error: state.fieldErrors[AuthField.name],
                  onChanged: (_) => cubit.clearField(AuthField.name),
                ),
                PhoneInput(
                  countryCode: _country,
                  onCountryChanged: (v) => setState(() => _country = v),
                  controller: _phone,
                  error: state.fieldErrors[AuthField.phone],
                  // The "not your phone" hint follows the phone as you type.
                  onChanged: (_) {
                    cubit.clearField(AuthField.phone);
                    setState(() {});
                  },
                ),
                PasswordInput(
                  label: Strings.fieldPassword,
                  controller: _password,
                  newPassword: true,
                  showRules: true,
                  phoneForms: phoneForms(_country, _phone.text),
                  error: state.fieldErrors[AuthField.password],
                  onChanged: (_) => cubit.clearField(AuthField.password),
                  onSubmitted: _submit,
                ),
                FormErrorBanner(
                  error: state.formError,
                  lockSeconds: state.lockSeconds,
                  onLogin: () =>
                      context.go(Routes.withFrom(Routes.login, widget.from)),
                ),
                AuthSubmitButton(
                  label: Strings.registerSubmit,
                  submitting: state.submitting,
                  locked: state.locked,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
          GoogleSignInSection(from: widget.from),
          const SizedBox(height: Spacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(Strings.registerHaveAccount),
              TextButton(
                onPressed: () =>
                    context.go(Routes.withFrom(Routes.login, widget.from)),
                child: const Text(Strings.registerLogin),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Google onboarding: name (prefilled from Google) and phone.
class CompleteProfileScreen extends StatelessWidget {
  const CompleteProfileScreen({required this.profile, this.from, super.key});

  final GoogleNeedsProfile profile;
  final String? from;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CompleteProfileCubit(
        context.read<AuthApi>(),
        profile.signupToken,
        context.read<SessionCubit>(),
      ),
      child: _CompleteProfileView(profile: profile, from: from),
    );
  }
}

class _CompleteProfileView extends StatefulWidget {
  const _CompleteProfileView({required this.profile, required this.from});

  final GoogleNeedsProfile profile;
  final String? from;

  @override
  State<_CompleteProfileView> createState() => _CompleteProfileViewState();
}

class _CompleteProfileViewState extends State<_CompleteProfileView> {
  late final _name = TextEditingController(text: widget.profile.name ?? '');
  final _phone = TextEditingController();
  String _country = defaultCountryCode;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() => context.read<CompleteProfileCubit>().submit(
    name: _name.text,
    countryCode: _country,
    phone: _phone.text,
  );

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CompleteProfileCubit>();
    return _LeaveOnSuccess<CompleteProfileCubit>(
      from: widget.from,
      child: AuthScaffold(
        title: Strings.completeProfile,
        lead: Strings.completeLead,
        children: [
          if (widget.profile.email != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.lg),
              child: Text(
                '${Strings.completeGoogleAccount} ${widget.profile.email}',
                textAlign: TextAlign.center,
              ),
            ),
          BlocBuilder<CompleteProfileCubit, AuthFormState>(
            builder: (context, state) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  label: Strings.fieldName,
                  hint: Strings.fieldNameHint,
                  controller: _name,
                  error: state.fieldErrors[AuthField.name],
                  onChanged: (_) => cubit.clearField(AuthField.name),
                ),
                PhoneInput(
                  countryCode: _country,
                  onCountryChanged: (v) => setState(() => _country = v),
                  controller: _phone,
                  error: state.fieldErrors[AuthField.phone],
                  onChanged: (_) => cubit.clearField(AuthField.phone),
                ),
                FormErrorBanner(
                  error: state.formError,
                  onLogin: () => context.go(Routes.login),
                  // The signup token lives 10 minutes: start Google again.
                  onRestart: () => context.go(Routes.login),
                ),
                AuthSubmitButton(
                  label: Strings.completeSubmit,
                  submitting: state.submitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Replaces a temporary password. While [SessionState.mustChangePassword] it
/// is the only reachable screen (the router guard enforces that), has no back
/// button, and offers logout so the user is never trapped.
class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({this.from, super.key});

  final String? from;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChangePasswordCubit(
        context.read<AuthApi>(),
        context.read<SessionCubit>(),
      ),
      child: _ChangePasswordView(from: from),
    );
  }
}

class _ChangePasswordView extends StatefulWidget {
  const _ChangePasswordView({required this.from});

  final String? from;

  @override
  State<_ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<_ChangePasswordView> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() => context.read<ChangePasswordCubit>().submit(
    currentPassword: _current.text,
    newPassword: _new.text,
    confirmPassword: _confirm.text,
  );

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ChangePasswordCubit>();
    final forced = context.select<SessionCubit, bool>(
      (s) => s.state.mustChangePassword,
    );
    return PopScope(
      canPop: !forced,
      child: BlocListener<ChangePasswordCubit, AuthFormState>(
        listenWhen: (a, b) => !a.done && b.done,
        listener: (context, _) => context.go(safeReturnPath(widget.from)),
        child: AuthScaffold(
          title: Strings.changePassword,
          lead: Strings.changeLead,
          showBack: !forced,
          children: [
            if (forced) const AuthNotice(Strings.changeForcedNote),
            BlocBuilder<ChangePasswordCubit, AuthFormState>(
              builder: (context, state) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PasswordInput(
                    label: forced
                        ? Strings.fieldTemporaryPassword
                        : Strings.fieldCurrentPassword,
                    controller: _current,
                    action: TextInputAction.next,
                    error: state.fieldErrors[AuthField.currentPassword],
                    onChanged: (_) =>
                        cubit.clearField(AuthField.currentPassword),
                  ),
                  PasswordInput(
                    label: Strings.fieldNewPassword,
                    controller: _new,
                    newPassword: true,
                    showRules: true,
                    action: TextInputAction.next,
                    error: state.fieldErrors[AuthField.newPassword],
                    onChanged: (_) => cubit.clearField(AuthField.newPassword),
                  ),
                  PasswordInput(
                    label: Strings.fieldConfirmPassword,
                    controller: _confirm,
                    error: state.fieldErrors[AuthField.confirmPassword],
                    onChanged: (_) =>
                        cubit.clearField(AuthField.confirmPassword),
                    onSubmitted: _submit,
                  ),
                  FormErrorBanner(
                    error: state.formError,
                    lockSeconds: state.lockSeconds,
                  ),
                  AuthSubmitButton(
                    label: Strings.changeSubmit,
                    submitting: state.submitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.lg),
            if (forced)
              TextButton(
                onPressed: () => context.read<SessionCubit>().signOut(),
                child: const Text(Strings.logout),
              ),
          ],
        ),
      ),
    );
  }
}
