import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lamsa_app/core/storage/token_storage.dart';
import 'package:lamsa_app/features/auth/data/auth_api.dart';
import 'package:lamsa_app/features/auth/data/guest_data_merger.dart';
import 'package:lamsa_app/features/auth/data/models/auth_user.dart';
import 'package:lamsa_app/features/auth/data/models/token_pair.dart';
import 'package:lamsa_app/features/notifications/data/push_service.dart';

enum SessionStatus { unknown, authenticated, unauthenticated }

/// Why a session is not active, so the router can react differently:
/// [expired] (a stored session died: login with a notice), [signedOut] (the
/// user chose to leave: login without a notice). [none] is a first launch or
/// a guest who never signed in (browse as a guest).
enum SessionEnd { none, expired, signedOut }

final class SessionState extends Equatable {
  const SessionState(this.status, [this.user, this.end = SessionEnd.none]);

  const SessionState.unknown() : this(SessionStatus.unknown);

  final SessionStatus status;

  /// Null while authenticated-but-offline (tokens kept, profile not loaded).
  final AuthUser? user;
  final SessionEnd end;

  bool get isAuthenticated => status == SessionStatus.authenticated;
  bool get mustChangePassword => user?.mustChangePassword ?? false;

  @override
  List<Object?> get props => [status, user, end];
}

/// App-wide session. A Cubit: its few transitions are direct method calls
/// (sign in, sign out, expired), not an event pipeline.
final class SessionCubit extends Cubit<SessionState> {
  SessionCubit({
    required this._api,
    required this._storage,
    required this._push,
    this._merger = const NoopGuestDataMerger(),
    this._onSignedOut,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const SessionState.unknown());

  final AuthApi _api;
  final TokenStorage _storage;
  final PushService _push;
  final GuestDataMerger _merger;

  /// Extra local cleanup after a sign-out (Google account, caches).
  final Future<void> Function()? _onSignedOut;
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
      if (!user.mustChangePassword) await _mergeGuestData();
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
    // The backend refuses cart/favorites calls while a temporary password is
    // pending, so the merge waits for the password change (which signs in again).
    if (!pair.user.mustChangePassword) await _mergeGuestData();
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
    try {
      await _onSignedOut?.call();
    } on Object {
      // Local cleanup must never block signing out.
    }
    emit(
      const SessionState(
        SessionStatus.unauthenticated,
        null,
        SessionEnd.signedOut,
      ),
    );
  }

  /// Called when the refresh flow gave up; storage is already cleared.
  void expire() {
    if (state.status != SessionStatus.unauthenticated ||
        state.end == SessionEnd.none) {
      emit(
        const SessionState(
          SessionStatus.unauthenticated,
          null,
          SessionEnd.expired,
        ),
      );
    }
  }

  /// The login screen has shown/handled why the session ended.
  void acknowledgeEnd() {
    if (state.end == SessionEnd.none) return;
    emit(const SessionState(SessionStatus.unauthenticated));
  }

  /// A request was refused with `403 PASSWORD_CHANGE_REQUIRED`: re-read the
  /// profile (allowed during the gate) so the router sends the user to the
  /// change-password screen.
  Future<void> passwordChangeRequired() async {
    if (!state.isAuthenticated || state.mustChangePassword) return;
    await refreshUser();
  }

  /// Loads `/users/me` (offline launches keep the session without a profile).
  /// Returns whether the profile is now available.
  Future<bool> refreshUser() async {
    if (!state.isAuthenticated) return false;
    try {
      final user = await _api.me();
      if (state.isAuthenticated) {
        emit(SessionState(SessionStatus.authenticated, user));
      }
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _mergeGuestData() async {
    try {
      await _merger.merge();
    } on Object {
      // Never blocks a sign-in; the merger keeps the data and retries later.
    }
  }
}
