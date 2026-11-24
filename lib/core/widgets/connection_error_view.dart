import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/core/widgets/lamsa_button.dart';

/// Which kind of connection failure the shopper is looking at.
enum ConnectionIssue { noInternet, serverUnreachable }

/// Asks the OS whether the device has any network at all. Never inferred from
/// a request timeout: a timeout alone cannot tell a dead network from a dead
/// server.
typedef ConnectivityProbe = Future<bool> Function();

Future<bool> _platformProbe() async {
  final results = await Connectivity().checkConnectivity();
  return results.any((r) => r != ConnectivityResult.none);
}

/// Replaceable in tests.
ConnectivityProbe connectivityProbe = _platformProbe;

/// The one "no connection" state, shown wherever a load failed because the
/// backend could not be reached (not for 4xx/5xx answers, not for empty data).
class ConnectionErrorView extends StatefulWidget {
  const ConnectionErrorView({required this.onRetry, this.probe, super.key});

  final VoidCallback onRetry;

  /// Overrides [connectivityProbe] (tests).
  final ConnectivityProbe? probe;

  @override
  State<ConnectionErrorView> createState() => _ConnectionErrorViewState();
}

class _ConnectionErrorViewState extends State<ConnectionErrorView> {
  // Until the probe answers we assume the milder case, so the shopper never
  // sees a wrong "no internet" flash.
  ConnectionIssue _issue = ConnectionIssue.serverUnreachable;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    bool online;
    try {
      online = await (widget.probe ?? connectivityProbe)();
    } on Object {
      online = true;
    }
    if (!mounted) return;
    setState(() {
      _issue = online
          ? ConnectionIssue.serverUnreachable
          : ConnectionIssue.noInternet;
    });
  }

  @override
  Widget build(BuildContext context) {
    final noNet = _issue == ConnectionIssue.noInternet;
    final theme = Theme.of(context).textTheme;
    final c = context.lamsa;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConnectionIcon(issue: _issue),
            const SizedBox(height: Spacing.lg),
            Text(
              noNet ? Strings.noInternetTitle : Strings.serverUnreachableTitle,
              textAlign: TextAlign.center,
              style: theme.titleMedium,
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              noNet ? Strings.noInternetText : Strings.serverUnreachableText,
              textAlign: TextAlign.center,
              style: theme.bodyMedium?.copyWith(color: c.muted),
            ),
            const SizedBox(height: Spacing.lg),
            SizedBox(
              width: 200,
              child: LamsaButton(
                label: Strings.retry,
                onPressed: () {
                  _check();
                  widget.onRetry();
                },
                secondary: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom-drawn icon: Wi-Fi arcs with a slash (no internet) or a cloud with a
/// broken link (server unreachable). Pulses a few times, then rests, so
/// `pumpAndSettle` and reduced-motion settings are both safe.
class ConnectionIcon extends StatefulWidget {
  const ConnectionIcon({required this.issue, super.key});

  final ConnectionIssue issue;

  @override
  State<ConnectionIcon> createState() => _ConnectionIconState();
}

class _ConnectionIconState extends State<ConnectionIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.repeat(count: 3);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    return SizedBox(
      width: 96,
      height: 96,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          painter: _ConnectionPainter(
            issue: widget.issue,
            t: _c.value,
            color: c.muted,
            accent: c.danger,
          ),
        ),
      ),
    );
  }
}

class _ConnectionPainter extends CustomPainter {
  _ConnectionPainter({
    required this.issue,
    required this.t,
    required this.color,
    required this.accent,
  });

  final ConnectionIssue issue;
  final double t;
  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5
      ..color = color;
    final slash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5
      ..color = accent;
    if (issue == ConnectionIssue.noInternet) {
      _wifi(canvas, size, stroke);
      canvas.drawLine(
        Offset(size.width * .18, size.height * .12),
        Offset(size.width * .82, size.height * .88),
        slash,
      );
    } else {
      _cloud(canvas, size, stroke, slash);
    }
  }

  void _wifi(Canvas canvas, Size size, Paint stroke) {
    final origin = Offset(size.width / 2, size.height * .78);
    for (var i = 0; i < 3; i++) {
      final r = size.width * (.18 + i * .16);
      // Arcs light up one after another as t runs 0 -> 1.
      final lit = (t * 3 - i).clamp(0.0, 1.0);
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5
        ..color = stroke.color.withValues(alpha: .35 + .65 * lit);
      canvas.drawArc(
        Rect.fromCircle(center: origin, radius: r),
        -math.pi * .75,
        math.pi * .5,
        false,
        p,
      );
    }
    canvas.drawCircle(origin, 4, Paint()..color = stroke.color);
  }

  void _cloud(Canvas canvas, Size size, Paint stroke, Paint slash) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * .25, h * .72)
      ..cubicTo(w * .02, h * .72, w * .02, h * .42, w * .27, h * .42)
      ..cubicTo(w * .30, h * .18, w * .66, h * .16, w * .72, h * .42)
      ..cubicTo(w * .98, h * .42, w * .98, h * .72, w * .75, h * .72)
      ..close();
    canvas.drawPath(path, stroke);
    // The broken link: a dot that drifts down and fades, then a cross.
    final dy = h * .12 * t;
    canvas.drawCircle(
      Offset(w * .5, h * .56 + dy),
      4,
      Paint()..color = slash.color.withValues(alpha: 1 - .5 * t),
    );
    canvas.drawLine(Offset(w * .42, h * .84), Offset(w * .58, h * .96), slash);
    canvas.drawLine(Offset(w * .58, h * .84), Offset(w * .42, h * .96), slash);
  }

  @override
  bool shouldRepaint(_ConnectionPainter old) =>
      old.t != t || old.issue != issue || old.color != color;
}
