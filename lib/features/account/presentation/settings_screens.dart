import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/core/widgets/app_messenger.dart';
import 'package:lamsa_app/features/account/cubit/settings_cubits.dart';
import 'package:lamsa_app/features/auth/cubit/auth_form_state.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/auth/data/auth_api.dart';
import 'package:lamsa_app/features/auth/data/auth_errors.dart';
import 'package:lamsa_app/features/auth/data/auth_validation.dart';
import 'package:lamsa_app/features/auth/presentation/auth_widgets.dart';

/// Leaves a settings form after a save: toast, then back to the account tab.
void _finish(BuildContext context, String toast) {
  showToast(toast);
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(Routes.account);
  }
}

/// A form page of the account area (title, no brand header).
class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Spacing.pageGutter),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      );
}

/// Name and email.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) => ProfileCubit(
          context.read<AuthApi>(),
          context.read<SessionCubit>(),
        ),
        child: const _ProfileView(),
      );
}

class _ProfileView extends StatefulWidget {
  const _ProfileView();

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  late final TextEditingController _name;
  late final TextEditingController _email;

  @override
  void initState() {
    super.initState();
    final user = context.read<SessionCubit>().state.user;
    _name = TextEditingController(text: user?.name ?? '');
    _email = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    final user = context.read<SessionCubit>().state.user;
    if (user == null) return;
    context.read<ProfileCubit>().save(
          name: _name.text,
          email: _email.text,
          current: user,
        );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProfileCubit>();
    return BlocListener<ProfileCubit, AuthFormState>(
      listenWhen: (a, b) => !a.done && b.done,
      listener: (context, _) => _finish(context, Strings.toastProfileSaved),
      child: _SettingsPage(
        title: Strings.accountProfile,
        children: [
          BlocBuilder<ProfileCubit, AuthFormState>(
            builder: (context, state) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  label: Strings.fieldName,
                  controller: _name,
                  error: state.fieldErrors[AuthField.name],
                  onChanged: (_) => cubit.clearField(AuthField.name),
                  autofillHints: const [AutofillHints.name],
                ),
                AuthTextField(
                  label: Strings.profileEmail,
                  controller: _email,
                  error: state.fieldErrors[AuthField.email],
                  onChanged: (_) => cubit.clearField(AuthField.email),
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.done,
                ),
                FormErrorBanner(error: state.formError),
                AuthSubmitButton(
                  label: Strings.profileSave,
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

/// The login phone. Phone accounts confirm with their password; Google
/// accounts have none.
class PhoneScreen extends StatelessWidget {
  const PhoneScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) => PhoneCubit(
          context.read<AuthApi>(),
          context.read<SessionCubit>(),
        ),
        child: const _PhoneView(),
      );
}

class _PhoneView extends StatefulWidget {
  const _PhoneView();

  @override
  State<_PhoneView> createState() => _PhoneViewState();
}

class _PhoneViewState extends State<_PhoneView> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String _country = defaultCountryCode;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _needsPassword =>
      context.read<SessionCubit>().state.user?.authProvider != 'google';

  void _submit() => context.read<PhoneCubit>().save(
        countryCode: _country,
        phone: _phone.text,
        currentPassword: _password.text,
        needsPassword: _needsPassword,
      );

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PhoneCubit>();
    final user = context.watch<SessionCubit>().state.user;
    final c = context.lamsa;
    return BlocListener<PhoneCubit, AuthFormState>(
      listenWhen: (a, b) => !a.done && b.done,
      listener: (context, _) => _finish(context, Strings.toastPhoneChanged),
      child: _SettingsPage(
        title: Strings.accountPhone,
        children: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: Row(
                children: [
                  Text(
                    Strings.phoneCurrent,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium!
                        .copyWith(color: c.muted),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(user.phone),
                  ),
                ],
              ),
            ),
          AuthNotice(_needsPassword ? Strings.phoneHintPhone : Strings.phoneHintGoogle),
          BlocBuilder<PhoneCubit, AuthFormState>(
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
                if (_needsPassword)
                  PasswordInput(
                    label: Strings.fieldCurrentPassword,
                    controller: _password,
                    error: state.fieldErrors[AuthField.currentPassword],
                    onChanged: (_) => cubit.clearField(AuthField.currentPassword),
                    onSubmitted: _submit,
                  ),
                FormErrorBanner(error: state.formError),
                AuthSubmitButton(
                  label: Strings.phoneSave,
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
