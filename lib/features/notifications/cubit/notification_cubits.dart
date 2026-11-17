import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/features/notifications/cubit/unread_cubit.dart';
import 'package:lamsa_app/features/notifications/data/notification_models.dart';
import 'package:lamsa_app/features/notifications/data/notifications_api.dart';

enum InboxLoad { loading, ready, failed }

/// Notifications per page (infinite scroll).
const inboxPageSize = 20;

final class InboxState extends Equatable {
  const InboxState({
    this.status = InboxLoad.loading,
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.unread = 0,
    this.loadingMore = false,
    this.error,
  });

  final InboxLoad status;
  final List<AppNotification> items;
  final int total;
  final int page;

  /// The backend's unread count (all pages, not just those loaded).
  final int unread;
  final bool loadingMore;
  final String? error;

  bool get hasMore => items.length < total;

  InboxState copyWith({
    InboxLoad? status,
    List<AppNotification>? items,
    int? total,
    int? page,
    int? unread,
    bool? loadingMore,
    String? error,
  }) =>
      InboxState(
        status: status ?? this.status,
        items: items ?? this.items,
        total: total ?? this.total,
        page: page ?? this.page,
        unread: unread ?? this.unread,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error,
      );

  @override
  List<Object?> get props =>
      [status, items, total, page, unread, loadingMore, error];
}

/// The notification inbox: newest first, infinite scroll, mark one / all read.
/// Every change also feeds the shared badge ([UnreadCubit]).
final class InboxCubit extends Cubit<InboxState> {
  InboxCubit(this._api, this._badge) : super(const InboxState());

  final NotificationsApi _api;
  final UnreadCubit _badge;
  int _token = 0;

  Future<void> load({bool refresh = false}) async {
    final token = ++_token;
    if (!refresh || state.status != InboxLoad.ready) {
      emit(const InboxState());
    }
    try {
      final page = await _api.list();
      if (token != _token || isClosed) return;
      emit(
        InboxState(
          status: InboxLoad.ready,
          items: page.items,
          total: page.total,
          page: page.page,
          unread: page.unreadCount,
        ),
      );
      _badge.set(page.unreadCount);
    } on Object catch (e) {
      if (token != _token || isClosed) return;
      emit(state.copyWith(status: InboxLoad.failed, error: messageOf(e)));
    }
  }

  Future<void> loadMore() async {
    if (state.status != InboxLoad.ready || state.loadingMore || !state.hasMore) {
      return;
    }
    final token = _token;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _api.list(page: state.page + 1);
      if (token != _token || isClosed) return;
      final known = {for (final n in state.items) n.id};
      emit(
        state.copyWith(
          items: [
            ...state.items,
            for (final n in page.items) if (!known.contains(n.id)) n,
          ],
          total: page.total,
          page: page.page,
          unread: page.unreadCount,
          loadingMore: false,
        ),
      );
      _badge.set(page.unreadCount);
    } on Object {
      if (token == _token && !isClosed) emit(state.copyWith(loadingMore: false));
    }
  }

  /// Marks one read at once and tells the backend; a failure puts it back.
  Future<void> markRead(AppNotification n) async {
    if (n.isRead) return;
    final before = state;
    emit(
      state.copyWith(
        items: [for (final i in state.items) i.id == n.id ? i.asRead() : i],
        unread: state.unread > 0 ? state.unread - 1 : 0,
      ),
    );
    try {
      final count = await _api.markRead(n.id);
      if (isClosed) return;
      emit(state.copyWith(unread: count));
      _badge.set(count);
    } on Object {
      if (isClosed) return;
      emit(before);
      await _badge.refresh();
    }
  }

  /// "تعليم الكل كمقروء". Returns the backend's message on failure.
  Future<String?> markAllRead() async {
    final before = state;
    emit(
      state.copyWith(
        items: [for (final i in state.items) i.asRead()],
        unread: 0,
      ),
    );
    try {
      final count = await _api.markAllRead();
      if (isClosed) return null;
      emit(state.copyWith(unread: count));
      _badge.set(count);
      return null;
    } on Object catch (e) {
      if (!isClosed) emit(before);
      await _badge.refresh();
      return messageOf(e);
    }
  }
}

enum PrefsLoad { loading, ready, failed }

final class PrefsState extends Equatable {
  const PrefsState({
    this.status = PrefsLoad.loading,
    this.prefs = const NotificationPrefs(),
    this.error,
  });

  final PrefsLoad status;
  final NotificationPrefs prefs;
  final String? error;

  PrefsState copyWith({
    PrefsLoad? status,
    NotificationPrefs? prefs,
    String? error,
  }) =>
      PrefsState(
        status: status ?? this.status,
        prefs: prefs ?? this.prefs,
        error: error,
      );

  @override
  List<Object?> get props => [status, prefs, error];
}

enum PrefKey { marketing, favorites, cartReminders }

/// The three switches the backend has. Each toggle shows at once and is saved
/// alone (`PATCH` with that one key); if the backend refuses, it goes back.
final class PreferencesCubit extends Cubit<PrefsState> {
  PreferencesCubit(this._api) : super(const PrefsState());

  final NotificationsApi _api;

  Future<void> load() async {
    emit(const PrefsState());
    try {
      final prefs = await _api.preferences();
      if (!isClosed) emit(PrefsState(status: PrefsLoad.ready, prefs: prefs));
    } on Object catch (e) {
      if (!isClosed) emit(PrefsState(status: PrefsLoad.failed, error: messageOf(e)));
    }
  }

  bool valueOf(PrefKey key) => switch (key) {
        PrefKey.marketing => state.prefs.marketing,
        PrefKey.favorites => state.prefs.favorites,
        PrefKey.cartReminders => state.prefs.cartReminders,
      };

  NotificationPrefs _with(NotificationPrefs p, PrefKey key, bool v) =>
      switch (key) {
        PrefKey.marketing => p.copyWith(marketing: v),
        PrefKey.favorites => p.copyWith(favorites: v),
        PrefKey.cartReminders => p.copyWith(cartReminders: v),
      };

  /// Returns the backend's message when saving failed.
  Future<String?> set(PrefKey key, {required bool value}) async {
    if (state.status != PrefsLoad.ready || valueOf(key) == value) return null;
    emit(state.copyWith(prefs: _with(state.prefs, key, value)));
    try {
      final saved = await _api.updatePreferences(
        marketing: key == PrefKey.marketing ? value : null,
        favorites: key == PrefKey.favorites ? value : null,
        cartReminders: key == PrefKey.cartReminders ? value : null,
      );
      if (isClosed) return null;
      // Only this switch comes from the answer; another one may have been
      // toggled meanwhile.
      emit(
        state.copyWith(
          prefs: _with(state.prefs, key, switch (key) {
            PrefKey.marketing => saved.marketing,
            PrefKey.favorites => saved.favorites,
            PrefKey.cartReminders => saved.cartReminders,
          }),
        ),
      );
      return null;
    } on Object catch (e) {
      if (!isClosed) {
        emit(state.copyWith(prefs: _with(state.prefs, key, !value)));
      }
      return messageOf(e);
    }
  }
}
