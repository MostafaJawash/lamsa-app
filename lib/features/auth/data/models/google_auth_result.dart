import 'package:lamsa_app/features/auth/data/models/token_pair.dart';

/// Result of `POST /auth/google`: either a known account (tokens) or a new
/// one that must finish name + phone via `/auth/google/complete`.
sealed class GoogleAuthResult {
  const GoogleAuthResult();

  factory GoogleAuthResult.fromJson(Map<String, dynamic> json) {
    if (json['registered'] == true) {
      return GoogleRegistered(
        TokenPair.fromJson(json['tokens'] as Map<String, dynamic>),
      );
    }
    final profile = json['profile'] as Map<String, dynamic>? ?? const {};
    return GoogleNeedsProfile(
      signupToken: json['signup_token'] as String,
      name: profile['name'] as String?,
      email: profile['email'] as String?,
    );
  }
}

final class GoogleRegistered extends GoogleAuthResult {
  const GoogleRegistered(this.tokens);
  final TokenPair tokens;
}

/// The signup token is valid for 10 minutes only.
final class GoogleNeedsProfile extends GoogleAuthResult {
  const GoogleNeedsProfile({
    required this.signupToken,
    this.name,
    this.email,
  });

  final String signupToken;
  final String? name;
  final String? email;
}
