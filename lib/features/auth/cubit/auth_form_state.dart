import 'package:equatable/equatable.dart';

/// Shared state shape for the auth form cubits.
final class AuthFormState extends Equatable {
  const AuthFormState({this.submitting = false, this.errorMessage});

  final bool submitting;
  final String? errorMessage;

  @override
  List<Object?> get props => [submitting, errorMessage];
}
