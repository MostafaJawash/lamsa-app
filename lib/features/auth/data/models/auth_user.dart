import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'auth_user.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
final class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.authProvider,
    required this.mustChangePassword,
    this.email,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) =>
      _$AuthUserFromJson(json);

  final int id;
  final String name;
  final String phone;
  final String? email;
  final String role;
  final String authProvider;
  final bool mustChangePassword;

  Map<String, dynamic> toJson() => _$AuthUserToJson(this);

  @override
  List<Object?> get props =>
      [id, name, phone, email, role, authProvider, mustChangePassword];
}
