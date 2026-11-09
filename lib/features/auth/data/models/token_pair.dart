import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:lamsa_app/core/storage/token_storage.dart';
import 'package:lamsa_app/features/auth/data/models/auth_user.dart';

part 'token_pair.g.dart';

/// Response of every successful sign-in and of `/auth/refresh`.
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
final class TokenPair extends Equatable {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
    this.refreshExpiresIn,
  });

  factory TokenPair.fromJson(Map<String, dynamic> json) =>
      _$TokenPairFromJson(json);

  final String accessToken;
  final String refreshToken;
  final String tokenType;

  /// Access token lifetime in seconds (900 = 15 minutes).
  final int expiresIn;

  /// Refresh token lifetime in seconds; additive/optional on the backend.
  final int? refreshExpiresIn;
  final AuthUser user;

  StoredTokens toStored(DateTime now) => StoredTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        accessExpiresAt: now.add(Duration(seconds: expiresIn)),
      );

  @override
  List<Object?> get props =>
      [accessToken, refreshToken, tokenType, expiresIn, refreshExpiresIn, user];
}
