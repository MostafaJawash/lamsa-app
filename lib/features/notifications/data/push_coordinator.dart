import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/notifications/cubit/unread_cubit.dart';
import 'package:lamsa_app/features/notifications/data/notification_target.dart';
import 'package:lamsa_app/features/notifications/data/notifications_api.dart';
import 'package:lamsa_app/features/notifications/data/push_link.dart';
import 'package:lamsa_app/features/notifications/data/push_service.dart';

/// A push to show as an in-app banner.
final class ForegroundPush extends Equatable {
  const ForegroundPush(this.message, this.link);

  final PushMessage message;
  final PushLink link;

  @override
  List<Object?> get props => [message, link];
}

/// What the app does with pushes, apart from the system drawing them:
///
/// - **foreground**: a push that arrives while the app is open becomes an
///   in-app banner (once per `notification_id`) and bumps the unread badge;
/// - **tap** (from the banner, from the background, or the one that launched
///   the app): opens the screen its link points to (once per id), marks the
///   notification read and refreshes the badge. A tap on an unknown or
///   admin-only link does nothing and stays where the customer is.
///
/// Delivery is at least once, so the two "once per id" sets (banners shown,
/// pushes opened) keep the newest 100 ids on the device. A test push has no id
/// and is never deduplicated nor marked read.
final class PushCoordinator {
  PushCoordinator({
    required this.push,
    required this.session,
    required this.api,
    required this.unread,
    required this.navigate,
    Future<void> Function()? whenReady,
  }) : _whenReady = whenReady ?? (() async {}) {
    _subs
      ..add(push.foreground.listen((m) => unawaited(_onForeground(m))))
      ..add(push.opened.listen((m) => unawaited(handleTap(m))));
  }

  final PushService push;
  final SessionCubit session;
  final NotificationsApi api;
  final UnreadCubit unread;

  /// Goes to a target (the app wires it to the router and the browser).
  final void Function(NotificationTarget target) navigate;

  /// Completes when the session is known and the router can take a route (a
  /// push that launches the app arrives before either is ready).
  final Future<void> Function() _whenReady;

  final _subs = <StreamSubscription<PushMessage>>[];
  final _banners = StreamController<ForegroundPush>.broadcast();

  Stream<ForegroundPush> get banners => _banners.stream;

  Future<void> _onForeground(PushMessage message) async {
    try {
      final link = PushLink.fromData(message.data);
      // A push for a signed-out device means nothing to show.
      if (!session.state.isAuthenticated) return;
      if (!await push.shown.firstTime(link.notificationId)) return;
      if (!link.isTest) {
        unread
          ..increment()
          ..refresh().ignore();
      }
      _banners.add(ForegroundPush(message, link));
    } on Object catch (e) {
      debugPrint('[push] foreground handling failed: $e');
    }
  }

  /// The customer tapped a push (or its banner).
  Future<void> handleTap(PushMessage message) async {
    try {
      final link = PushLink.fromData(message.data);
      if (!await push.openedIds.firstTime(link.notificationId)) return;
      await _whenReady();
      final target = resolveNotificationTarget(
        linkType: link.linkType,
        linkValue: link.linkValue,
        orderId: link.orderId,
        type: link.type,
      );
      if (target is NoTarget) return;
      navigate(target);
      await _markRead(link);
    } on Object catch (e) {
      debugPrint('[push] tap handling failed: $e');
    }
  }

  Future<void> _markRead(PushLink link) async {
    final id = link.inboxId;
    if (link.isTest || id == null || !session.state.isAuthenticated) return;
    try {
      unread.set(await api.markRead(id));
    } on Object {
      unawaited(unread.refresh());
    }
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _banners.close();
  }
}
