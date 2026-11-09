import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lamsa_app/features/auth/cubit/auth_form_state.dart';

// Empty scaffolds: form logic arrives with the auth feature work. The data
// layer (AuthApi, GoogleAuthService, SessionCubit) is already complete.

final class LoginCubit extends Cubit<AuthFormState> {
  LoginCubit() : super(const AuthFormState());
}

final class RegisterCubit extends Cubit<AuthFormState> {
  RegisterCubit() : super(const AuthFormState());
}

final class GoogleSignInCubit extends Cubit<AuthFormState> {
  GoogleSignInCubit() : super(const AuthFormState());
}

final class CompleteProfileCubit extends Cubit<AuthFormState> {
  CompleteProfileCubit() : super(const AuthFormState());
}
