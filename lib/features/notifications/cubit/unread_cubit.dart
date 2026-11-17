import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/notifications/data/notifications_api.dart';

/// The unread-notifications count shown as a badge (Account tab and menu),
/// the same role the cart and favorites cubits play for their badges.
///
/// It follows the session (loaded after sign-in or restore, back to 0 at
/// sign-out) and is kept live by: the inbox (every page carries the count),
/// marking one or all as read (the backend returns the new count), a push that
/// arrives in the foreground, and the app coming back to the foreground.
final class UnreadCubit extends Cubit<int> {
  UnreadCubit(this._api, SessionCubit session) : super(0) {
    _sub = session.stream.listen(_onSession);
    _onSession(session.state);
  }

  final NotificationsApi _api;
  late final StreamSubscription<SessionState> _sub;
  int _epoch = 0;
  bool _wasSignedIn = false;

  void _onSession(SessionState s) {
    final signedIn = s.isAuthenticated && !s.mustChangePassword;
    if (signedIn && !_wasSignedIn) {
      unawaited(refresh());
    } else if (!s.isAuthenticated && state != 0) {
      _epoch++;
      emit(0);
    }
    _wasSignedIn = signedIn;
  }

  /// Reads the count from the backend. Failures keep the current number (a
  /// badge must never turn into an error).
  Future<void> refresh() async {
    final epoch = ++_epoch;
    try {
      final n = await _api.unreadCount();
      if (epoch == _epoch && !isClosed) emit(n);
    } on Object {
      // Keep what is shown.
    }
  }

  /// The backend's own count (from a page or a mark-read response).
  void set(int count) {
    if (isClosed) return;
    _epoch++;
    emit(count < 0 ? 0 : count);
  }

  /// A push arrived: show it at once, then confirm with the backend.
  void increment() {
    if (isClosed) return;
    emit(state + 1);
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
