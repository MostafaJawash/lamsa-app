import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/core/widgets/app_messenger.dart';
import 'package:lamsa_app/core/widgets/connection_error_view.dart';
import 'package:lamsa_app/core/widgets/state_views.dart';
import 'package:lamsa_app/features/notifications/cubit/notification_cubits.dart';
import 'package:lamsa_app/features/notifications/cubit/unread_cubit.dart';
import 'package:lamsa_app/features/notifications/data/notification_format.dart';
import 'package:lamsa_app/features/notifications/data/notification_models.dart';
import 'package:lamsa_app/features/notifications/data/notification_target.dart';
import 'package:lamsa_app/features/notifications/data/notifications_api.dart';
import 'package:lamsa_app/features/notifications/data/push_coordinator.dart';
import 'package:lamsa_app/features/notifications/data/push_service.dart';
import 'package:lamsa_app/features/notifications/presentation/push_widgets.dart';

/// The notification inbox (Account > الإشعارات): newest first, an unread dot,
/// tap to open (it marks the notification read and goes where its link leads),
/// "تعليم الكل كمقروء", infinite scroll and pull to refresh.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({this.clock = DateTime.now, super.key});

  /// The current time (replaceable in tests, for the relative times).
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) => InboxCubit(
          context.read<NotificationsApi>(),
          context.read<UnreadCubit>(),
        )..load(),
        child: _InboxView(clock: clock),
      );
}

class _InboxView extends StatefulWidget {
  const _InboxView({required this.clock});

  final DateTime Function() clock;

  @override
  State<_InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends State<_InboxView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) {
        context.read<InboxCubit>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _markAll() async {
    final error = await context.read<InboxCubit>().markAllRead();
    if (error != null) showToast(error);
  }

  /// Marks it read and goes where it leads (a row without a destination only
  /// marks itself read).
  void _open(AppNotification n) {
    context.read<InboxCubit>().markRead(n);
    final target = inboxTarget(
      linkType: n.link.type,
      linkValue: n.link.value,
      orderId: n.orderId,
      type: n.type,
    );
    if (target is! NoTarget) context.read<PushCoordinator>().navigate(target);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.notifications),
        actions: [
          BlocBuilder<InboxCubit, InboxState>(
            buildWhen: (a, b) => a.unread != b.unread,
            builder: (context, state) => state.unread > 0
                ? TextButton(
                    onPressed: _markAll,
                    child: const Text(Strings.notifMarkAll),
                  )
                : const SizedBox.shrink(),
          ),
          IconButton(
            tooltip: Strings.prefsTitle,
            icon: const Icon(Icons.tune),
            onPressed: () => context.push(Routes.notificationSettings),
          ),
        ],
      ),
      body: BlocBuilder<InboxCubit, InboxState>(
        builder: (context, state) {
          switch (state.status) {
            case InboxLoad.loading:
              return const LoadingView(message: Strings.loading);
            case InboxLoad.failed:
              if (state.connection) {
                return ConnectionErrorView(
                  onRetry: () => context.read<InboxCubit>().load(),
                );
              }
              return ErrorView(
                message: state.error ?? Strings.notifUnavailable,
                onRetry: () => context.read<InboxCubit>().load(),
              );
            case InboxLoad.ready:
              break;
          }
          final push = context.read<PushService>();
          return RefreshIndicator(
            onRefresh: () => context.read<InboxCubit>().load(refresh: true),
            child: ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(Spacing.pageGutter),
              children: [
                PushPermissionBanner(push: push),
                if (state.items.isEmpty)
                  const _Empty()
                else ...[
                  for (final n in state.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.sm),
                      child: _NotificationRow(
                        notification: n,
                        now: widget.clock(),
                        onTap: () => _open(n),
                      ),
                    ),
                  if (state.loadingMore)
                    const Padding(
                      padding: EdgeInsets.all(Spacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xxl),
      child: Column(
        children: [
          Icon(Icons.notifications_none, size: 56, color: c.muted),
          const SizedBox(height: Spacing.md),
          Text(
            Strings.notifEmptyTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            Strings.notifEmptyText,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: c.muted),
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.notification,
    required this.now,
    required this.onTap,
  });

  final AppNotification notification;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    final theme = Theme.of(context).textTheme;
    final n = notification;
    return Card(
      margin: EdgeInsets.zero,
      color: n.isRead ? null : c.accentSoft,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: onTap,
        child: Semantics(
          label: n.isRead ? null : Strings.notifUnreadLabel,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    key: ValueKey('dot-${n.id}-${n.isRead ? 'read' : 'unread'}'),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: n.isRead ? Colors.transparent : c.accent,
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: theme.titleSmall!.copyWith(
                          fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                        ),
                      ),
                      if (n.body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(n.body, style: theme.bodyMedium),
                      ],
                      const SizedBox(height: Spacing.xs),
                      Text(
                        formatNotificationTime(n.sentAt, now),
                        style: theme.bodySmall!.copyWith(color: c.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
