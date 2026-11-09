import 'package:flutter/material.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/widgets/placeholder_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: Strings.login);
}

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: Strings.register);
}

class CompleteProfileScreen extends StatelessWidget {
  const CompleteProfileScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: Strings.completeProfile);
}

class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: Strings.changePassword);
}
