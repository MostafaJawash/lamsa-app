import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/features/notifications/data/push_coordinator.dart';
import 'package:lamsa_app/features/notifications/data/push_messaging.dart';
import 'package:lamsa_app/features/notifications/data/push_service.dart';

/// Shown at the top of the inbox and the preferences when the notification
/// permission is not granted: a button while it was never asked, a short hint
/// (enable it in the device settings) once it was refused. Nothing when push
/// is unavailable (no Firebase config) or the permission is granted. It looks
/// again when the app comes back (the customer may have used the settings).
class PushPermissionBanner extends StatefulWidget {
  const PushPermissionBanner({required this.push, super.key});

  final PushService push;

  @override
  State<PushPermissionBanner> createState() => _PushPermissionBannerState();
}

class _PushPermissionBannerState extends State<PushPermissionBanner>
    with WidgetsBindingObserver {
  PushPermission? _permission;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<void> _check() async {
    if (!widget.push.isAvailable) return;
    final p = await widget.push.permission();
    if (mounted) setState(() => _permission = p);
  }

  Future<void> _ask() async {
    setState(() => _asking = true);
    final p = await widget.push.requestPermission();
    if (p == PushPermission.granted) {
      await widget.push.registerForUser(force: true);
    }
    if (mounted) {
      setState(() {
        _permission = p;
        _asking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _permission;
    if (p == null || p == PushPermission.granted) return const SizedBox.shrink();
    final c = context.lamsa;
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: c.accentSoft,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: p == PushPermission.notDetermined
            ? Row(
                children: [
                  Icon(Icons.notifications_active_outlined, color: c.accent),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(Strings.pushAskTitle, style: theme.titleSmall),
                        Text(Strings.pushAskText, style: theme.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  FilledButton(
                    onPressed: _asking ? null : _ask,
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                    child: const Text(Strings.pushAskAction),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notifications_off_outlined, color: c.muted),
                  const SizedBox(width: Spacing.md),
                  const Expanded(child: Text(Strings.pushDeniedText)),
                ],
              ),
      ),
    );
  }
}

/// Asks for the notification permission at the order confirmation: a short
/// explanation first (the value is clear right now: order updates cannot be
/// switched off), then the system prompt. Shown once, and only while the
/// permission was never asked and push is available.
Future<void> offerPushPermission(BuildContext context, PushService push) async {
  if (!push.isAvailable || await push.explained) return;
  if (await push.permission() != PushPermission.notDetermined) return;
  if (!context.mounted) return;
  await push.markExplained();
  if (!context.mounted) return;
  final allow = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.notifications_active_outlined),
      title: const Text(Strings.pushExplainTitle),
      content: const Text(Strings.pushExplainText),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(Strings.pushExplainLater),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(Strings.pushExplainAllow),
        ),
      ],
    ),
  );
  if (allow != true) return;
  if (await push.requestPermission() == PushPermission.granted) {
    await push.registerForUser(force: true);
  }
}

/// Draws a push that arrives while the app is open as a banner at the top;
/// tapping it opens what it links to, and it goes away by itself. Lighter than
/// a local-notification plugin and the same on Android and iOS.
class ForegroundPushOverlay extends StatefulWidget {
  const ForegroundPushOverlay({
    required this.coordinator,
    required this.child,
    this.duration = const Duration(seconds: 5),
    super.key,
  });

  final PushCoordinator coordinator;
  final Widget child;
  final Duration duration;

  @override
  State<ForegroundPushOverlay> createState() => _ForegroundPushOverlayState();
}

class _ForegroundPushOverlayState extends State<ForegroundPushOverlay> {
  StreamSubscription<ForegroundPush>? _sub;
  ForegroundPush? _current;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sub = widget.coordinator.banners.listen(_show);
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_sub?.cancel());
    super.dispose();
  }

  void _show(ForegroundPush push) {
    _timer?.cancel();
    setState(() => _current = push);
    _timer = Timer(widget.duration, _hide);
  }

  void _hide() {
    _timer?.cancel();
    if (mounted) setState(() => _current = null);
  }

  void _open(ForegroundPush push) {
    _hide();
    unawaited(widget.coordinator.handleTap(push.message));
  }

  @override
  Widget build(BuildContext context) {
    final push = _current;
    return Stack(
      children: [
        widget.child,
        if (push != null)
          PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.sm),
                child: _BannerCard(
                  push: push,
                  onTap: () => _open(push),
                  onClose: _hide,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.push,
    required this.onTap,
    required this.onClose,
  });

  final ForegroundPush push;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    final theme = Theme.of(context).textTheme;
    final title = push.message.title ?? '';
    final body = push.message.body ?? '';
    return Material(
      elevation: 6,
      color: c.surface,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm,
          ),
          child: Row(
            children: [
              Icon(Icons.notifications, color: c.accent),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.titleSmall,
                      ),
                    if (body.isNotEmpty)
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodySmall,
                      ),
                  ],
                ),
              ),
              // No tooltip: the banner sits above the navigator, so there is no
              // Overlay for it; the label is for screen readers.
              Semantics(
                label: Strings.notifBannerClose,
                button: true,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClose,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Calls [onResume] whenever the app returns to the foreground.
class ResumeWatcher extends StatefulWidget {
  const ResumeWatcher({required this.onResume, required this.child, super.key});

  final VoidCallback onResume;
  final Widget child;

  @override
  State<ResumeWatcher> createState() => _ResumeWatcherState();
}

class _ResumeWatcherState extends State<ResumeWatcher>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.onResume();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
