import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lamsa_app/core/storage/token_storage.dart';
import 'package:lamsa_app/features/auth/data/auth_api.dart';
import 'package:lamsa_app/features/auth/data/models/auth_user.dart';
import 'package:lamsa_app/features/auth/data/models/token_pair.dart';
import 'package:lamsa_app/features/notifications/data/push_service.dart';

enum SessionStatus { unknown, authenticated, unauthenticated }

final class SessionState extends Equatable {
  const SessionState(this.status, [this.user]);

  const SessionState.unknown() : this(SessionStatus.unknown);

  final SessionStatus status;

  /// Null while authenticated-but-offline (tokens kept, profile not loaded).
  final AuthUser? user;

  bool get isAuthenticated => status == SessionStatus.authenticated;
  bool get mustChangePassword => user?.mustChangePassword ?? false;

  @override
  List<Object?> get props => [status, user];
}

/// App-wide session. A Cubit: its few transitions are direct method calls
/// (sign in, sign out, expired), not an event pipeline.
final class SessionCubit extends Cubit<SessionState> {
  SessionCubit({
    required this._api,
    required this._storage,
    required this._push,
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        super(const SessionState.unknown());

  final AuthApi _api;
  final TokenStorage _storage;
  final PushService _push;
  final DateTime Function() _now;

  /// Restores the session from secure storage at launch.
  Future<void> restore() async {
    final tokens = await _storage.read();
    if (tokens == null) {
      emit(const SessionState(SessionStatus.unauthenticated));
      return;
    }
    try {
      final user = await _api.me();
      emit(SessionState(SessionStatus.authenticated, user));
      await _push.registerForUser();
    } on Object {
      // The interceptor ends the session itself on an unrecoverable 401
      // (-> expire()). Anything else (offline) keeps the stored session.
      if (state.status == SessionStatus.unknown) {
        emit(const SessionState(SessionStatus.authenticated));
      }
    }
  }

  /// Persists a fresh token pair (login, register, Google, password change).
  Future<void> signIn(TokenPair pair) async {
    await _storage.write(pair.toStored(_now()));
    emit(SessionState(SessionStatus.authenticated, pair.user));
    await _push.registerForUser();
  }

  Future<void> signOut() async {
    final tokens = await _storage.read();
    await _push.unregister();
    if (tokens != null) {
      try {
        await _api.logout(tokens.refreshToken);
      } on Object {
        // Best effort: local sign-out must always succeed.
      }
    }
    await _storage.clear();
    emit(const SessionState(SessionStatus.unauthenticated));
  }

  /// Called when the refresh flow gave up; storage is already cleared.
  void expire() {
    if (state.status != SessionStatus.unauthenticated) {
      emit(const SessionState(SessionStatus.unauthenticated));
    }
  }
}
