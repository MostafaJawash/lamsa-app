import 'package:flutter/material.dart';
import 'package:lamsa_app/core/network/app_env.dart';
import 'package:lamsa_app/core/platform/external_links.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/features/auth/data/auth_errors.dart';
import 'package:lamsa_app/features/auth/data/auth_validation.dart';

/// Page frame of the auth screens: centered column, scrolls with the keyboard.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.children,
    this.lead,
    this.showBack = true,
    super.key,
  });

  final String title;
  final String? lead;
  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title), automaticallyImplyLeading: showBack),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Spacing.pageGutter),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: Spacing.md),
                  Text(
                    Strings.appName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall!.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (lead != null) ...[
                    const SizedBox(height: Spacing.sm),
                    Text(
                      lead!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: context.lamsa.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: Spacing.xl),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Plain labelled field with an error line (name, etc.).
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    required this.label,
    required this.controller,
    this.error,
    this.hint,
    this.onChanged,
    this.autofillHints,
    this.textInputAction,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? error;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        autofillHints: autofillHints,
        textInputAction: textInputAction ?? TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: error,
          errorMaxLines: 3,
        ),
      ),
    );
  }
}

/// Country code select plus the national number, laid out left-to-right
/// like the web's `.ph-row`.
class PhoneInput extends StatelessWidget {
  const PhoneInput({
    required this.countryCode,
    required this.onCountryChanged,
    required this.controller,
    this.error,
    this.onChanged,
    super.key,
  });

  final String countryCode;
  final ValueChanged<String> onCountryChanged;
  final TextEditingController controller;
  final String? error;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 112,
                child: DropdownButtonFormField<String>(
                  initialValue: countryCode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: Strings.fieldCountryCode,
                  ),
                  items: [
                    for (final code in phoneCountryCodes)
                      DropdownMenuItem(
                        value: code,
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(code),
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) onCountryChanged(v);
                  },
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: Strings.fieldPhone,
                    hintText: Strings.fieldPhoneHint,
                    errorText: error,
                    errorMaxLines: 3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Password input with a show/hide toggle and, for a new password, the
/// backend's rules as live hints.
class PasswordInput extends StatefulWidget {
  const PasswordInput({
    required this.label,
    required this.controller,
    this.error,
    this.onChanged,
    this.onSubmitted,
    this.showRules = false,
    this.phoneForms = const [],
    this.newPassword = false,
    this.action = TextInputAction.done,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? error;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  /// Live rule hints under the field (new passwords only).
  final bool showRules;

  /// Phone spellings the password must not equal (`notPhone` rule).
  final List<String>? phoneForms;
  final bool newPassword;
  final TextInputAction action;

  @override
  State<PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<PasswordInput> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: widget.controller,
            obscureText: !_visible,
            onChanged: widget.onChanged,
            onSubmitted: (_) => widget.onSubmitted?.call(),
            textInputAction: widget.action,
            autofillHints: [
              if (widget.newPassword)
                AutofillHints.newPassword
              else
                AutofillHints.password,
            ],
            decoration: InputDecoration(
              labelText: widget.label,
              errorText: widget.error,
              errorMaxLines: 3,
              suffixIcon: IconButton(
                tooltip: _visible ? Strings.hidePassword : Strings.showPassword,
                icon: Icon(
                  _visible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () => setState(() => _visible = !_visible),
              ),
            ),
          ),
          if (widget.showRules)
            ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) => PasswordRulesHint(
                password: widget.controller.text,
                phoneForms: widget.phoneForms ?? const [],
              ),
            ),
        ],
      ),
    );
  }
}

/// The three backend password rules, each marked met / unmet as you type.
class PasswordRulesHint extends StatelessWidget {
  const PasswordRulesHint({
    required this.password,
    this.phoneForms = const [],
    super.key,
  });

  final String password;
  final List<String> phoneForms;

  @override
  Widget build(BuildContext context) {
    final met = passwordRules(password, phoneForms);
    final c = context.lamsa;
    String label(PasswordRule r) => switch (r) {
      PasswordRule.length => Strings.ruleLength,
      PasswordRule.notDigits => Strings.ruleNotDigits,
      PasswordRule.notPhone => Strings.ruleNotPhone,
    };
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sm),
      child: Semantics(
        label: Strings.rulesLabel,
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final rule in PasswordRule.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Semantics(
                  label:
                      '${label(rule)}: '
                      '${met[rule]! ? Strings.ruleMet : Strings.ruleUnmet}',
                  excludeSemantics: true,
                  child: Row(
                    children: [
                      Icon(
                        met[rule]!
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 16,
                        color: met[rule]! ? c.ok : c.muted,
                      ),
                      const SizedBox(width: Spacing.sm),
                      Text(
                        label(rule),
                        style: Theme.of(context).textTheme.bodySmall!
                            .copyWith(color: met[rule]! ? c.ok : c.muted),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A form-level error: the message, plus what its kind needs (countdown,
/// link to login, store contact, restart).
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner({
    required this.error,
    this.lockSeconds = 0,
    this.onLogin,
    this.onRestart,
    super.key,
  });

  final FormError? error;
  final int lockSeconds;
  final VoidCallback? onLogin;
  final VoidCallback? onRestart;

  @override
  Widget build(BuildContext context) {
    final e = error;
    if (e == null) return const SizedBox.shrink();
    final c = context.lamsa;
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: c.danger.withValues(alpha: .08),
          border: Border.all(color: c.danger.withValues(alpha: .5)),
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.message, style: theme.bodyMedium!.copyWith(color: c.danger)),
            if (e.kind == FormErrorKind.rateLimited && lockSeconds > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  Strings.authRetryIn(lockSeconds),
                  style: theme.bodySmall,
                ),
              ),
            if (e.kind == FormErrorKind.alreadyRegistered && onLogin != null)
              TextButton(
                onPressed: onLogin,
                child: const Text(Strings.loginInstead),
              ),
            if (e.kind == FormErrorKind.disabled &&
                AppEnv.supportPhone.isNotEmpty)
              TextButton(
                onPressed: () => ExternalLinks.open(
                  Uri(scheme: 'tel', path: AppEnv.supportPhone),
                ),
                child: const Text(
                  Strings.authContactStore,
                  textDirection: TextDirection.rtl,
                ),
              ),
            if (e.kind == FormErrorKind.signupExpired && onRestart != null)
              TextButton(
                onPressed: onRestart,
                child: const Text(Strings.completeRestart),
              ),
          ],
        ),
      ),
    );
  }
}

/// A non-error note (session expired, forced password change).
class AuthNotice extends StatelessWidget {
  const AuthNotice(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: c.accentSoft,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium!
              .copyWith(color: c.accent),
        ),
      ),
    );
  }
}

/// Submit button that shows progress and disables itself while locked out.
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    required this.label,
    required this.submitting,
    required this.onPressed,
    this.locked = false,
    super.key,
  });

  final String label;
  final bool submitting;
  final bool locked;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: submitting || locked ? null : onPressed,
      child: submitting
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : Text(label),
    );
  }
}

/// Forgot password: there is no self-service reset, the store gives a
/// temporary password by phone. Buttons only appear for configured contacts.
Future<void> showForgotPasswordDialog(BuildContext context) {
  const phone = AppEnv.supportPhone;
  const whatsapp = AppEnv.supportWhatsapp;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(Strings.forgotTitle),
      content: const Text(Strings.forgotBody),
      actions: [
        if (phone.isNotEmpty)
          TextButton(
            onPressed: () =>
                ExternalLinks.open(Uri(scheme: 'tel', path: phone)),
            child: const Text(Strings.forgotCall),
          ),
        if (whatsapp.isNotEmpty)
          TextButton(
            onPressed: () => ExternalLinks.open(
              Uri.https('wa.me', '/${whatsapp.replaceAll(RegExp(r'\D'), '')}'),
            ),
            child: const Text(Strings.forgotWhatsapp),
          ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text(Strings.close),
        ),
      ],
    ),
  );
}
